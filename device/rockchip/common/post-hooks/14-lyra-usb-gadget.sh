#!/bin/bash -e

source "${RK_POST_HELPER:-$(dirname "$(realpath "$0")")/post-helper}"

[ "$POST_OS" = ubuntu ] || exit 0

message "Installing Lyra USB gadget service..."

rm -f "$TARGET_DIR/etc/.usb0_macaddr"
rm -f "$TARGET_DIR/etc/.usb_config"
rm -f "$TARGET_DIR/etc/init.d/S45usbinit"
rm -f "$TARGET_DIR/etc/init.d/S45usbconfig"
rm -f "$TARGET_DIR/usr/bin/adbd" \
	"$TARGET_DIR/usr/bin/adbd-auth.sh" \
	"$TARGET_DIR/usr/bin/logcat" \
	"$TARGET_DIR/etc/profile.d/adbd.sh" \
	"$TARGET_DIR/adb_keys"

if [ -f "$TARGET_DIR/etc/rc.local" ]; then
	sed -i '/^[[:space:]]*modprobe[[:space:]]\+usb_f_fs[[:space:]]*$/d' \
		"$TARGET_DIR/etc/rc.local"
fi

install -D -m 0755 \
	"$RK_SDK_DIR/device/rockchip/common/overlays/rootfs/luckfox-lyra/usr/local/sbin/lyra-usb-gadget" \
	"$TARGET_DIR/usr/local/sbin/lyra-usb-gadget"

install -d "$TARGET_DIR/etc/init.d"
cat > "$TARGET_DIR/etc/init.d/S45usbinit" <<'EOF'
#!/bin/sh
exec /usr/local/sbin/lyra-usb-gadget "$@"
EOF
chmod 0755 "$TARGET_DIR/etc/init.d/S45usbinit"

install -d "$TARGET_DIR/lib/systemd/system"

cat > "$TARGET_DIR/lib/systemd/system/lyra-usb-gadget.service" <<'EOF'
[Unit]
Description=Luckfox Lyra USB gadget
After=systemd-modules-load.service systemd-udev-settle.service
Wants=systemd-udev-settle.service
Before=lyra-network-fallback.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/lyra-usb-gadget start
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

install -d "$TARGET_DIR/etc/systemd/system/multi-user.target.wants"
ln -rsf "$TARGET_DIR/lib/systemd/system/lyra-usb-gadget.service" \
	"$TARGET_DIR/etc/systemd/system/multi-user.target.wants/lyra-usb-gadget.service"
