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

run_root()
{
	if [ "$(id -u)" -eq 0 ]; then
		run "$@"
	elif command -v sudo >/dev/null 2>&1; then
		run sudo "$@"
	else
		printf '$ %s\n' "$*"
		printf 'command skipped: root privileges required\n'
	fi
}

root_device()
{
	local dev

	dev="$(findmnt -no SOURCE / 2>/dev/null || true)"
	if [ -n "$dev" ] && [ "$dev" != /dev/root ]; then
		printf '%s\n' "$dev"
		return
	fi

	sed -n 's/.* root=\([^ ]*\).*/\1/p' /proc/cmdline
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

section "root filesystem"
ROOT_DEV="$(root_device)"
printf 'root device: %s\n' "${ROOT_DEV:-unknown}"
run findmnt /
run df -h /
if [ -n "${ROOT_DEV:-}" ]; then
	run_root tune2fs -l "$ROOT_DEV"
fi

section "modules"
run find /lib/modules -maxdepth 1 -mindepth 1 -type d -printf '%f\n'
run find /lib/modules -name 'aic*.ko' -printf '%p\n'
if command -v lsmod >/dev/null 2>&1; then
	run lsmod
fi

section "network"
run ip addr
run ip route
if command -v nmcli >/dev/null 2>&1; then
	run nmcli device status
	run nmcli connection show
fi

section "optional wifi"
if command -v wifibt-info >/dev/null 2>&1; then
	run wifibt-info -f
	run wifibt-module
fi
run systemctl status wifibt-init.service
if command -v lsusb >/dev/null 2>&1; then
	run lsusb
fi
run find /lib/firmware -maxdepth 3 -path '*aic*' -printf '%p\n'

section "usb gadget"
run systemctl status lyra-usb-gadget.service
if [ -d /sys/kernel/config/usb_gadget/rockchip ]; then
	run cat /sys/kernel/config/usb_gadget/rockchip/UDC
	if [ -d /sys/kernel/config/usb_gadget/rockchip/functions/rndis.usb0 ]; then
		run cat /sys/kernel/config/usb_gadget/rockchip/functions/rndis.usb0/dev_addr
		run cat /sys/kernel/config/usb_gadget/rockchip/functions/rndis.usb0/host_addr
	fi
fi
if [ -d /sys/class/net/usb0 ]; then
	run cat /sys/class/net/usb0/address
	run ip -s link show usb0
fi
if [ -e /sys/class/udc/ff740000.usb/state ]; then
	run cat /sys/class/udc/ff740000.usb/state
fi

section "time"
run date -u
run readlink /etc/localtime
if [ -r /etc/timezone ]; then
	run cat /etc/timezone
fi
if command -v timedatectl >/dev/null 2>&1; then
	run timedatectl
fi
run systemctl status systemd-timesyncd.service

section "ssh"
run ls -l /etc/ssh
run systemctl status lyra-ssh-hostkeys.service
run systemctl status ssh.socket
run systemctl status ssh.service
if command -v ss >/dev/null 2>&1; then
	run ss -lntp
fi

section "container runtime"
run id lyra
run stat -fc %T /sys/fs/cgroup
run cat /proc/cgroups
run mount
if command -v docker >/dev/null 2>&1; then
	run docker --version
	run docker info
fi
if command -v containerd >/dev/null 2>&1; then
	run containerd --version
	run systemctl status containerd.service
fi
if command -v podman >/dev/null 2>&1; then
	run podman --version
	run podman info
fi

section "services"
run systemctl status lyra-network-fallback.service
run systemctl status lyra-usb-gadget.service
run systemctl status docker.service

section "kernel logs"
printf '\n== filtered kernel logs ==\n'
dmesg 2>&1 | grep -Ei 'mmc|EXT4|JBD2|EFSBADCRC|VFS|gmac|stmmac|eth|phy|mdio|dwmac|gpio|led|heartbeat|pvtpll|clk|usb0|rndis|aic|wlan|wifi|bluetooth|cfg80211|ssh|docker|containerd|podman|cgroup|systemd' || true
