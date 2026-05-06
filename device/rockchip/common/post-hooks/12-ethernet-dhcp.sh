#!/bin/bash -e

source "${RK_POST_HELPER:-$(dirname "$(realpath "$0")")/post-helper}"

[ "$POST_OS" = ubuntu ] || exit 0

message "Configuring wired DHCP autoconnect..."

install -d -m 700 "$TARGET_DIR/etc/NetworkManager/system-connections"

cat > "$TARGET_DIR/etc/NetworkManager/system-connections/wired-dhcp.nmconnection" <<'EOF'
[connection]
id=wired-dhcp
type=ethernet
autoconnect=true
autoconnect-priority=100

[ethernet]

[ipv4]
method=auto

[ipv6]
method=ignore
EOF

rm -f "$TARGET_DIR/etc/NetworkManager/system-connections/eth0.nmconnection"
chmod 600 "$TARGET_DIR/etc/NetworkManager/system-connections/wired-dhcp.nmconnection"
