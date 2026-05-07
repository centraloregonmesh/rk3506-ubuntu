#!/bin/bash -e

source "${RK_POST_HELPER:-$(dirname "$(realpath "$0")")/post-helper}"

[ "$POST_OS" = ubuntu ] || exit 0

message "Installing Lyra validation helper..."

install -D -m 0755 "$RK_SDK_DIR/tools/validate-lyra-6.18.sh" \
	"$TARGET_DIR/usr/local/sbin/validate-lyra-6.18"
