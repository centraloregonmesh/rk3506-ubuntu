#!/bin/bash
set -euo pipefail

usage()
{
	cat <<'EOF'
Usage: tools/prepare-lts-kernel.sh <6.6|6.12> [repo-url]

Creates kernel-<version> from the upstream stable branch so the Rockchip SDK can
select it with ./build.sh kernel-<version>. This is only a starting tree; RK3506
BSP patches, DTS files, configs, and out-of-tree modules still need porting.

Examples:
  tools/prepare-lts-kernel.sh 6.6
  tools/prepare-lts-kernel.sh 6.12
EOF
}

case "${1:-}" in
	6.6 | 6.12) VERSION="$1" ;;
	-h | --help | "") usage; exit 0 ;;
	*) echo "Unsupported kernel line: $1" >&2; usage >&2; exit 1 ;;
esac

SDK_DIR="$(cd "$(dirname "$(realpath "$0")")/.."; pwd)"
TARGET="$SDK_DIR/kernel-$VERSION"
REPO="${2:-https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git}"
BRANCH="linux-$VERSION.y"

if [ -e "$TARGET" ]; then
	echo "$TARGET already exists; refusing to overwrite" >&2
	exit 1
fi

git clone --depth=1 --branch "$BRANCH" "$REPO" "$TARGET"

for logo in logo.bmp logo_kernel.bmp; do
	if [ -r "$SDK_DIR/kernel-6.1/$logo" ] && [ ! -e "$TARGET/$logo" ]; then
		cp "$SDK_DIR/kernel-6.1/$logo" "$TARGET/$logo"
	fi
done

cat <<EOF
Created $TARGET from $BRANCH.

Next steps:
  1. Port RK3506 DTS/config/driver patches from kernel-6.1 into kernel-$VERSION.
  2. Run: ./build.sh kernel-$VERSION
  3. Fix compile errors until kernel-$VERSION/zboot.img is produced.
EOF
