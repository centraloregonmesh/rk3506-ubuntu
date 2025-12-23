#!/bin/bash -e

# Build and install AIC8800 WiFi modules into the kernel modules install path.
# Assumes RK_KERNEL_VERSION points to the active kernel build dir (kernel-6.1).

source "${RK_BUILD_HELPER:-$(dirname "$(realpath "$0")")/build-helper}"

usage_hook() {
    usage_oneline "aic8800-modules" "build and install AIC8800 WiFi modules"
}

BUILD_CMDS="aic8800-modules"
build_hook() {
    message "Building AIC8800 WiFi modules..."

    AIC_DIR="$RK_SDK_DIR/external/rkwifibt/drivers/aic8800/aic8800"
    if [ ! -d "$AIC_DIR" ]; then
        error "AIC8800 driver directory not found: $AIC_DIR"
        exit 1
    fi

    pushd "$AIC_DIR" >/dev/null
    make clean || true
    make KDIR="$RK_SDK_DIR/kernel-6.1" ARCH=arm \
        CROSS_COMPILE="$RK_SDK_DIR/prebuilts/gcc/linux-x86/arm/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-" \
        modules
    # Install into the rootfs staging modules dir
    MODDESTDIR="$RK_SDK_DIR/output/kernel-modules/lib/modules/$(kernel_version)"
    mkdir -p "$MODDESTDIR/kernel/drivers/net/wireless/aic8800"
    install -p -m 644 aic_load_fw/aic_load_fw.ko "$MODDESTDIR/kernel/drivers/net/wireless/aic8800/"
    install -p -m 644 aic8800_fdrv/aic8800_fdrv.ko "$MODDESTDIR/kernel/drivers/net/wireless/aic8800/"
    popd >/dev/null

    finish_build aic8800-modules
}

source "${RK_BUILD_HELPER:-$(dirname "$(realpath "$0")")/build-helper}"
