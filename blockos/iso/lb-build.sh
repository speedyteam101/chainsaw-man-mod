#!/usr/bin/env bash
# Runs inside a Debian container (started by build-iso.sh) and builds the ISO with live-build.
set -euo pipefail

ARCH="${ARCH:?ARCH must be set}"
DIST="${DIST:-trixie}"
BUILD_DIR=/build

apt-get update
apt-get install -y --no-install-recommends live-build ca-certificates

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

if [ "$ARCH" = amd64 ]; then
  BOOTLOADERS="syslinux,grub-efi"   # BIOS and UEFI
else
  BOOTLOADERS="grub-efi"            # arm64 boots with UEFI only
fi

lb config \
  --distribution "$DIST" \
  --architectures "$ARCH" \
  --archive-areas "main" \
  --binary-images iso-hybrid \
  --bootloaders "$BOOTLOADERS" \
  --debian-installer none \
  --memtest none \
  --iso-application "BlockOS" \
  --iso-volume "BlockOS" \
  --iso-publisher "BlockOS" \
  --bootappend-live "boot=live components quiet splash username=user hostname=blockos"

mkdir -p config/includes.chroot/opt/blockos-src config/package-lists config/hooks/normal
cp -r /blockos/shell /blockos/system config/includes.chroot/opt/blockos-src/
cp /blockos/iso/blockos.list.chroot config/package-lists/
install -m 755 /blockos/iso/9000-blockos.hook.chroot config/hooks/normal/

lb build

iso=$(find . -maxdepth 1 -name "*.iso" -print -quit)
cp "$iso" "/out/blockos-$DIST-$ARCH.iso"
echo "Built /out/blockos-$DIST-$ARCH.iso"
