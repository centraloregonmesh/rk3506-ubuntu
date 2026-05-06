# Ubuntu 26.04 Porting Plan

This plan tracks moving the RK3506 Ubuntu image path from the current
Ubuntu 24.04.3 prebuilt board rootfs toward Ubuntu 26.04 LTS
(`resolute`) while keeping the 24.04 flow usable.

## Current State

- The current Ubuntu rootfs is a prebuilt community board tarball:
  `ubuntu/ubuntu_24.04.3.tar.gz`.
- `device/rockchip/common/scripts/mk-ubuntu.sh` is hard-coded to extract
  `ubuntu_24.04.3.tar.gz`.
- README setup instructions fetch that tarball from:
  `https://github.com/markbirss/ubuntu_24.04.3.git`.
- The older saved rootfs script references the previous 22.04 tarball repo:
  `https://github.com/markbirss/luckfox_lyra_ubuntu22.04.git`.
- These are not plain Canonical Ubuntu Base tarballs. The 24.04.3 tarball is
  already a full board/userland rootfs with hostname `luckfox`, `/home/lyra`,
  AIC8800 artifacts, development packages, NetworkManager, and other tools.

## Official 26.04 Base Input

Canonical publishes an official Ubuntu Base 26.04 ARMHF tarball:

```text
https://cdimage.ubuntu.com/ubuntu-base/releases/resolute/release/ubuntu-base-26.04-base-armhf.tar.gz
```

SHA256:

```text
414e9d5685ff8a6f4497149544e5aa76129f51aa2b97ccd94d845a9803725b46
```

This is only a minimal Ubuntu Base rootfs, not a board-ready image. The port
must install and configure the board packages and runtime services currently
embedded in the 24.04.3 tarball.

## Branch Strategy

Create a separate branch after checkpointing the current kernel/rootfs work:

```sh
git checkout optimize-image-kernel-lts
git checkout -b feature/ubuntu-26.04-resolute
```

Do not mix the 26.04 rootfs migration into unrelated kernel-tree changes.

## Implementation Phases

1. Parameterize Ubuntu rootfs selection.
   - Add config variables such as `RK_UBUNTU_VERSION`, `RK_UBUNTU_CODENAME`,
     and `RK_UBUNTU_TARBALL`.
   - Keep the default compatible with the existing 24.04.3 tarball.
   - Update `mk-ubuntu.sh` and `mk-rootfs.sh` to avoid hard-coded
     `ubuntu_24.04.3.tar.gz`.

2. Add a 26.04 rootfs path.
   - Support `ubuntu-base-26.04-base-armhf.tar.gz` as the source tarball.
   - Verify SHA256 before extraction.
   - Keep the 24.04 prebuilt board tarball path working for fallback builds.

3. Rebuild the missing board rootfs content from hooks.
   - Install base runtime packages: `systemd-sysv`, `udev`, `dbus`,
     `netplan.io`, `network-manager`, `openssh-server`, `ca-certificates`,
     `curl`, `gnupg`, `iproute2`, `iw`, `wireless-tools`, `rfkill`,
     `dnsutils`, `rsync`, `tcpdump`, `file`, and similar board utilities.
   - Install container packages: `containerd`, `runc`, `podman`,
     `fuse-overlayfs`, `slirp4netns`, `uidmap`, and optionally `docker.io`
     or an explicitly chosen Docker repository.
   - Recreate users, hostname, SSH defaults, machine-id handling, firmware,
     module installation, AIC8800 staging, and cleanup steps.

4. Confirm 26.04 system behavior.
   - Ubuntu 26.04 uses modern systemd and should run cgroup v2 only.
   - Ensure no boot args or systemd settings force cgroup v1 or hybrid mode.
   - Confirm the RK3506 kernels provide cgroup v2, memory cgroups, swap,
     overlayfs, FUSE/CUSE, seccomp, BPF, veth, bridge netfilter, nftables,
     iptables compatibility, and IPVS.

5. Build and package images.
   - First target `kernel-6.12`, because it is the active preferred LTS tree.
   - Then validate packaging with `kernel-6.1` and `kernel-6.6`.
   - Confirm `/lib/modules/$(uname -r)` in the rootfs matches the flashed
     kernel and includes AIC8800 modules where expected.

## Validation Checklist

After flashing a 26.04 image:

```sh
cat /etc/os-release
uname -a
ls /lib/modules
stat -fc %T /sys/fs/cgroup
cat /sys/fs/cgroup/cgroup.controllers
```

Expected cgroup type:

```text
cgroup2fs
```

Expected controllers should include at least:

```text
cpu cpuset io memory pids
```

Check swap cgroup files in a child cgroup:

```sh
sudo mkdir /sys/fs/cgroup/testcg
ls /sys/fs/cgroup/testcg/memory.swap.*
sudo rmdir /sys/fs/cgroup/testcg
```

Check board basics:

```sh
systemctl --failed
ip addr
nmcli device
timedatectl
ssh localhost true
```

Check AIC8800 and Meshtastic-relevant interfaces:

```sh
find /lib/modules/$(uname -r) -name '*aic*' -o -name 'cfg80211.ko'
dmesg | grep -Ei 'aic|cfg80211|usb|uart|spi|gpio'
ls -l /dev/tty* /dev/spidev* 2>/dev/null
```

Check containers:

```sh
containerd --version
runc --version
podman info
podman run --rm docker.io/library/alpine:latest uname -a
podman run --rm --memory=64m docker.io/library/alpine:latest sh -c \
  'cat /sys/fs/cgroup/memory.max; cat /sys/fs/cgroup/memory.swap.max'
```

Rootless Podman also needs:

- `uidmap`
- `slirp4netns`
- `fuse-overlayfs`
- valid `/etc/subuid`
- valid `/etc/subgid`
- user namespaces permitted by distro policy

## Main Risks

- The official 26.04 tarball is minimal, so missing packages/services will
  show up as boot or networking failures unless hooks recreate the full board
  rootfs.
- Tailscale and Docker third-party repositories may lag or use different
  repository names for `resolute`; prefer Ubuntu archive packages first unless
  a newer upstream package is required.
- 26.04 cgroup behavior is stricter than older releases. Kernel support is in
  place, but userspace validation is required.
- The existing 24.04.3 tarball contains historical board artifacts and build
  leftovers. Some may be required; some should be deliberately omitted in the
  reproducible 26.04 path.
