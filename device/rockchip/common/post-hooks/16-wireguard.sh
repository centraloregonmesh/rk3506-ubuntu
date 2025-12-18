#!/bin/bash -e

source "${RK_POST_HELPER:-$(dirname "$(realpath "$0")")/post-helper}"

[ "$POST_OS" = ubuntu ] || exit 0

QEMU_BIN="$(command -v qemu-aarch64-static || command -v qemu-arm-static || true)"
if [ -z "$QEMU_BIN" ]; then
	error "qemu-*-static not found on host; cannot chroot to install wireguard-tools."
	exit 1
fi

QEMU_DEST="$TARGET_DIR/usr/bin/$(basename "$QEMU_BIN")"
install -D "$QEMU_BIN" "$QEMU_DEST"
cp /etc/resolv.conf "$TARGET_DIR/etc/resolv.conf"

mount -t proc proc "$TARGET_DIR/proc"
mount -t sysfs sys "$TARGET_DIR/sys"
mount --bind /dev "$TARGET_DIR/dev"
mount --bind /dev/pts "$TARGET_DIR/dev/pts"

cleanup() {
	umount -l "$TARGET_DIR/dev/pts" "$TARGET_DIR/dev" \
		"$TARGET_DIR/sys" "$TARGET_DIR/proc" 2>/dev/null || true
	rm -f "$QEMU_DEST"
}
trap cleanup EXIT

CHROOT_ENV=(chroot "$TARGET_DIR" env DEBIAN_FRONTEND=noninteractive)

"${CHROOT_ENV[@]}" apt-get update
"${CHROOT_ENV[@]}" apt-get -y install wireguard-tools
"${CHROOT_ENV[@]}" apt-get -y autoremove
"${CHROOT_ENV[@]}" apt-get clean
