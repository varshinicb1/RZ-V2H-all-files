# 🧠 RZ/V2H OS Build & Boot Guide

_Author: Varshini CB – EdgeHax  
Last Updated: July 2025_

---

## 📘 Overview

This guide provides a step-by-step walkthrough to build, configure, and flash a complete Linux OS image for the **Renesas RZ/V2H** microprocessor platform. It is written for developers, integrators, and product teams who want to bring up a GUI-powered embedded Linux system with optional AI support.

Whether you're building an AI-enabled camera system, a kiosk display, or a custom Linux product, this guide aims to be the **single reference** needed from bare-metal boot to full GUI desktop.

---

## 🎯 What This Covers

- Full OS build using **Yocto Project**
- Using **Renesas AI SDK v5.20**
- GUI with **LXQt**, Chromium, and apps
- Flashing via SD card or eMMC
- Bootloader, DDR init, and device tree handling
- Kernel and rootfs configuration
- Debugging and UART console output
- DRP-AI integration (camera + object detection)
- Autostarting Qt/Python/Chromium apps
- 📦 Packaging a production-ready image

---

## 🛠️ Target Hardware

- **SoC**: Renesas RZ/V2H (R9A09G057H4x series)
- **Evaluation Kit**: RTK0EF0168C01000BJ (Renesas EVK)
- **Board Features**:
  - Quad Cortex-A55 (1.8GHz)
  - Dual Cortex-R8 + Cortex-M33
  - DRP-AI Accelerator
  - DDR4 support
  - USB 3.2, GbE, MIPI DSI/CSI
  - HDMI via bridge or USB
  - SPI/I2C/CAN/UART

---

## ⚠️ Assumptions

You should have:
- A Linux host system (Ubuntu 22.04 LTS recommended)
- Familiarity with terminal, SSH, SD card flashing
- RZ/V2H EVK board or equivalent custom board
- 15GB+ disk space & 16GB RAM (for Yocto builds)

---

## 📦 Final Output

A `.wic` image ready to flash to SD card or eMMC, booting into:
- LXQt desktop
- Chromium in kiosk mode (optional)
- Pre-installed Python3, Qt5, OpenCV
- DRP-AI-ready GStreamer pipeline
- Configurable auto-launch dashboard

---

