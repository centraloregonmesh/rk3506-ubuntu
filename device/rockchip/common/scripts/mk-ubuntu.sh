#!/bin/bash -e

function RUN_NOTICE() {
	local command="$1"
	notice $command
	$command
}

RK_SCRIPTS_DIR="${RK_SCRIPTS_DIR:-$(dirname "$(realpath "$0")")}"
RK_SDK_DIR="${RK_SDK_DIR:-$RK_SCRIPTS_DIR/../../../..}"

ROOTFS_OUTPUT_DIR="$RK_SDK_DIR/output/ubuntu"
UBUNTU_DIR="$RK_SDK_DIR/ubuntu"

#"$RK_SCRIPTS_DIR/check-ubuntu.sh" #check md5

UBUNTU_OUTPUT_DIR="$UBUNTU_DIR/output"

SRC_DIR="$UBUNTU_OUTPUT_DIR/target"
IMAGE_DIR="$UBUNTU_OUTPUT_DIR/images"
EXT4_IMAGE="$IMAGE_DIR/rootfs.ext4"

# Save the original .config if exists
if [ -r "$BUILDROOT_CONFIG" ] && [ ! -r "$BUILDROOT_CONFIG_ORIG" ]; then
	cp "$BUILDROOT_CONFIG" "$BUILDROOT_CONFIG_ORIG"
fi

if [ -d  "$SRC_DIR"  ] ;then
	rm -rf "$SRC_DIR"
fi
mkdir -p "$SRC_DIR"

# build ubuntu target
tar -xf "$UBUNTU_DIR/ubuntu_24.04.3.tar.gz" -C "$SRC_DIR"

# post build target
mkdir -p "$SRC_DIR/lib/modules"
chmod -R a+wX "$SRC_DIR/lib/modules"
#"$RK_SCRIPTS_DIR/mk-kernel.sh" modules "$SRC_DIR"
"$RK_SCRIPTS_DIR/post-rootfs.sh" "$SRC_DIR"

# mkimage ext4
rm -rf "$IMAGE_DIR"
mkdir -p "$IMAGE_DIR"

DST_SIZE="${RK_UBUNTU_EXT4_SIZE:-2048M}"

RUN_NOTICE "mkfs.ext4 -d $SRC_DIR -r 1 -N 0 -m 0 -L \"\" -O ^64bit,^huge_file $EXT4_IMAGE "$DST_SIZE""
RUN_NOTICE "e2fsck -fy  $EXT4_IMAGE"
RUN_NOTICE "tune2fs -m 0  $EXT4_IMAGE"
RUN_NOTICE "e2fsck -fy  $EXT4_IMAGE"

# Use ubuntu output dir as image output dir
rm -rf "$ROOTFS_OUTPUT_DIR"
ln -rsf "$UBUNTU_OUTPUT_DIR" "$ROOTFS_OUTPUT_DIR"
