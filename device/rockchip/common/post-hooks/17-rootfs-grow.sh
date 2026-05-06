#!/bin/bash -e

source "${RK_POST_HELPER:-$(dirname "$(realpath "$0")")/post-helper}"

[ "$POST_OS" = ubuntu ] || exit 0

message "Installing Lyra rootfs grow service..."

install -d "$TARGET_DIR/usr/local/sbin" \
	"$TARGET_DIR/usr/lib/systemd/system" \
	"$TARGET_DIR/etc/systemd/system/multi-user.target.wants"

cat > "$TARGET_DIR/usr/local/sbin/lyra-rootfs-grow" <<'EOF'
#!/bin/sh
set -eu

log()
{
	echo "lyra-rootfs-grow: $*"
}

root_dev_from_findmnt()
{
	local source majmin sys_path dev_name

	source="$(findmnt -n -o SOURCE / 2>/dev/null || true)"
	case "$source" in
		/dev/*)
			if [ "$source" != "/dev/root" ] && [ -b "$source" ]; then
				printf '%s\n' "$source"
				return 0
			fi
			;;
	esac

	majmin="$(findmnt -n -o MAJ:MIN / 2>/dev/null || true)"
	[ -n "$majmin" ] || return 1

	sys_path="/sys/dev/block/$majmin"
	[ -e "$sys_path" ] || return 1

	dev_name="$(basename "$(readlink -f "$sys_path")")"
	[ -n "$dev_name" ] || return 1

	if [ -b "/dev/$dev_name" ]; then
		printf '/dev/%s\n' "$dev_name"
		return 0
	fi

	if [ -b "/dev/block/$dev_name" ]; then
		printf '/dev/block/%s\n' "$dev_name"
		return 0
	fi

	return 1
}

ROOT_DEV="$(root_dev_from_findmnt || true)"
if [ -z "$ROOT_DEV" ]; then
	log "could not resolve root block device"
	exit 0
fi

if ! command -v resize2fs >/dev/null 2>&1; then
	log "resize2fs is not installed"
	exit 0
fi

log "resizing root filesystem on $ROOT_DEV"
resize2fs "$ROOT_DEV"
log "root filesystem after resize:"
df -h /
EOF

chmod 0755 "$TARGET_DIR/usr/local/sbin/lyra-rootfs-grow"

cat > "$TARGET_DIR/usr/lib/systemd/system/lyra-rootfs-grow.service" <<'EOF'
[Unit]
Description=Grow Luckfox Lyra root filesystem
After=local-fs.target systemd-remount-fs.service resize-all.service
Before=containerd.service docker.service ssh.service
RequiresMountsFor=/

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/lyra-rootfs-grow
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

ln -rsf "$TARGET_DIR/usr/lib/systemd/system/lyra-rootfs-grow.service" \
	"$TARGET_DIR/etc/systemd/system/multi-user.target.wants/lyra-rootfs-grow.service"

if [ -e "$TARGET_DIR/etc/init.d/S40resize2fs" ]; then
	cat > "$TARGET_DIR/etc/init.d/S40resize2fs" <<'EOF'
#!/bin/sh

case "$1" in
	start|"")
		exec /usr/local/sbin/lyra-rootfs-grow
		;;
	*)
		exit 1
		;;
esac
EOF
	chmod 0755 "$TARGET_DIR/etc/init.d/S40resize2fs"
fi

rm -f "$TARGET_DIR/swapfile" \
	"$TARGET_DIR/etc/.filesystem_swap" \
	"$TARGET_DIR/etc/.filesystem_resized"

if [ -f "$TARGET_DIR/etc/fstab" ]; then
	sed -i '\|/swapfile[[:space:]]|d' "$TARGET_DIR/etc/fstab"
fi
