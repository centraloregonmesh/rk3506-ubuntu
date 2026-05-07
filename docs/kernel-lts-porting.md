# RK3506 LTS Kernel Porting

The SDK can switch between side-by-side kernel trees named `kernel-*`. The
active `kernel` path is a symlink managed by `./build.sh kernel-<version>`.

Initial source trees can be created with:

```sh
tools/prepare-lts-kernel.sh 6.6
tools/prepare-lts-kernel.sh 6.12
tools/prepare-lts-kernel.sh 6.18
```

Then select a tree with:

```sh
./build.sh kernel-6.6
./build.sh kernel-6.12
./build.sh kernel-6.18
```

These upstream stable trees are not expected to be fully board-ready without
RK3506 BSP porting. The initial 6.6 and 6.12 trees have enough RK3506 plumbing
copied from `kernel-6.1` to build the configured DTS, in-tree modules, and
Rockchip boot images. The 6.18 LTS tree is the next target and should start
from the known-working 6.12 RK3506 port surface:

```sh
./build.sh kernel-6.6
./build.sh kernel-6.6 kernel-modules:output/kernel-modules-6.6
./build.sh aic8800-modules:output/kernel-modules-6.6
./build.sh kernel-6.12
./build.sh kernel-6.12 kernel-modules:output/kernel-modules-6.12
./build.sh aic8800-modules:output/kernel-modules-6.12
./build.sh kernel-6.18
./build.sh kernel-6.18 kernel-modules:output/kernel-modules-6.18
./build.sh aic8800-modules:output/kernel-modules-6.18
```

The initial copied BSP surface includes:

- `arch/arm/boot/dts/rk3506*`
- `arch/arm/boot/dts/rk3502*`
- `arch/arm/configs/rk3506_luckfox_defconfig`
- `arch/arm/configs/rk3506-display.config`
- selected RK3506 dt-bindings needed by those DTS files
- Rockchip `mkimg`/resource tooling needed to generate `zboot.img`
- the BSP `CONFIG_DRM_IGNORE_IOTCL_PERMIT` compatibility option required by
  the SDK kernel check
- `CONFIG_CFG80211=m` and `CONFIG_CFG80211_WEXT=y`, required by the AIC8800
  WiFi module
- `arch/arm/configs/rk3506-docker.config`, enabled through
  `RK_KERNEL_CFG_FRAGMENTS`, for Docker, containerd, and Podman kernel
  requirements: namespaces, cgroups, memory cgroups with swap support,
  seccomp, BPF, overlayfs, FUSE/CUSE,
  veth/bridge networking, nftables/iptables NAT, and IPVS

Modern 6.1, 6.6, and 6.12 kernels do not expose a `CONFIG_MEMCG_SWAP` Kconfig
symbol. Memcg swap accounting is built from `CONFIG_MEMCG=y` plus
`CONFIG_SWAP=y`; `mm/swap_cgroup.o` is compiled when both are enabled. Runtime
validation should check for cgroup v2 `memory.swap.current` and
`memory.swap.max` files in non-root memory cgroups.

## Lyra Ultra / Ultra W 6.18 status

The Luckfox Lyra Ultra / Ultra W 6.18 port uses one shared Ubuntu 24.04.4 image
for both boards. The canonical build target remains
`luckfox_lyra_ultra_ubuntu_emmc_defconfig`, but it now uses the Ultra W DTS and
includes optional AIC8800DC WiFi/Bluetooth support. On a plain Ultra, no AIC USB
radio enumerates, so the WiFi/Bluetooth service exits without enabling a radio
interface and does not block Ethernet, SSH, Docker, containerd, Podman, cgroup
v2, or USB RNDIS.

The current management USB contract is intentionally RNDIS-only:

- device address: `192.168.123.100/24`
- host address: `192.168.123.1/24`
- access method: SSH/SCP/rsync over USB Ethernet

ADB is not part of the production Lyra Ubuntu image, and the boot-time gadget
does not configure a FunctionFS ADB function. ADB adds a second management stack
and an extra gadget failure mode without replacing anything needed for normal
Linux administration.

On a Linux host, after the RNDIS interface appears, configure it with:

```sh
sudo ip addr replace 192.168.123.1/24 dev <usb-rndis-interface>
sudo ip link set <usb-rndis-interface> up
ping -c 4 192.168.123.100
ssh lyra@192.168.123.100
```

On the board, run:

```sh
/usr/local/sbin/validate-lyra-6.18
```

The validation output should show:

- `uname -r` as `6.18.26`
- `/etc/localtime` pointing at `Etc/UTC`
- `timedatectl` synchronized through `systemd-timesyncd`
- `end1` DHCP and `usb0` at `192.168.123.100/24`
- RNDIS `dev_addr` matching `/sys/class/net/usb0/address`
- `/sys/class/udc/ff740000.usb/state` as `configured`
- AIC8800DC modules under `/lib/modules/6.18.26/updates`
- AIC8800DC firmware under `/lib/firmware/aicsemi/aic8800DC` and
  `/lib/firmware/aic8800DC`
- `wifibt-init.service` enabled; plain Ultra boards may report no detected
  WiFi/BT chip, while Ultra W boards should detect the AIC8800DC and create a
  wireless interface after the module loads
- Docker using cgroup v2 and the `overlayfs` storage driver
- containerd and Podman reporting healthy runtime info

The root filesystem image is still built as a compact 2 GiB ext4 image and
grown on first boot. The image build refreshes the ext4 journal after
`mkfs.ext4 -d` so `metadata_csum` remains enabled while avoiding stale journal
CRC failures at first mount.

Current clean rebuild artifact:

- image:
  `output/update/Image/lyra-ultra-ultra-w-emmc-ubuntu24.04-kernel6.18.26.img`
- SHA256: `00d8e480330eb8364099f9fbcffa677481b31b525ec4c0cf0fd1db74953cbb8f`
- checksum file:
  `output/update/Image/lyra-ultra-ultra-w-emmc-ubuntu24.04-kernel6.18.26.img.sha256`
- rootfs: 2 GiB ext4 with `metadata_csum`, refreshed journal, and 0 reserved
  blocks
- rootfs SHA256:
  `8b3f9170db30c0fcd7b8f2c249275e60c3a7318b36d41d53b2f8f02346603da3`

Publishable image artifacts should include the target board/storage, Ubuntu
series, and full kernel release:

```text
lyra-ultra-ultra-w-emmc-ubuntu24.04-kernel<kernel-release>.img
lyra-ultra-ultra-w-emmc-ubuntu24.04-kernel<kernel-release>.img.sha256
```

That keeps new patch-level kernel builds publishable side-by-side without
overwriting older validated images.

Final clean image hardware validation:

- `uname -r`: `6.18.26`
- Ubuntu: `24.04.4 LTS`
- rootfs: `/dev/mmcblk0p3`, grown to 7.1 GiB, clean ext4 with
  `metadata_csum`
- Ethernet: `end1` DHCP on `192.168.100.122/24`
- USB RNDIS: `usb0` up on `192.168.123.100/24`
- USB gadget: `ff740000.usb`, UDC state `configured`
- RNDIS MAC: `dev_addr` matches `/sys/class/net/usb0/address`
- optional WiFi: AIC8800DC modules and firmware installed; no WiFi interface is
  expected on plain Ultra hardware without the AIC radio
- time: `Etc/UTC`, `systemd-timesyncd` synchronized
- services: SSH, `lyra-usb-gadget`, `lyra-network-fallback`, Docker, and
  containerd active; `wifibt-init` enabled
- containers: Docker `29.1.3`, containerd `2.2.1`, Podman `4.9.3`, cgroup v2,
  Docker `overlayfs`

Remaining board-readiness work includes:

- audit and port missing Rockchip clock, pinctrl, GPIO, MMC, USB, SPI, UART,
  display, power, and SoC driver patches from `kernel-6.1`
- verify Meshtastic radio interfaces

Milestones:

1. Done: `kernel-6.6/zboot.img` is produced through the SDK path with
   modules enabled.
2. Done: `kernel-6.12/zboot.img` is produced through the SDK path with
   modules enabled.
3. Done: matching in-tree modules build for 6.6 and 6.12; the current clean
   Lyra Ultra Ubuntu image installs 6.12 modules under `/lib/modules/6.12.85`.
4. Done: AIC8800 `aic_load_fw.ko` and `aic8800_fdrv.ko` build and install into
   both staged module trees, with `modules.dep` refreshed by `depmod`.
5. Done: Docker/containerd/Podman kernel support is enabled in the 6.1, 6.6,
   and 6.12 generated configs.
6. Done: create and port `kernel-6.18` from upstream `linux-6.18.y`.
7. Done: boot the Lyra Ultra 6.18 image to shell with Ethernet, SSH, Docker,
   containerd, Podman, time sync, and USB RNDIS.
8. Done: remove temporary 6.18 diagnostics and rebuild a clean RNDIS-only
   image.
9. Done: flash-test the final clean Ultra image and run
   `/usr/local/sbin/validate-lyra-6.18`.
10. Done: add AIC8800DC modules, firmware, and runtime service support for a
    unified Ultra / Ultra W image.
11. Next: flash-test the unified image on plain Ultra for regression and on
    Ultra W for WiFi/Bluetooth enumeration.
12. Next: verify Meshtastic radio interfaces: USB/UART/SPI plus GPIO IRQ/reset
    pins as applicable.
