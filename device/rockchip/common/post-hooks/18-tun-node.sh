#!/bin/bash -e

source "${RK_POST_HELPER:-$(dirname "$(realpath "$0")")/post-helper}"

[ "$POST_OS" = ubuntu ] || exit 0

mkdir -p "$TARGET_DIR/dev/net"
if [ ! -e "$TARGET_DIR/dev/net/tun" ]; then
	mknod "$TARGET_DIR/dev/net/tun" c 10 200
	chmod 0660 "$TARGET_DIR/dev/net/tun"
fi
