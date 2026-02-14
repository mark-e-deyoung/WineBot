# Build Performance & Resource Utilization Report

**Date:** 2026-02-14  
**Status:** Baseline after v0.9.3 optimizations  
**Reference Issues:** [#4](https://github.com/mark-e-deyoung/WineBot/issues/4), [#5](https://github.com/mark-e-deyoung/WineBot/issues/5)

## Overview
This report characterizes the build time overhead and resource utilization of the WineBot container system. It identifies major bottlenecks and provides a baseline for ongoing optimization efforts.

---

## 1. Build Time Overhead
*Total clean build time: ~16 minutes (Standard GitHub Runner environment).*

| Stage / Subsystem | Time | Characteristics | Primary Bottleneck |
| :--- | :--- | :--- | :--- |
| **System Dependencies (APT)** | ~10 mins | Very High | Network bandwidth and Disk I/O (Unpacking Wine i386/amd64). |
| **Windows Tools (Download)** | ~1 min | Low | External network latency. |
| **Wine Prefix Warm-up** | ~2 mins | Medium | CPU-intensive (First-run registry initialization). |
| **Linux Python Deps** | ~1 min | Low | Standard `pip install` overhead. |
| **Image Export/Layering** | ~2 mins | Medium | Disk I/O (Compressing and writing ~4.3GB). |

### Key Improvements (v0.9.3)
- **Prefix Warm-up Logic:** Moved the ~90s `wineboot` process from runtime to build-time.
- **Layer Reordering:** Positioned application code `COPY` commands after the heavy prefix-template generation, ensuring code changes don't invalidate 90% of the build cache.

---

## 2. Resource Utilization
*Total Image Footprint: ~4.3 GB (Production REL intent).*

| Subsystem / Feature | Size | Category | Impact / Value |
| :--- | :--- | :--- | :--- |
| **Wine & X11 System Core** | **2.2 GB** | Infrastructure | Essential. Large due to dual-architecture (i386 + amd64) requirements. |
| **Wine Prefix Template** | **1.4 GB** | Optimization | High storage cost, but provides instant startup and CI stability. |
| **FastAPI / OpenCV Stack** | **150 MB** | Application | Core API and Visual (CV) automation dependencies. |
| **Windows Python (`winpy`)** | **44 MB** | Diagnostic | Essential for high-fidelity `win_hook` tracing. |
| **AutoIt / AutoHotkey** | **24 MB** | Automation | Lightweight native automation fallbacks. |

---

## 3. Storage Analysis (Internal)
Detailed breakdown of major filesystem paths:
- `/usr/lib/x86_64-linux-gnu`: **1.4 GB** (System libraries)
- `/usr/lib/i386-linux-gnu`: **773 MB** (32-bit Wine support)
- `/opt/winebot/prefix-template`: **1.4 GB** (Pre-initialized `C:` drive)
- `/opt/winebot/windows-tools/Python`: **44 MB** (Embedded interpreter)

---

## 4. Optimization Strategy

### A. Implemented
- **[DONE] Remove Windows Pip Bootstrap:** Saved ~3 mins of build time and avoided ~1.4GB of redundant prefix bloat in the `/root` directory.
- **[DONE] Multi-Stage Layering:** Separated stable system layers from dynamic tool and application layers to maximize cache hits.
- **[DONE] CI Disk Management:** Added `Maximize disk space` steps to GitHub Actions to prevent "No space left on device" failures.

### B. Future (Strategic Issues)
- **[Issue #4] Modular 'Slim' Intent:** Create an image variant that excludes the 1.4GB prefix template for users who prioritize disk space over startup speed.
- **[Issue #5] Custom Minimal Wine Build:** Research a stripped-down Wine build targeting only core automation DLLs (`user32`, `gdi32`, `kernel32`) to reduce the 2.2GB infrastructure baseline.

---

## 5. Conclusion
WineBot v0.9.3 represents a significant leap in build performance and runtime reliability. While the image remains large (~4.3GB), the storage is now utilized effectively to provide nearly instantaneous startup. Further gains require moving away from standard distribution packages towards custom-compiled Wine binaries.
