#!/bin/bash -e

source "${RK_POST_HELPER:-$(dirname "$(realpath "$0")")/post-helper}"

[ "$POST_OS" = ubuntu ] || exit 0

message "Installing Lyra network fallback service..."

install -d "$TARGET_DIR/usr/local/sbin" "$TARGET_DIR/lib/systemd/system"

cat > "$TARGET_DIR/usr/local/sbin/lyra-network-fallback" <<'EOF'
#!/bin/sh

set -eu

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
LOG=/var/log/lyra-network-fallback.log

exec >>"$LOG" 2>&1

echo "[$(date -Iseconds 2>/dev/null || date)] starting network fallback"

is_wired_candidate()
{
	iface="$1"

	case "$iface" in
		lo|usb*|wlan*|wwan*|docker*|br-*|veth*|sit*|ip6*|can*)
			return 1
			;;
	esac

	[ -e "/sys/class/net/$iface" ] || return 1
	[ "$(cat "/sys/class/net/$iface/type" 2>/dev/null || echo 0)" = 1 ] || return 1
	[ -e "/sys/class/net/$iface/device" ] || return 1

	return 0
}

wait_for_interfaces()
{
	for _ in $(seq 1 30); do
		for iface in eth0 $(ls /sys/class/net 2>/dev/null | sort); do
			is_wired_candidate "$iface" && return 0
		done
		[ -e /sys/class/net/usb0 ] && return 0
		sleep 1
	done
}

bring_up_usb0()
{
	[ -e /sys/class/net/usb0 ] || return 0

	echo "configuring usb0 static address"
	ip link set usb0 up || true
	ip addr replace 192.168.123.100/24 dev usb0 || true
}

start_dhcp()
{
	iface="$1"

	echo "configuring $iface for DHCP"
	ip link set "$iface" up || true

	if ip -4 addr show dev "$iface" | grep -q ' inet '; then
		echo "$iface already has an IPv4 address"
		return 0
	fi

	if command -v udhcpc >/dev/null 2>&1; then
		udhcpc -i "$iface" -b -q -t 5 -T 3 -p "/run/udhcpc-$iface.pid" \
			>"/tmp/${iface}_udhcpc.log" 2>&1 || true
	elif command -v dhclient >/dev/null 2>&1; then
		dhclient -4 -nw "$iface" || true
	else
		echo "no DHCP client found"
	fi
}

wait_for_interfaces
bring_up_usb0

for iface in eth0 $(ls /sys/class/net 2>/dev/null | sort); do
	is_wired_candidate "$iface" || continue
	start_dhcp "$iface"
done

echo "[$(date -Iseconds 2>/dev/null || date)] network fallback complete"
EOF

chmod 0755 "$TARGET_DIR/usr/local/sbin/lyra-network-fallback"

cat > "$TARGET_DIR/lib/systemd/system/lyra-network-fallback.service" <<'EOF'
[Unit]
Description=Luckfox Lyra network fallback
After=systemd-udev-settle.service NetworkManager.service
Wants=systemd-udev-settle.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/lyra-network-fallback
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

install -d "$TARGET_DIR/etc/systemd/system/multi-user.target.wants"
ln -rsf "$TARGET_DIR/lib/systemd/system/lyra-network-fallback.service" \
	"$TARGET_DIR/etc/systemd/system/multi-user.target.wants/lyra-network-fallback.service"
