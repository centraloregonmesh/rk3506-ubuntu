#!/bin/bash -e

source "${RK_POST_HELPER:-$(dirname "$(realpath "$0")")/post-helper}"

[ "$POST_OS" = ubuntu ] || exit 0

message "Installing Lyra USB gadget service..."

install -d "$TARGET_DIR/lib/systemd/system"

cat > "$TARGET_DIR/lib/systemd/system/lyra-usb-gadget.service" <<'EOF'
[Unit]
Description=Luckfox Lyra USB gadget
After=systemd-modules-load.service systemd-udev-settle.service
Wants=systemd-udev-settle.service
Before=lyra-network-fallback.service

[Service]
Type=oneshot
ExecStart=/etc/init.d/S45usbinit start
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

install -d "$TARGET_DIR/etc/systemd/system/multi-user.target.wants"
ln -rsf "$TARGET_DIR/lib/systemd/system/lyra-usb-gadget.service" \
	"$TARGET_DIR/etc/systemd/system/multi-user.target.wants/lyra-usb-gadget.service"
