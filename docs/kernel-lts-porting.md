# RK3506 LTS Kernel Porting

The SDK can switch between side-by-side kernel trees named `kernel-*`. The
active `kernel` path is a symlink managed by `./build.sh kernel-<version>`.

Initial source trees can be created with:

```sh
tools/prepare-lts-kernel.sh 6.6
tools/prepare-lts-kernel.sh 6.12
```

Then select a tree with:

```sh
./build.sh kernel-6.6
./build.sh kernel-6.12
```

These upstream stable trees are not expected to be fully board-ready without
RK3506 BSP porting. The initial 6.6 and 6.12 trees have enough RK3506 plumbing
copied from `kernel-6.1` to build the configured DTS, in-tree modules, and
Rockchip boot images:

```sh
./build.sh kernel-6.6
./build.sh kernel-6.6 kernel-modules:output/kernel-modules-6.6
./build.sh aic8800-modules:output/kernel-modules-6.6
./build.sh kernel-6.12
./build.sh kernel-6.12 kernel-modules:output/kernel-modules-6.12
./build.sh aic8800-modules:output/kernel-modules-6.12
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

Remaining board-readiness work includes:

- audit and port missing Rockchip clock, pinctrl, GPIO, MMC, USB, SPI, UART,
  display, power, and SoC driver patches from `kernel-6.1`
- boot-test each image and verify Meshtastic radio interfaces

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
6. Next: boot each image to shell.
7. Next: verify Meshtastic radio interfaces: USB/UART/SPI plus GPIO IRQ/reset
   pins as applicable.
8. Next: install and test container userspace on target hardware. Rootless
   Podman also needs `uidmap`, `slirp4netns`, `fuse-overlayfs`,
   `/etc/subuid`, `/etc/subgid`, and user namespaces permitted by sysctl or
   distro policy.
