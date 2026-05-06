#!/bin/sh

set -u

section()
{
	printf '\n== %s ==\n' "$1"
}

run()
{
	printf '$ %s\n' "$*"
	"$@" 2>&1 || printf 'command failed: %s\n' "$*"
}

section "identity"
run uname -a
run uname -r
run cat /etc/os-release
run cat /proc/cmdline
if [ -r /proc/device-tree/model ]; then
	printf '$ cat /proc/device-tree/model\n'
	tr '\0' '\n' < /proc/device-tree/model
	printf '\n'
fi
if [ -r /proc/device-tree/compatible ]; then
	printf '$ tr "\\0" "\\n" < /proc/device-tree/compatible\n'
	tr '\0' '\n' < /proc/device-tree/compatible
fi

section "modules"
run find /lib/modules -maxdepth 1 -mindepth 1 -type d -printf '%f\n'
if command -v modinfo >/dev/null 2>&1; then
	run modinfo phy_rockchip_inno_usb2
fi

section "network"
run ip addr
run ip route
if command -v nmcli >/dev/null 2>&1; then
	run nmcli device status
	run nmcli connection show
fi

section "ssh"
run ls -l /etc/ssh
run systemctl status lyra-ssh-hostkeys.service
run systemctl status ssh.socket
run systemctl status ssh.service
if command -v ss >/dev/null 2>&1; then
	run ss -lntp
fi

section "services"
run systemctl status lyra-network-fallback.service
run systemctl status lyra-usb-gadget.service

section "kernel logs"
run dmesg
printf '\n== filtered kernel logs ==\n'
dmesg 2>&1 | grep -Ei 'mmc|EXT4|VFS|gmac|stmmac|eth|phy|mdio|dwmac|gpio|led|heartbeat|pvtpll|clk|usb0|rndis|ssh|systemd' || true
