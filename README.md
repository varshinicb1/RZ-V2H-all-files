```
# Building and Deploying ROS2 Galactic with core-image-weston on RZ/V2H EVK

This guide provides a complete, step-by-step process to build and deploy the `core-image-weston` Yocto image with ROS2 Galactic on the Renesas RZ/V2H evaluation kit (EVK) using Ubuntu 20.04 LTS. It incorporates lessons learned from a successful build, addressing issues like file conflicts and host contamination, to ensure a smooth, one-go process. The guide aligns with the Renesas ROS2 Installation Guide (R01AN7366EJ0110) and is optimized for a system with 16GB RAM (32GB recommended).

## Prerequisites

- **Host System**: Fresh Ubuntu 20.04 LTS installation with at least 800GB free disk space (preferably on an SSD) and 16GB RAM (32GB recommended).
- **RZ/V2H EVK**: Renesas RZ/V2H evaluation kit (R9A09G057 SoC).
- **SD Card**: 32GB or larger microSD card for the image.
- **Serial Cable**: For bootloader programming and debugging (e.g., USB-to-serial adapter).
- **Dependencies**: Install required packages for Yocto builds.
  ```bash
  sudo apt update
  sudo apt install -y gawk wget git-core diffstat unzip texinfo gcc-multilib \
  build-essential chrpath socat cpio python3 python3-pip python3-pexpect \
  xz-utils debianutils iputils-ping python3-git python3-jinja2 libegl1-mesa \
  libsdl1.2-dev pylint3 xterm python3-subunit mesa-common-dev zstd liblz4-tool
  ```
- **Disk Space**: Verify sufficient free space (~800-900GB recommended).
  ```bash
  df -h /
  df -h /home
  ```
- **Internet**: Stable connection for downloading sources and repositories.

## Step 1: Set Up the Build Environment

1. **Create a Working Directory**:
   ```bash
   mkdir -p ~/ai_sdk_work/src_setup/yocto
   cd ~/ai_sdk_work/src_setup/yocto
   ```

2. **Clone Required Repositories**:
   - Clone the Yocto Poky repository (Dunfell branch, compatible with ROS2 Galactic):
     ```bash
     git clone -b dunfell git://git.yoctoproject.org/poky
     ```
   - Clone Renesas RZ/V2H layers:
     ```bash
     git clone -b dunfell git://github.com/renesas-rz/meta-renesas
     ```
   - Clone meta-openembedded for additional packages:
     ```bash
     git clone -b dunfell git://git.openembedded.org/meta-openembedded
     ```
   - Clone meta-ros and ROS2 Galactic layers:
     ```bash
     git clone -b build --single-branch https://github.com/ros/meta-ros.git meta-ros-build
     cd meta-ros-build
     git checkout 72c59f58923295ae0519cbe148b4ceda1616b6b4
     mkdir conf
     ./scripts/mcf -f files/ros2-galactic-dunfell.mcf
     cd ..
     cp -Rp meta-ros-build/meta-ros .
     ```
   - Clone meta-rz-features-ros for RZ/V2H ROS2 support:
     ```bash
     git clone -b dunfell https://github.com/renesas-rz/meta-rz-features-ros
     ```
   - Clone meta-rzv2-ros-galactic for RZ/V2H ROS2 support:
     ```bash
     git clone https://github.com/renesas-rz/meta-rzv2-ros-galactic
     ```

3. **Copy and Apply ROS2 Galactic Patch**:
   - Copy the patch files from meta-rz-features-ros:
     ```bash
     cp -Rp ~/ai_sdk_work/src_setup/yocto/meta-rz-features-ros/meta-ros-galactic.patch .
     cp -Rp ~/ai_sdk_work/src_setup/yocto/meta-rz-features-ros/patch_meta-rzv2h-ros-galactic.sh .
     chmod +x patch_meta-rzv2h-ros-galactic.sh
     ./patch_meta-rzv2h-ros-galactic.sh -f
     ```

## Step 2: Configure Yocto Build

1. **Initialize the Build Environment**:
   ```bash
   cd ~/ai_sdk_work/src_setup/yocto/poky
   source oe-init-build-env ../build
   ```

2. **Configure `bblayers.conf`**:
   - Edit `~/ai_sdk_work/src_setup/yocto/build/conf/bblayers.conf` to include required layers:
     ```bash
     nano conf/bblayers.conf
     ```
     - Replace the `BBLAYERS` section with:
       ```
       BBPATH = "${TOPDIR}"
       BBFILES ?= ""

       BBLAYERS = ""
       BBLAYERS += " ${TOPDIR}/../poky/meta "
       BBLAYERS += " ${TOPDIR}/../poky/meta-poky "
       BBLAYERS += " ${TOPDIR}/../poky/meta-yocto-bsp "
       BBLAYERS += " ${TOPDIR}/../meta-renesas/meta-rz-common "
       BBLAYERS += " ${TOPDIR}/../meta-renesas/meta-rzg2l "
       BBLAYERS += " ${TOPDIR}/../meta-renesas/meta-rzv2h "
       BBLAYERS += " ${TOPDIR}/../meta-openembedded/meta-oe "
       BBLAYERS += " ${TOPDIR}/../meta-openembedded/meta-python "
       BBLAYERS += " ${TOPDIR}/../meta-openembedded/meta-multimedia "
       BBLAYERS += " ${TOPDIR}/../meta-rz-features-ros/meta-rz-graphics "
       BBLAYERS += " ${TOPDIR}/../meta-rz-features-ros/meta-rz-drpai "
       BBLAYERS += " ${TOPDIR}/../meta-rz-features-ros/meta-rz-opencva "
       BBLAYERS += " ${TOPDIR}/../meta-rz-features-ros/meta-rz-codecs "
       BBLAYERS += " ${TOPDIR}/../meta-openembedded/meta-filesystems "
       BBLAYERS += " ${TOPDIR}/../meta-openembedded/meta-networking "
       BBLAYERS += " ${TOPDIR}/../meta-virtualization "
       BBLAYERS += " ${TOPDIR}/../meta-ros-build/meta-ros-backports-gatesgarth "
       BBLAYERS += " ${TOPDIR}/../meta-ros-build/meta-ros-backports-hardknott "
       BBLAYERS += " ${TOPDIR}/../meta-ros-build/meta-ros-common "
       BBLAYERS += " ${TOPDIR}/../meta-ros-build/meta-ros2 "
       BBLAYERS += " ${TOPDIR}/../meta-ros-build/meta-ros2-galactic "
       BBLAYERS += " ${TOPDIR}/../meta-rzv2-ros-galactic "
       ```
     - Save and exit.

3. **Configure `local.conf`**:
   - Edit `~/ai_sdk_work/src_setup/yocto/build/conf/local.conf`:
     ```bash
     nano conf/local.conf
     ```
     - Add or modify the following lines at the end:
       ```
       MACHINE = "rzv2h-evk-ver1"
       LICENSE_FLAGS_WHITELIST = "commercial"
       IMAGE_INSTALL_remove = "libxkbcommon-dev orc-dev libpthread-stubs-dev lttng-modules"
       BB_NUMBER_THREADS = "4"
       PARALLEL_MAKE = "-j 4"
       ```
     - Save and exit.

4. **Fix File Ownership**:
   - Prevent `pseudo` host contamination:
     ```bash
     sudo chown -R $(whoami):$(whoami) ~/ai_sdk_work
     ```

## Step 3: Build the Image
- Source the environment and build:
  ```bash
  source ~/ai_sdk_work/src_setup/yocto/poky/oe-init-build-env ~/ai_sdk_work/src_setup/yocto/build
  MACHINE=rzv2h-evk-ver1 bitbake core-image-weston -k
  ```
- Monitor memory usage:
  ```bash
  free -h
  ```
- The build may take 4-8 hours. Output images are in `~/ai_sdk_work/src_setup/yocto/build/tmp/deploy/images/rzv2h-evk-ver1/`.

## Step 4: Prepare the SD Card
1. **Identify the SD Card**:
   ```bash
   lsblk
   ```
   - Note the device (e.g., `/dev/mmcblk0`).

2. **Unmount Partitions**:
   ```bash
   sudo umount /dev/mmcblk0p*
   ```

3. **Repartition**:
   ```bash
   sudo fdisk /dev/mmcblk0
   ```
   - Delete existing partitions with `d`.
   - Create FAT32 boot partition: `n`, `p`, `1`, default start, `+512M`, `t`, `c`.
   - Create ext4 root partition: `n`, `p`, `2`, default start, default end.
   - Write with `w`.

4. **Format Partitions**:
   ```bash
   sudo mkfs.vfat -F 32 /dev/mmcblk0p1
   sudo mkfs.ext4 /dev/mmcblk0p2
   ```

5. **Flash Root Filesystem**:
   ```bash
   sudo dd if=~/ai_sdk_work/src_setup/yocto/build/tmp/deploy/images/rzv2h-evk-ver1/core-image-weston-rzv2h-evk-ver1-*.rootfs.ext4 of=/dev/mmcblk0p2 bs=4M status=progress
   sync
   ```

6. **Copy Boot Files**:
   ```bash
   sudo mkdir /mnt/boot
   sudo mount /dev/mmcblk0p1 /mnt/boot
   sudo cp ~/ai_sdk_work/src_setup/yocto/build/tmp/deploy/images/rzv2h-evk-ver1/Image--5.10.145-cip17+*.bin /mnt/boot/Image
   sudo cp ~/ai_sdk_work/src_setup/yocto/build/tmp/deploy/images/rzv2h-evk-ver1/r9a09g057h4-evk-ver1--*.dtb /mnt/boot/r9a09g057h4-evk-ver1.dtb
   sudo umount /mnt/boot
   sudo rmdir /mnt/boot
   ```

## Step 5: Program the Bootloader
1. Connect serial cable and open terminal:
   ```bash
   sudo minicom -D /dev/ttyUSB0  # Replace with your serial port
   ```
2. Enter flash writer mode (power off, set DIP switches per R01AN7366EJ0110, power on).
3. Load flash writer via XMODEM in minicom: `Ctrl+A S xmodem`, select `Flash_Writer_SCIF_RZV2H_DEV_INTERNAL_MEMORY.mot`.
4. Program files via XMODEM (use guide addresses):
   - `bl2-rzv2h-evk-ver1.bin`
   - `fip-rzv2h-evk-ver1.bin`
   - `u-boot-rzv2h-evk-ver1-v2021.10+*.bin`

## Step 6: Configure U-Boot
1. Boot into U-Boot (interrupt countdown in minicom).
2. Set variables:
   ```bash
   setenv bootargs 'root=/dev/mmcblk0p2 rw rootwait'
   setenv bootcmd 'mmc dev 0; fatload mmc 0:1 0x48080000 Image; fatload mmc 0:1 0x48000000 r9a09g057h4-evk-ver1.dtb; booti 0x48080000 - 0x48000000'
   saveenv
   boot
   ```

## Step 7: Test the System
- Insert SD card, power on EVK, connect via minicom.
- Test:
  - Weston: `weston`
  - GStreamer: `gst-launch-1.0 videotestsrc ! videoconvert ! autovideosink`
  - OpenCV: `python3 -c "import cv2; print(cv2.__version__)"`
  - ROS2: `source /opt/ros/galactic/setup.bash; ros2 run demo_nodes_cpp talker`

## Troubleshooting
- Build: Check logs, clean affected tasks.
- Boot: Verify partitions, reprogram bootloader.
- Logs: `journalctl -xe`

## Notes
- Time: Build 4-8 hours, deployment 30 minutes.
- Optimized for 16GB RAM to avoid crashes.
```
