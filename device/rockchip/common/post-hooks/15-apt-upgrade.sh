#!/bin/bash -e

source "${RK_POST_HELPER:-$(dirname "$(realpath "$0")")/post-helper}"

[ "$POST_OS" = ubuntu ] || exit 0

select_qemu()
{
	if [ -d "$TARGET_DIR/lib/arm-linux-gnueabihf" ] || \
		[ -d "$TARGET_DIR/usr/lib/arm-linux-gnueabihf" ]; then
		command -v qemu-arm-static || true
		return
	fi

	if [ -d "$TARGET_DIR/lib/aarch64-linux-gnu" ] || \
		[ -d "$TARGET_DIR/usr/lib/aarch64-linux-gnu" ]; then
		command -v qemu-aarch64-static || true
		return
	fi

	command -v qemu-arm-static || command -v qemu-aarch64-static || true
}

restore_resolv_conf()
{
	if [ -e "$RESOLV_BACKUP/resolv.conf" ] || [ -L "$RESOLV_BACKUP/resolv.conf" ]; then
		rm -f "$TARGET_DIR/etc/resolv.conf"
		cp -a "$RESOLV_BACKUP/resolv.conf" "$TARGET_DIR/etc/resolv.conf"
	else
		rm -f "$TARGET_DIR/etc/resolv.conf"
	fi
	rm -rf "$RESOLV_BACKUP"
}

QEMU_BIN="$(select_qemu)"
if [ -z "$QEMU_BIN" ]; then
	error "qemu-user-static not found on host; cannot chroot to update Ubuntu packages."
	exit 1
fi

QEMU_DEST="$TARGET_DIR/usr/bin/$(basename "$QEMU_BIN")"
install -D "$QEMU_BIN" "$QEMU_DEST"

RESOLV_BACKUP="$(mktemp -d)"
if [ -e "$TARGET_DIR/etc/resolv.conf" ] || [ -L "$TARGET_DIR/etc/resolv.conf" ]; then
	cp -a "$TARGET_DIR/etc/resolv.conf" "$RESOLV_BACKUP/resolv.conf"
fi

RESOLV_SRC="/etc/resolv.conf"
[ -e "$RESOLV_SRC" ] || RESOLV_SRC="/run/systemd/resolve/resolv.conf"
rm -f "$TARGET_DIR/etc/resolv.conf"
mkdir -p "$TARGET_DIR/etc"
if [ -e "$RESOLV_SRC" ]; then
	cp "$RESOLV_SRC" "$TARGET_DIR/etc/resolv.conf"
else
	printf 'nameserver 8.8.8.8\n' > "$TARGET_DIR/etc/resolv.conf"
fi

mkdir -p "$TARGET_DIR/proc" "$TARGET_DIR/sys" "$TARGET_DIR/dev/pts"
mountpoint -q "$TARGET_DIR/proc" || mount -t proc proc "$TARGET_DIR/proc"
mountpoint -q "$TARGET_DIR/sys" || mount -t sysfs sys "$TARGET_DIR/sys"
mountpoint -q "$TARGET_DIR/dev" || mount --bind /dev "$TARGET_DIR/dev"
mountpoint -q "$TARGET_DIR/dev/pts" || mount --bind /dev/pts "$TARGET_DIR/dev/pts"

cleanup() {
	umount -l "$TARGET_DIR/dev/pts" "$TARGET_DIR/dev" \
		"$TARGET_DIR/sys" "$TARGET_DIR/proc" 2>/dev/null || true
	rm -f "$QEMU_DEST"
	restore_resolv_conf
}
trap cleanup EXIT

add_target_user_to_group()
{
	local user="$1"
	local group="$2"
	local group_file="$TARGET_DIR/etc/group"
	local passwd_file="$TARGET_DIR/etc/passwd"
	local tmp

	grep -q "^${user}:" "$passwd_file" || return 0
	grep -q "^${group}:" "$group_file" || return 0

	tmp="$(mktemp)"
	awk -F: -v OFS=: -v user="$user" -v group="$group" '
		$1 == group {
			found = 0
			n = split($4, members, ",")
			for (i = 1; i <= n; i++) {
				if (members[i] == user)
					found = 1
			}
			if (!found)
				$4 = $4 ? $4 "," user : user
		}
		{ print }
	' "$group_file" > "$tmp"
	install -m 0644 "$tmp" "$group_file"
	rm -f "$tmp"
}

CHROOT_ENV=(chroot "$TARGET_DIR" env DEBIAN_FRONTEND=noninteractive)
APT_INSTALL=(apt-get -y --no-install-recommends install)

CODENAME="$(grep '^VERSION_CODENAME=' "$TARGET_DIR/etc/os-release" | cut -d= -f2)"
CODENAME="${CODENAME:-noble}"

message "Updating Ubuntu packages and installing image networking tools..."
"${CHROOT_ENV[@]}" apt-get update
"${CHROOT_ENV[@]}" "${APT_INSTALL[@]}" \
	ca-certificates curl dnsutils file gnupg htop iotop iproute2 \
	openssh-server rsync tcpdump wireguard-tools \
	containerd docker.io podman uidmap slirp4netns fuse-overlayfs
"${CHROOT_ENV[@]}" apt-get -y dist-upgrade

TS_KEYRING=/usr/share/keyrings/tailscale-archive-keyring.gpg
TS_LIST=/etc/apt/sources.list.d/tailscale.list
"${CHROOT_ENV[@]}" /bin/sh -c \
	"curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/${CODENAME}.noarmor.gpg > $TS_KEYRING"
"${CHROOT_ENV[@]}" /bin/sh -c \
	"curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/${CODENAME}.tailscale-keyring.list > $TS_LIST"

"${CHROOT_ENV[@]}" apt-get update
"${CHROOT_ENV[@]}" "${APT_INSTALL[@]}" tailscale
add_target_user_to_group lyra docker
"${CHROOT_ENV[@]}" systemctl enable containerd.service docker.service podman.socket || true
"${CHROOT_ENV[@]}" apt-get -y autoremove --purge
"${CHROOT_ENV[@]}" apt-get clean
rm -rf "$TARGET_DIR/var/lib/apt/lists/"*
