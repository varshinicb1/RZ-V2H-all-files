# RZ/V2H OS Build & Boot Guide

Author: Varshini CB – EdgeHax  
Last Updated: July 2025

---

## Overview

This document provides a step-by-step guide to build, configure, and boot a complete Linux-based operating system for the Renesas RZ/V2H microprocessor platform. It is intended for embedded developers and system integrators who are building graphical Linux systems with support for AI acceleration, camera input, and hardware-level customization.

This guide aims to serve as a single, self-contained reference to bring up an embedded system from initial SDK setup through to a bootable GUI desktop image on RZ/V2H hardware.

---

## Scope

- Building a Linux image using the Yocto Project
- Integration with the Renesas AI SDK v5.20
- Configuration of the kernel, device tree, and bootloader
- Creation of a GUI environment (LXQt, Chromium)
- Flashing and booting from SD card or eMMC
- DRP-AI runtime and camera integration
- Autostart of applications (Qt, Python, or browser-based)
- Packaging of a complete production-ready image

---

## Target Hardware

- SoC: Renesas RZ/V2H (R9A09G057H4x series)
- Evaluation Kit: RTK0EF0168C01000BJ or custom baseboard
- Key Features:
  - Quad-core Arm Cortex-A55 @ 1.8GHz
  - Dual Cortex-R8 and single Cortex-M33 (for real-time and low-power domains)
  - DRP-AI accelerator for vision inference
  - DDR4 memory support
  - HDMI (via USB or MIPI bridge), MIPI DSI/CSI
  - USB 3.2, Gigabit Ethernet
  - SPI, I2C, UART, CAN-FD support

---

## Requirements

- Ubuntu 22.04 LTS (host build system)
- Git, Python3, build-essential, and other Yocto dependencies
- 15 GB+ of available disk space
- At least 16 GB RAM for Yocto builds
- 16 GB or larger SD card
- Renesas RZ/V2H AI SDK v5.20 (source package)

---

## Output

A bootable `.wic` image that:
- Boots into a Linux system with LXQt desktop
- Supports Chromium browser, GStreamer pipelines, and DRP-AI applications
- Can autostart a custom Qt, Python, or browser-based dashboard
- Is suitable for production deployment and OTA upgrades

# Section 2: RZ/V2H Hardware Overview

The RZ/V2H is a high-performance application processor from Renesas designed for real-time edge AI applications, combining multiple CPU cores, hardware AI acceleration, rich multimedia support, and industrial-grade peripheral interfaces.

This section summarizes key hardware capabilities of the RZ/V2H SoC relevant to building and booting a custom Linux OS.

---

## 2.1 Processor Architecture

- **CPU Complex:**
  - 4x Arm Cortex-A55 @ up to 1.8 GHz
    - Supports 32-bit and 64-bit Armv8-A execution
    - Ideal for Linux and GUI workloads
  - 2x Arm Cortex-R8 @ 800 MHz (lockstep capable)
    - Real-time processing for deterministic tasks
  - 1x Arm Cortex-M33 @ 200 MHz
    - Suitable for low-power sensor or control tasks

- **TrustZone** support across all cores
- Optional ECC for on-chip memory

---

## 2.2 AI Acceleration

- **DRP-AI (Dynamically Reconfigurable Processor + AI Accelerator)**
  - Low-latency, low-power AI inference engine
  - Optimized for image classification, object detection, pose estimation
  - Integrated into the AI SDK v5.20
  - Supports pre-compiled DRP-AI models via TVM and ONNX

---

## 2.3 Memory Support

- **DDR Interfaces:**
  - Supports DDR4-2400 / LPDDR4 (x32)
  - Up to 4 GB typical on EVK
  - ECC support configurable via boot settings

- **Internal SRAM:**
  - A55 domain: 512 KB
  - R8 domain: 512 KB
  - M33 domain: 128 KB

---

## 2.4 Multimedia and Display

- **Video Input:**
  - MIPI CSI-2 interface (camera)
  - USB camera (via USB 3.2)

- **Video Output:**
  - MIPI DSI output
  - HDMI supported via external bridge or USB-C

- **Graphics:**
  - OpenGL ES 2.0/3.1 capable GPU
  - VPU supports H.264/H.265 encode/decode (via GStreamer OMX plugins)

---

## 2.5 Connectivity

- **Networking:**
  - Gigabit Ethernet MAC
  - External PHY required

- **USB:**
  - USB 3.2 Gen1 (Host/Device x2)
  - USB 2.0 OTG

- **Serial and Industrial Interfaces:**
  - UART x4
  - I2C x6
  - SPI x3
  - CAN-FD x2
  - GPIO banks

- **Storage Interfaces:**
  - SD/MMC
  - QSPI Flash (bootable)
  - eMMC boot via SDHI

---

## 2.6 Boot Modes

- **Supported Boot Devices:**
  - SD card
  - eMMC
  - QSPI NOR Flash
  - USB (firmware loader mode)

- **Boot Stages:**
  1. Boot ROM
  2. Boot Loader (FSBL from Flash or SD)
  3. U-Boot or Trusted Firmware-A
  4. Linux Kernel + Device Tree
  5. Root File System

- **Default EVK Boot Method:**
  - SD card with `bootparams`, `uImage`, and `.dtb` on 1st partition (FAT32)

---

## 2.7 Security and Isolation

- TrustZone-enabled secure execution environment
- Secure Boot and cryptographic acceleration
- Optional ARMv8-A EL3 monitor support

---

## 2.8 Development & Debugging

- On-board JTAG (via 20-pin header)
- UART0 for serial console
- USB serial console and firmware download (optional)
- ST-Link or J-Link support with OpenOCD

---

## 2.9 Supported OS and SDK

- **Yocto-based Linux (provided by Renesas)**
  - AI SDK v5.20 (includes DRP-AI runtime, GStreamer plugins)
- **RTOS (optional)** for R8 and M33 domains
- **Bare-metal or FreeRTOS** on M33

---
# Section 3: OS Choices and Yocto Architecture

The RZ/V2H supports multiple OS configurations across its multi-core architecture. This section outlines common OS choices, the rationale behind using Yocto for the A55 domain, and how its layered build system enables customization for production use.

---

## 3.1 OS Options for RZ/V2H

The RZ/V2H is designed to support multiple simultaneous OSes running on separate cores:

| Domain | Core(s)         | Supported OS Options                   |
|--------|------------------|----------------------------------------|
| A-CPU  | 4x Cortex-A55    | Linux (Yocto-based), Ubuntu RootFS, Android (experimental) |
| R-CPU  | 2x Cortex-R8     | Bare-metal, RTOS (e.g. eMCOS, FreeRTOS), AutoSAR |
| M-CPU  | 1x Cortex-M33    | FreeRTOS, Bare-metal, Trusted Execution |

In most applications, the A55 runs Linux with GUI and AI services, while the R8 and M33 run real-time control loops or secure enclave firmware.

---

## 3.2 Why Yocto?

The official Renesas SDK is built on the **Yocto Project**, which provides:

- Full control over root filesystem contents
- Fine-grained package selection
- Build-time customization of kernel, bootloader, and device tree
- Reproducible and portable builds
- SDK generation for cross-development

Yocto is ideal for production environments where the full Linux stack needs to be version-controlled, optimized, and secure.

---

## 3.3 Yocto Build Components

| Component     | Role                                         |
|---------------|----------------------------------------------|
| Poky          | Core Yocto build system and metadata         |
| BitBake       | Task executor and dependency engine          |
| meta-qt5      | Adds Qt5 modules (GUI framework)             |
| meta-lxqt     | Lightweight LXQt desktop environment         |
| meta-rzv      | Renesas SoC support layer (board config)     |
| meta-drpai    | DRP-AI support: runtime, kernel modules      |
| meta-browser  | Chromium support (via Ozone/Wayland)         |
| meta-openembedded | Additional multimedia/networking utilities |

All of these are referenced in `bblayers.conf` and brought together by a custom image recipe (`rzv2h-pro-desktop.bb`).

---

## 3.4 Build Output Structure

After a successful build, the Yocto output directory contains:

tmp/deploy/images/rzv2h/
├── Image # Linux kernel
├── *.dtb # Device tree blob(s)
├── rootfs.tar.bz2 # Root filesystem archive
├── .wic # Flashable disk image (SD/eMMC)
├── modules-.tgz # Kernel modules
├── boot.scr # U-Boot boot script

yaml
Copy
Edit

The `.wic` file is the complete image used for booting the board via SD card or flashing to eMMC.

---

## 3.5 Layering Concept in Yocto

Yocto is modular. Each meta-layer contains:
- Configuration files (machine definitions, distro settings)
- Recipes for software packages
- Patches and build overrides

The Renesas SDK structure (based on AI SDK v5.20) looks like:

![image](https://github.com/user-attachments/assets/28a60252-ddd6-4bbb-b0a8-1ed051b64d30)


yaml


Layers are ordered in `bblayers.conf` to build the final image.

---


## Section 4: Toolchain, SDK, and Build Preparation

````markdown
#Before starting the build process, it is important to install all required packages on the host system and prepare the SDK environment. This section covers the necessary tools, SDK source structure, and setup script used to prepare the Yocto workspace.

---

## 4.1 Host PC Requirements

**Recommended OS:** Ubuntu 22.04 LTS (64-bit)

### Required Packages

Install dependencies using:

```bash
sudo apt update && sudo apt install -y \
    gawk wget git-core diffstat unzip texinfo gcc-multilib \
    build-essential chrpath socat cpio python3 python3-pip \
    python3-pexpect xz-utils debianutils iputils-ping \
    libsdl1.2-dev xterm curl zstd
````

---

## 4.2 Downloading the Renesas AI SDK (v5.20)

Download the official SDK ZIP:

* [Renesas RZ/V2H AI SDK v5.20](https://www.renesas.com/en/document/sws/rzv2h-ai-sdk-v520-source-code)

You should receive a file named:

```
RTK0EF0180F04001LINUXAISP_src.zip
```

Extract the ZIP archive into the `sources/` folder inside your Yocto workspace:

```bash
mkdir -p sources/meta-rzv-ai-sdk
cd sources/meta-rzv-ai-sdk
unzip ~/Downloads/RTK0EF0180F04001LINUXAISP_src.zip
```

You should now see:

```
meta-rzv/
meta-drpai/
scripts/
recipes/
```

These layers will be added to your build configuration.

---

## 4.3 Running the Setup Script

The project includes a script `setup.sh` that clones all required meta-layers and sets up the workspace.

### Example usage:

```bash
cd rzv2h-pro-desktop-yocto
chmod +x setup.sh
./setup.sh
```

The script will:

* Clone `poky`, `meta-openembedded`, `meta-qt5`, `meta-browser`, `meta-lxqt`
* Print instructions for verifying the SDK structure

---

## 4.4 Directory Structure After Setup

After completing `setup.sh`, the expected structure is:

```
rzv2h-pro-desktop-yocto/
├── build/
│   └── conf/
├── boot/
├── extras/
├── recipes-core/
│   └── images/
├── sources/
│   ├── poky/
│   ├── meta-openembedded/
│   ├── meta-qt5/
│   ├── meta-browser/
│   ├── meta-lxqt/
│   └── meta-rzv-ai-sdk/
│       ├── meta-rzv/
│       └── meta-drpai/
├── setup.sh
└── README.md
```

---

## 4.5 Initializing the Build Environment

Once all layers are present, initialize the build environment using:

```bash
source sources/poky/oe-init-build-env build
```

This creates and switches to the `build/` directory.

Next, configure the following:

* `conf/bblayers.conf` → list all meta-layers
* `conf/local.conf` → select packages, features, and image type

These files are included as editable templates in the repository.

---


## Section 5: Image Configuration and Directory Structure

````markdown
# Section 5: Image Configuration and Directory Structure

Once the Yocto environment is initialized and meta-layers are in place, the next step is to define how the final image will be built, what it includes, and how it is structured. This is done through two key configuration files and a custom image recipe.

---

Key Configuration Files

 1. `build/conf/bblayers.conf`

This file defines which layers are included in the build process. It should be populated with the full paths to all meta-layers, such as:

```conf
BBLAYERS ?= " \
  ${TOPDIR}/../sources/poky/meta \
  ${TOPDIR}/../sources/poky/meta-poky \
  ${TOPDIR}/../sources/meta-openembedded/meta-oe \
  ${TOPDIR}/../sources/meta-openembedded/meta-networking \
  ${TOPDIR}/../sources/meta-openembedded/meta-python \
  ${TOPDIR}/../sources/meta-openembedded/meta-multimedia \
  ${TOPDIR}/../sources/meta-qt5 \
  ${TOPDIR}/../sources/meta-browser \
  ${TOPDIR}/../sources/meta-lxqt \
  ${TOPDIR}/../sources/meta-rzv-ai-sdk/meta-rzv \
  ${TOPDIR}/../sources/meta-rzv-ai-sdk/meta-drpai \
"
````

2. `build/conf/local.conf`

This file sets machine type, image features, and packages. Example:

```conf
MACHINE = "rzv2h"

DISTRO_FEATURES:append = " x11 wayland opengl systemd bluetooth wifi v4l2"

IMAGE_FEATURES += "ssh-server-openssh tools-debug package-management"

PACKAGE_CLASSES = "package_ipk"

INIT_MANAGER = "systemd"

EXTRA_IMAGE_FEATURES += "read-only-rootfs overlayfs"

IMAGE_INSTALL:append = " \
  lightdm lxqt lxqt-config lxqt-panel lxqt-session \
  pcmanfm-qt lxterminal qtbase qtquickcontrols2 qtdeclarative \
  chromium-ozone-wayland gstreamer1.0-plugins-base \
  gstreamer1.0-plugins-good gstreamer1.0-plugins-bad \
  networkmanager nm-applet openssh sudo matchbox-keyboard \
  python3 python3-pyqt5 python3-opencv \
"
```

---

## 5.2 Image Recipe: `rzv2h-pro-desktop.bb`

This recipe defines what gets included in the final root filesystem. Located at:

```
recipes-core/images/rzv2h-pro-desktop.bb
```

### Example content:

```bitbake
SUMMARY = "Full-featured LXQt Desktop Image for RZ/V2H"
LICENSE = "MIT"

inherit core-image

IMAGE_INSTALL += " \
  ${CORE_IMAGE_EXTRA_INSTALL} \
  lightdm lxqt lxqt-config lxqt-panel lxqt-session \
  pcmanfm-qt lxterminal chromium \
  qtbase qtquickcontrols2 qtdeclarative \
  gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-bad \
  networkmanager nm-applet openssh sudo \
  python3 python3-pyqt5 python3-opencv \
  drpai-driver drpai-runtime \
"
```

This results in a desktop image with:

* GUI (LXQt)
* Browser (Chromium)
* Terminal and File Manager
* DRP-AI Runtime
* Python3 + Qt5
* GStreamer multimedia stack

---

## 5.3 Output Directory Layout (after bitbake)

After building, you’ll find images in:

```
tmp/deploy/images/rzv2h/
├── Image                # Kernel
├── *.dtb                # Device Tree
├── rootfs.tar.bz2       # Root filesystem archive
├── *.wic                # Flashable SD/eMMC image
├── modules-*.tgz        # Kernel modules
├── boot.scr             # U-Boot script (optional)
```

You will typically flash the `.wic` file to an SD card using `dd`.

---

## 5.4 SD Card Partition Layout

A `.wic` file is an image with two partitions:

* **boot (FAT32):** Contains `Image`, `.dtb`, and `boot.scr`
* **rootfs (ext4):** Contains the entire Linux filesystem with GUI, apps, etc.

You can inspect it using:

```bash
fdisk -l rzv2h-pro-desktop.wic
```

---

```

Let me know when you're ready for **Section 6: Building, Flashing, and Booting** by saying `next`.
```



