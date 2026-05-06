#!/bin/bash -e

source "${RK_POST_HELPER:-$(dirname "$(realpath "$0")")/post-helper}"

[ "$POST_OS" = ubuntu ] || exit 0

message "Cleaning final Ubuntu image payload..."

KERNEL_DIR="${RK_KERNEL_DIR:-$RK_SDK_DIR/kernel}"
KERNEL_RELEASE="$(make -sC "$KERNEL_DIR" kernelrelease 2>/dev/null || true)"
if [ -z "$KERNEL_RELEASE" ] && [ -n "$RK_KERNEL_VERSION" ]; then
	KERNEL_RELEASE="$(find "$TARGET_DIR/lib/modules" -mindepth 1 -maxdepth 1 \
		-type d -name "${RK_KERNEL_VERSION}"'*' -printf '%f\n' 2>/dev/null | \
		sort -V | tail -n 1)"
fi
if [ -n "$KERNEL_RELEASE" ]; then
	for modules_dir in "$TARGET_DIR/lib/modules" "$TARGET_DIR/usr/lib/modules"; do
		[ -d "$modules_dir" ] || continue
		find "$modules_dir" -mindepth 1 -maxdepth 1 -type d \
			! -name "$KERNEL_RELEASE" -exec rm -rf {} +
	done
fi

rm -rf "$TARGET_DIR/home/lyra/aic800" \
	"$TARGET_DIR/home/lyra/linux-firmware_"*.deb \
	"$TARGET_DIR/home/lyra/firmware-sof-signed_"*.deb

rm -rf "$TARGET_DIR/var/lib/apt/lists/"* \
	"$TARGET_DIR/var/cache/apt/archives/"*.deb \
	"$TARGET_DIR/tmp/"* "$TARGET_DIR/var/tmp/"*

find "$TARGET_DIR/var/log" -type f -exec truncate -s 0 {} + 2>/dev/null || true
rm -rf "$TARGET_DIR/var/log/journal/"*
