#!/usr/bin/env bash
#
# RZ/V2H Ubuntu 22.04 Full Image Builder
# Author: ChatGPT for Varshini
# Version: FINAL - Super Robust
# Date: July 2025

set -euo pipefail

# ======== CONFIG ========
SDCARD_DEVICE="/dev/sdX" # <<< !!! EDIT THIS !!! e.g., /dev/sdb
UBUNTU_ROOTFS_URL="http://cdimage.ubuntu.com/ubuntu-base/releases/22.04/release/ubuntu-base-22.04-base-arm64.tar.gz"
KERNEL_BRANCH="rzv2h-linux-v1.0.2"
UBOOT_REPO="https://github.com/renesas-rz/rza_u-boot-2015.01.git"
KERNEL_REPO="https://github.com/renesas-rz/linux-cip.git"
DRPAI_DRIVER_REPO="https://github.com/renesas-rz/rzv2h_drp-ai_driver.git"
DRPAI_RUNTIME_URL="https://github.com/renesas-rz/rzv_drp-ai_tvm/releases/download/v1.0.0/drpai_runtime_rzv2h.tar.gz"

WORKDIR="$PWD/rzv2h_build"
BOOT_MNT="/mnt/rzv2h-boot"
ROOTFS_MNT="/mnt/rzv2h-root"

# ======== FUNCTIONS ========
abort() {
  echo "❌ ERROR: $1"
  exit 1
}

require() {
  command -v "$1" >/dev/null 2>&1 || abort "$1 is not installed"
}

echo_section() {
  echo ""
  echo "=================================================="
  echo "==> $1"
  echo "=================================================="
}

# ======== CHECK TOOLS ========
echo_section "Checking required tools..."
for tool in git wget curl parted mkimage gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi; do
  require "$tool"
done

# ======== CONFIRM SD CARD ========
echo_section "SD Card WARNING"
echo "⚠️  About to WIPE $SDCARD_DEVICE COMPLETELY."
lsblk "$SDCARD_DEVICE"
read -p "Type 'YES' to continue: " confirm
[ "$confirm" == "YES" ] || abort "Aborted by user."

# ======== PREP BUILD DIR ========
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# ======== INSTALL DEPENDENCIES ========
echo_section "Installing dependencies..."
sudo apt update
sudo apt install -y build-essential device-tree-compiler u-boot-tools \
  bison flex libssl-dev gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi \
  wget curl parted kpartx qemu-user-static debootstrap xz-utils unzip tar

# ======== CLONE & BUILD KERNEL ========
echo_section "Cloning kernel..."
git clone --depth=1 --branch "$KERNEL_BRANCH" "$KERNEL_REPO" kernel
cd kernel
echo_section "Building kernel..."
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig
make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- Image dtbs modules
KERNEL_VER=$(make kernelrelease)
cd ..

# ======== CLONE & BUILD U-BOOT ========
echo_section "Cloning U-Boot..."
git clone --depth=1 "$UBOOT_REPO" uboot
cd uboot
echo_section "Building U-Boot..."
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- renesas_rzv2h_evk_defconfig
make -j$(nproc) ARCH=arm CROSS_COMPILE=arm-linux-gnueabi-
cd ..

# ======== DOWNLOAD UBUNTU ROOTFS ========
echo_section "Downloading Ubuntu rootfs..."
wget -c "$UBUNTU_ROOTFS_URL" -O ubuntu-rootfs.tar.gz
mkdir -p rootfs
sudo tar -xpf ubuntu-rootfs.tar.gz -C rootfs

# ======== INSTALL KERNEL MODULES ========
echo_section "Installing kernel modules..."
sudo make -C kernel ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- INSTALL_MOD_PATH=./rootfs modules_install

# ======== SET HOSTNAME AND ROOT PASSWORD ========
echo_section "Configuring rootfs..."
echo "rzv2h" | sudo tee rootfs/etc/hostname
echo "root:root" | sudo chroot rootfs chpasswd || true

# ======== BUILD & INSTALL DRP-AI DRIVER ========
echo_section "Cloning DRP-AI driver..."
git clone "$DRPAI_DRIVER_REPO" drpai_driver
cd drpai_driver
echo_section "Building DRP-AI driver..."
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- KERNEL_DIR=../kernel
sudo mkdir -p ../rootfs/lib/modules/"$KERNEL_VER"/kernel/drpai
sudo cp drpai-driver.ko ../rootfs/lib/modules/"$KERNEL_VER"/kernel/drpai/
cd ..

# ======== DOWNLOAD & INSTALL DRP-AI RUNTIME ========
echo_section "Downloading DRP-AI runtime..."
wget -c "$DRPAI_RUNTIME_URL" -O drpai_runtime.tar.gz
sudo tar -xpf drpai_runtime.tar.gz -C rootfs/

# ======== CREATE BOOT SCRIPT ========
echo_section "Creating boot script..."
cat <<EOF > boot.cmd
setenv bootargs console=ttySC0,115200 root=/dev/mmcblk0p2 rw rootwait
load mmc 0:1 0x48080000 Image
load mmc 0:1 0x48000000 renesas/r9a09g057l2.dtb
booti 0x48080000 - 0x48000000
EOF

mkimage -A arm64 -T script -C none -n "boot script" -d boot.cmd boot.scr

# ======== PARTITION & FORMAT SD CARD ========
echo_section "Partitioning SD card..."
sudo parted "$SDCARD_DEVICE" mklabel gpt
sudo parted -a optimal "$SDCARD_DEVICE" mkpart primary fat32 1MiB 512MiB
sudo parted -a optimal "$SDCARD_DEVICE" mkpart primary ext4 512MiB 100%
sudo mkfs.vfat "${SDCARD_DEVICE}1"
sudo mkfs.ext4 "${SDCARD_DEVICE}2"

# ======== MOUNT PARTITIONS ========
sudo mkdir -p "$BOOT_MNT" "$ROOTFS_MNT"
sudo mount "${SDCARD_DEVICE}1" "$BOOT_MNT"
sudo mount "${SDCARD_DEVICE}2" "$ROOTFS_MNT"

# ======== COPY BOOT FILES ========
echo_section "Copying boot files..."
sudo cp kernel/arch/arm64/boot/Image "$BOOT_MNT/"
sudo cp kernel/arch/arm64/boot/dts/renesas/*.dtb "$BOOT_MNT/"
sudo cp boot.scr "$BOOT_MNT/"

# ======== COPY ROOTFS ========
echo_section "Copying rootfs..."
sudo cp -a rootfs/* "$ROOTFS_MNT/"

sync

# ======== VERIFY STRUCTURE ========
echo_section "Verifying SD card contents..."
[ -f "$BOOT_MNT/Image" ] || abort "Kernel Image missing in BOOT partition!"
[ -f "$BOOT_MNT/boot.scr" ] || abort "boot.scr missing!"
[ -d "$ROOTFS_MNT/lib/modules" ] || abort "Kernel modules missing!"

# ======== CLEAN UP ========
sudo umount "$BOOT_MNT"
sudo umount "$ROOTFS_MNT"

echo_section "✅ DONE - Your SD card is ready!"
echo "👉 Default login: root / root"
echo "👉 Insert SD card and boot RZ/V2H EVK."

exit 0
