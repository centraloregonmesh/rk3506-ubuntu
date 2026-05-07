#!/bin/bash -e

# Build and install AIC8800 WiFi modules into the kernel modules install path.
# Build against the active kernel symlink so kernel-6.6/kernel-6.12 can be used.

usage_hook() {
    usage_oneline "aic8800-modules[:<dst dir>]" "build and install AIC8800 WiFi modules"
}

BUILD_CMDS="aic8800-modules"
build_hook() {
	shift
	message "Building AIC8800 WiFi modules..."

	AIC_DIR="$RK_SDK_DIR/external/rkwifibt/drivers/aic8800/aic8800"
    if [ ! -d "$AIC_DIR" ]; then
        error "AIC8800 driver directory not found: $AIC_DIR"
        exit 1
    fi

    pushd "$AIC_DIR" >/dev/null
    make clean || true
	KERNEL_DIR="${RK_KERNEL_DIR:-$RK_SDK_DIR/kernel}"
	TOOLCHAIN="${RK_KERNEL_TOOLCHAIN:-$RK_SDK_DIR/prebuilts/gcc/linux-x86/arm/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-}"
	make KDIR="$KERNEL_DIR" ARCH="${RK_KERNEL_ARCH:-arm}" \
		CROSS_COMPILE="$TOOLCHAIN" \
		KCFLAGS="-Wno-error=missing-prototypes -Wno-error=implicit-fallthrough" \
		modules
	# Install into the modules/firmware staging tree for rootfs.
	KVER="$(make -s -C "$KERNEL_DIR" ARCH="${RK_KERNEL_ARCH:-arm}" kernelrelease)"
	MODROOT="${1:-$RK_OUTDIR/kernel-modules}"
	case "$MODROOT" in
		/*) ;;
		*) MODROOT="$RK_SDK_DIR/$MODROOT" ;;
	esac
	MODDEST="$MODROOT/lib/modules/$KVER/extra/aic8800"
	mkdir -p "$MODDEST"
	install -p -m 644 aic_load_fw/aic_load_fw.ko "$MODDEST/"
	install -p -m 644 aic8800_fdrv/aic8800_fdrv.ko "$MODDEST/"

	# Firmware
	FWDEST="$MODROOT/lib/firmware/aicsemi"
	mkdir -p "$FWDEST"
	if [ -d "$RK_SDK_DIR/external/rkwifibt/firmware/aicsemi" ]; then
		cp -r "$RK_SDK_DIR/external/rkwifibt/firmware/aicsemi/"* "$FWDEST/" 2>/dev/null || true
	fi
	if [ -d "$FWDEST/aic8800DC" ]; then
		rm -rf "$MODROOT/lib/firmware/aic8800DC"
		cp -a "$FWDEST/aic8800DC" "$MODROOT/lib/firmware/aic8800DC"
	fi
	depmod -b "$MODROOT" "$KVER"
	popd >/dev/null

	finish_build aic8800-modules
}

source "${RK_BUILD_HELPER:-$(dirname "$(realpath "$0")")/build-helper}"
