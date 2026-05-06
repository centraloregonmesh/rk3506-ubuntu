#!/bin/bash -e

source "${RK_POST_HELPER:-$(dirname "$(realpath "$0")")/post-helper}"

[ "$POST_OS" = ubuntu ] || exit 0

message "Cleaning Ubuntu rootfs build artifacts..."

rm -rf "$TARGET_DIR/var/lib/apt/lists/"* \
	"$TARGET_DIR/var/cache/apt/archives/"*.deb \
	"$TARGET_DIR/tmp/"* "$TARGET_DIR/var/tmp/"*

find "$TARGET_DIR/usr/bin" -maxdepth 1 -type f \
	\( -name 'qemu-*-static' -o -name 'qemu-arm' -o -name 'qemu-aarch64' \) \
	-delete

find "$TARGET_DIR/var/log" -type f -exec truncate -s 0 {} + 2>/dev/null || true
rm -rf "$TARGET_DIR/var/log/journal/"*

rm -f "$TARGET_DIR/etc/ssh"/ssh_host_*_key \
	"$TARGET_DIR/etc/ssh"/ssh_host_*_key.pub

mkdir -p "$TARGET_DIR/etc" "$TARGET_DIR/var/lib/dbus"
: > "$TARGET_DIR/etc/machine-id"
ln -sf /etc/machine-id "$TARGET_DIR/var/lib/dbus/machine-id"

rm -f "$TARGET_DIR/dev/net/tun"
