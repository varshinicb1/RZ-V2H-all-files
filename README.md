Building and Deploying ROS2 Galactic with core-image-weston on RZ/V2H EVK
This guide provides a complete, step-by-step process to build and deploy the core-image-weston Yocto image with ROS2 Galactic on the Renesas RZ/V2H evaluation kit (EVK) using Ubuntu 20.04 LTS. It incorporates lessons learned from a successful build, addressing issues like file conflicts and host contamination, to ensure a smooth, one-go process. The guide aligns with the Renesas ROS2 Installation Guide (R01AN7366EJ0110) and is optimized for a system with 16GB RAM.
Prerequisites

Host System: Ubuntu 20.04 LTS with at least 800GB free disk space (preferably on an SSD) and 16GB RAM (32GB recommended).
RZ/V2H EVK: Renesas RZ/V2H evaluation kit (R9A09G057 SoC).
SD Card: 32GB or larger microSD card for the image.
Serial Cable: For bootloader programming and debugging (e.g., USB-to-serial adapter).
Dependencies: Install required packages for Yocto builds.sudo apt update
sudo apt install -y gawk wget git-core diffstat unzip texinfo gcc-multilib \
build-essential chrpath socat cpio python3 python3-pip python3-pexpect \
xz-utils debianutils iputils-ping python3-git python3-jinja2 libegl1-mesa \
libsdl1.2-dev pylint3 xterm python3-subunit mesa-common-dev zstd liblz4-tool


Disk Space: Verify sufficient free space (~800-900GB recommended).df -h /
df -h /home


Internet: Stable connection for downloading sources and repositories.

Step 1: Set Up the Build Environment

Create a Working Directory:
mkdir -p ~/ai_sdk_work/src_setup/yocto
cd ~/ai_sdk_work/src_setup/yocto


Clone Required Repositories:

Clone the Yocto Poky repository (Dunfell branch, compatible with ROS2 Galactic):git clone -b dunfell git://git.yoctoproject.org/poky


Clone Renesas RZ/V2H layers:git clone -b dunfell git://github.com/renesas-rz/meta-renesas


Clone meta-openembedded for additional packages:git clone -b dunfell git://git.openembedded.org/meta-openembedded


Clone meta-ros and ROS2 Galactic layers:git clone -b dunfell https://github.com/ros/meta-ros.git


Clone meta-rzv2-ros-galactic for RZ/V2H ROS2 support:git clone https://github.com/renesas-rz/meta-rzv2-ros-galactic




Apply ROS2 Galactic Patch:

If the meta-ros-galactic.patch is provided in the RZ/V2H AI SDK or guide (R01AN7366EJ0110), apply it:cd meta-ros
git apply ~/path/to/meta-ros-galactic.patch
cd ..


If no patch is available, skip this step, as the repositories are typically pre-configured.



Step 2: Configure Yocto Build

Initialize the Build Environment:
cd poky
source oe-init-build-env ../build


This creates the build directory and sets up the Yocto environment.


Configure bblayers.conf:

Edit ~/ai_sdk_work/src_setup/yocto/build/conf/bblayers.conf to include required layers:nano conf/bblayers.conf


Ensure it contains (adjust paths if necessary):BBLAYERS ?= " \
  /home/${USER}/ai_sdk_work/src_setup/yocto/poky/meta \
  /home/${USER}/ai_sdk_work/src_setup/yocto/poky/meta-poky \
  /home/${USER}/ai_sdk_work/src_setup/yocto/poky/meta-yocto-bsp \
  /home/${USER}/ai_sdk_work/src_setup/yocto/meta-renesas/meta-rz-common \
  /home/${USER}/ai_sdk_work/src_setup/yocto/meta-renesas/meta-rzg2l \
  /home/${USER}/ai_sdk_work/src_setup/yocto/meta-renesas/meta-rzv2h \
  /home/${USER}/ai_sdk_work/src_setup/yocto/meta-openembedded/meta-oe \
  /home/${USER}/ai_sdk_work/src_setup/yocto/meta-openembedded/meta-python \
  /home/${USER}/ai_sdk_work/src_setup/yocto/meta-openembedded/meta-multimedia \
  /home/${USER}/ai_sdk_work/src_setup/yocto/meta-openembedded/meta-filesystems \
  /home/${USER}/ai_sdk_work/src_setup/yocto/meta-openembedded/meta-networking \
  /home/${USER}/ai_sdk_work/src_setup/yocto/meta-openembedded/meta-virtualization \
  /home/${USER}/ai_sdk_work/src_setup/yocto/meta-ros/meta-ros-backports-gatesgarth \
  /home/${USER}/ai_sdk_work/src_setup/yocto/meta-ros/meta-ros-backports-hardknott \
  /home/${USER}/ai_sdk_work/src_setup/yocto/meta-ros/meta-ros-common \
  /home/${USER}/ai_sdk_work/src_setup/yocto/meta-ros/meta-ros2 \
  /home/${USER}/ai_sdk_work/src_setup/yocto/meta-ros/meta-ros2-galactic \
  /home/${USER}/ai_sdk_work/src_setup/yocto/meta-rzv2-ros-galactic \
"


Save and exit (Ctrl+O, Enter, Ctrl+X).




Configure local.conf:

Edit ~/ai_sdk_work/src_setup/yocto/build/conf/local.conf:nano conf/local.conf


Add or modify the following lines to configure the machine, enable commercial licenses, remove conflicting packages, and optimize for 16GB RAM:MACHINE = "rzv2h-evk-ver1"
DISTRO = "poky"
LICENSE_FLAGS_WHITELIST = "commercial"
IMAGE_INSTALL_remove = "libxkbcommon-dev orc-dev libpthread-stubs-dev lttng-modules"
BB_NUMBER_THREADS = "4"
PARALLEL_MAKE = "-j 4"


Explanation:
MACHINE: Targets the RZ/V2H EVK.
LICENSE_FLAGS_WHITELIST: Allows commercial packages (e.g., GStreamer plugins).
IMAGE_INSTALL_remove: Prevents file conflicts in /usr/lib/pkgconfig and removes lttng-modules to avoid CONFIG_TRACEPOINTS issues.
BB_NUMBER_THREADS and PARALLEL_MAKE: Reduces parallelism to avoid memory issues on 16GB RAM systems.


Save and exit.




Fix File Ownership:

Ensure all files are owned by your user to prevent pseudo host contamination:sudo chown -R $(whoami):$(whoami) ~/ai_sdk_work





Step 3: Build the Image

Build the core-image-weston image:MACHINE=rzv2h-evk-ver1 bitbake core-image-weston -k


The -k flag continues past non-critical errors.
Monitor memory usage to avoid crashes:free -h


The build may take several hours, depending on your system. The resulting image will be in ~/ai_sdk_work/src_setup/yocto/build/tmp/deploy/images/rzv2h-evk-ver1/.

Step 4: Prepare the SD Card

Identify the SD Card:

Insert a 32GB (or larger) microSD card and identify its device name:lsblk


Look for a device like /dev/mmcblk0 or /dev/sdX (e.g., 29.7GB for a 32GB card).




Unmount Existing Partitions:

Unmount any mounted partitions (replace mmcblk0p1 with the actual partition):sudo umount /dev/mmcblk0p1




Repartition the SD Card:

Use fdisk to create a FAT32 boot partition and an ext4 root filesystem partition:sudo fdisk /dev/mmcblk0


In fdisk:
Delete existing partitions:Command (m for help): d


Repeat for all partitions (e.g., mmcblk0p1).


Create a 512MB FAT32 boot partition:Command (m for help): n
Partition type: p (primary)
Partition number (1-4, default 1): 1
First sector: (default)
Last sector: +512M
Command (m for help): t
Selected partition 1
Hex code: c (W95 FAT32 LBA)


Create an ext4 root filesystem partition:Command (m for help): n
Partition type: p (primary)
Partition number (2-4, default 2): 2
First sector: (default)
Last sector: (default, use all remaining space)


Write changes:Command (m for help): w






Verify the layout:lsblk /dev/mmcblk0


Expected: mmcblk0p1 (512MB), mmcblk0p2 (~29.2GB).




Format the Partitions:

Format the boot partition as FAT32:sudo mkfs.vfat -F 32 /dev/mmcblk0p1


Format the root filesystem as ext4:sudo mkfs.ext4 /dev/mmcblk0p2




Flash the Root Filesystem:

Flash the core-image-weston image to mmcblk0p2:sudo dd if=~/ai_sdk_work/src_setup/yocto/build/tmp/deploy/images/rzv2h-evk-ver1/core-image-weston-rzv2h-evk-ver1-*.rootfs.ext4 of=/dev/mmcblk0p2 bs=4M status=progress
sync




Copy Boot Files:

Mount the boot partition and copy the kernel and device tree:sudo mkdir /mnt/boot
sudo mount /dev/mmcblk0p1 /mnt/boot
sudo cp ~/ai_sdk_work/src_setup/yocto/build/tmp/deploy/images/rzv2h-evk-ver1/Image--5.10.145-cip17+*.bin /mnt/boot/Image
sudo cp ~/ai_sdk_work/src_setup/yocto/build/tmp/deploy/images/rzv2h-evk-ver1/r9a09g057h4-evk-ver1--*.dtb /mnt/boot/r9a09g057h4-evk-ver1.dtb
sudo umount /mnt/boot
sudo rmdir /mnt/boot





Step 5: Program the Bootloader

Program the bootloader to the RZ/V2H’s internal memory or SPI flash (per R01AN7366EJ0110, Section 3.2).


Connect the Board:

Connect the RZ/V2H EVK to your host PC via a serial cable.
Identify the serial port:dmesg | grep tty


Look for /dev/ttyUSB0 or /dev/ttyACM0.


Open a serial terminal:sudo minicom -D /dev/ttyUSB0




Enter Flash Writer Mode:

Power off the board.
Set DIP switches for flash writer mode (check R01AN7366EJ0110, Section 3.2, for settings, e.g., SW1/SW2).
Power on the board.


Program Bootloader Files:

In minicom, load the flash writer:
Press Ctrl+A, S, select xmodem, choose:~/ai_sdk_work/src_setup/yocto/build/tmp/deploy/images/rzv2h-evk-ver1/Flash_Writer_SCIF_RZV2H_DEV_INTERNAL_MEMORY.mot




Program the bootloader files (use addresses from the guide):
bl2-rzv2h-evk-ver1.bin (or bl2_bp_esd-rzv2h-evk-ver1.bin for ESD memory).
fip-rzv2h-evk-ver1.bin.
u-boot-rzv2h-evk-ver1-v2021.10+*.bin.
For each file, use XMODEM (Ctrl+A, S, xmodem, select file).


Follow the guide’s commands (e.g., write, erase) and memory addresses.



Step 6: Configure U-Boot

Configure U-Boot to boot from the SD card:


Boot the board into U-Boot (via minicom).
Interrupt the boot process (press any key during the countdown).
Set environment variables:setenv bootargs 'root=/dev/mmcblk0p2 rw rootwait'
setenv bootcmd 'mmc dev 0; fatload mmc 0:1 0x48080000 Image; fatload mmc 0:1 0x48000000 r9a09g057h4-evk-ver1.dtb; booti 0x48080000 - 0x48000000'
saveenv
boot



Step 7: Test the System

Insert the SD card into the RZ/V2H EVK and power it on.
Connect via serial console:sudo minicom -D /dev/ttyUSB0


Log in (default: root, no password, unless customized in local.conf).
Test components:
Weston:weston --version
weston


Connect a display to verify the desktop.


GStreamer:gst-launch-1.0 --version
gst-launch-1.0 videotestsrc ! videoconvert ! autovideosink


Expect a test video pattern on a display.


OpenCV:python3 -c "import cv2; print(cv2.__version__)"


Should output 4.1.0.


ROS2 Galactic:source /opt/ros/galactic/setup.bash
ros2 --version
ros2 run demo_nodes_cpp talker


In another terminal (via SSH or serial), run:ros2 run demo_nodes_cpp listener




Kernel Modules:lsmod


Verify modules like udmabuf, uvcs-drv, uvcvideo, vspm.





Troubleshooting

Build Failure:
Check the build log (e.g., tmp/work/rzv2h_evk_ver1-poky-linux/core-image-weston/1.0-r0/temp/log.do_rootfs.*).
Ensure IMAGE_INSTALL_remove in local.conf includes libxkbcommon-dev orc-dev libpthread-stubs-dev lttng-modules.
If memory issues occur, reduce parallelism further:echo 'BB_NUMBER_THREADS = "2"' >> conf/local.conf
echo 'PARALLEL_MAKE = "-j 2"' >> conf/local.conf


Clean and retry:bitbake core-image-weston -c clean
MACHINE=rzv2h-evk-ver1 bitbake core-image-weston -k




Boot Failure:
Check U-Boot logs in minicom for errors (e.g., “no kernel found”).
Verify partition layout:sudo fdisk -l /dev/mmcblk0


Reprogram bootloader files (Step 5) with correct addresses.


Missing Packages:
Check the manifest:cat ~/ai_sdk_work/src_setup/yocto/build/tmp/deploy/images/rzv2h-evk-ver1/core-image-weston-rzv2h-evk-ver1-*.rootfs.manifest


Add missing packages to IMAGE_INSTALL_append in local.conf and rebuild.


System Logs:
Check:cat /var/log/syslog
journalctl -xe





Notes

Time Estimate: Build (4-8 hours on 16GB RAM), SD card preparation (15 minutes), bootloader programming (~15 minutes).
Image Size: ~1.2GB (ext4), fits on a 32GB SD card.
Memory Management: Monitor memory during the build:free -h


Configuration: The local.conf settings prevent known file conflicts and CONFIG_TRACEPOINTS issues, ensuring a stable build.
