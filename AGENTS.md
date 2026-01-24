# AGENTS.md — WineBot (Codex Agent Guide)

WineBot is a containerized harness for running **Windows GUI applications under Wine** in two modes:

- **Automation / headless**: not visible; used for unattended runs and CI
- **Interactive / visible**: view and interact with the same virtual desktop used for automation (for setup and debugging)

WineBot also supports **UI automation** through a layered strategy:
1) *Control-level automation* (AutoIt/AHK/pywinauto) when available
2) *X11-level driving* (`xdotool`, `wmctrl`)
3) *Computer-vision fallback* (OpenCV template matching/OCR)

This document tells Codex exactly what to build, how to structure it, and what “done” looks like.

---

## 1) Outcomes (what to build)

### Required deliverables
Create a GitHub-ready repository that includes:

1. **Docker image** capable of running a Windows GUI app under Wine.
2. **Headless mode** using `Xvfb` on display `:99`.
3. **Interactive mode** that makes the same Xvfb session viewable via:
   - VNC (`x11vnc`) **and**
   - Browser viewing (noVNC) (optional but strongly preferred)
4. A **stable desktop environment** for consistent automation:
   - lightweight window manager (`openbox`)
   - fixed screen resolution and color depth (default `1920x1080x24`)
5. A **persistent Wine prefix** volume at `/wineprefix`.
6. A composable **entrypoint** that:
   - initializes the prefix (`wineboot --init`) if missing
   - starts Xvfb/openbox
   - optionally starts VNC/noVNC
   - launches a target Windows executable
   - optionally launches an automation runner
7. A small **automation SDK** inside the repo:
   - `automation/screenshot.sh` (grab a screenshot of the virtual display)
   - `automation/click_xy.sh` (click coordinates)
   - `automation/find_and_click.py` (OpenCV template match + click via xdotool)
8. **docker-compose.yml** with profiles:
   - `headless` (no ports exposed)
   - `interactive` (ports exposed for VNC/noVNC)
9. **Docs**:
   - `README.md` with quickstart and troubleshooting
   - `docs/` folder for deeper usage and troubleshooting notes

### Non-goals (do not implement unless easy)
- GPU acceleration (not required)
- RDP/SPICE
- Full Windows VM (this is Wine-only)
- Complex “record and replay” frameworks

---

## 2) Design principles

### Consistency first
Automation is brittle when UI geometry changes. Always enforce:
- fixed X display resolution
- consistent DPI and theme (keep defaults unless required)
- deterministic window placement whenever possible

### Separation of concerns
- Container bootstraps the environment (Xvfb + openbox + Wine prefix)
- App launch is parameterized (env vars/args)
- Automation is optional and lives under `automation/`

### Debuggability
- Interactive viewing should be a switch (compose profile or env var)
- Provide a “take screenshot now” script for rapid debugging
- Optionally allow recording the display using ffmpeg (extra credit)

---

## 3) Repository layout (target)

```
winebot/
  AGENTS.md
  README.md
  LICENSE
  docker/
    Dockerfile
    entrypoint.sh
  compose/
    docker-compose.yml
  scripts/
    run-headless.sh
    run-interactive.sh
  automation/
    screenshot.sh
    click_xy.sh
    find_and_click.py
    assets/
      example_button.png
  docs/
    architecture.md
    troubleshooting.md
    automation.md
  skills/
    container-build.md
    wine-prefix.md
    display-stack.md
    automation-cv.md
    security.md
    testing.md
```

---

## 4) Runtime modes (required behavior)

### Headless (default)
- Starts `Xvfb :99 -screen 0 ${SCREEN}`
- Exports `DISPLAY=:99`
- Starts `openbox` as the window manager
- Starts Wine app if `APP_EXE` is set
- Does **not** expose ports

### Interactive
Same as headless, plus:
- Start `x11vnc` bound to the Xvfb display
- Start `noVNC` (websockify) exposing a web port

Default ports (can be overridden):
- VNC: `5900`
- noVNC web: `6080`

---

## 5) Configuration contract (environment variables)

Implement these environment variables:

### Core
- `WINEPREFIX` (default `/wineprefix`)
- `DISPLAY` (default `:99`)
- `SCREEN` (default `1920x1080x24`)
- `MODE` (`headless` or `interactive`; default `headless`)

### App launching
- `APP_EXE` (path to `.exe` inside container; if set, run it)
- `APP_ARGS` (optional args string)
- `WORKDIR` (optional working directory for app)

### Prefix bootstrapping
- `INIT_PREFIX` (`1` default): if set, run `wineboot --init` on startup
- `WINEARCH` (optional, e.g. `win32` for 32-bit-only apps)

### Interactive viewing
- `ENABLE_VNC` (`0/1`, default `0` unless `MODE=interactive`)
- `VNC_PORT` (default `5900`)
- `NOVNC_PORT` (default `6080`)
- `VNC_PASSWORD` (optional; if empty, run without password only if bound to localhost)

### Automation runner (optional)
- `RUN_AUTOMATION` (`0/1`)
- `AUTOMATION_CMD` (command to run after app launch, e.g. `python3 automation/find_and_click.py ...`)

---

## 6) Docker image requirements

### Base image
Use Debian/Ubuntu slim where Wine packages are readily available.

### Packages to install (minimum baseline)
Must include:
- `wine`, `wine64`, `wine32` (enable i386 multiarch)
- `xvfb`, `xauth`
- `openbox`
- `xdotool`, `wmctrl`
- `x11vnc`
- `novnc` or `websockify` + static noVNC files
- `python3`, `python3-pip`
- `python3-opencv` (or pip `opencv-python`)
- `imagemagick` (optional) or `x11-apps` utilities for debugging
- `winetricks`, `cabextract` (for installing VC++ runtimes/.NET if needed)
- `ca-certificates`, `curl`

### Create a non-root user
- Add a user like `winebot` (uid 1000)
- Ensure `/wineprefix` is writable by it

---

## 7) docker-compose requirements

Under `compose/docker-compose.yml`, implement:
- service `winebot`
- two profiles:
  - `headless`: no published ports
  - `interactive`: publish VNC and noVNC ports

Include volume mounts:
- `wineprefix:/wineprefix` (named volume)
- optional bind-mount `./apps:/apps` for user-provided executables
- optional bind-mount `./automation/assets:/automation/assets`

---

## 8) Minimal automation SDK (required)

### `automation/screenshot.sh`
Takes a screenshot of display `:99` and writes it to `/tmp/screenshot.png` (and/or prints path).

Preferred method:
- `import -display :99 -window root /tmp/screenshot.png`
or
- `xwd -display :99 -root | convert xwd:- png:/tmp/screenshot.png`

### `automation/click_xy.sh`
Usage:
- `click_xy.sh 123 456`
Should focus the main window if possible and click the coordinates using `xdotool`.

### `automation/find_and_click.py`
Given:
- `--template automation/assets/example_button.png`
- thresholds and retries
Find a UI element via OpenCV template matching and click it.

Also include:
- `--screenshot-out` to dump a frame for debugging
- clear exit codes (`0` success, `2` not found)

---

## 9) README: minimum guidance

README must cover:

- What WineBot is and when to use it
- Quickstart:
  - `docker compose --profile headless up --build`
  - `docker compose --profile interactive up --build`
- How to mount an app executable and run it
- How to connect:
  - VNC client to `localhost:5900`
  - Browser to `http://localhost:6080`
- How to take a screenshot in headless mode
- How to run the sample CV automation

---

## 10) Acceptance criteria (Definition of Done)

WineBot is “done” when:

- `docker compose --profile headless up` starts successfully and can launch a Windows exe under Wine
- `docker compose --profile interactive up` exposes VNC/noVNC and you can see the app window
- The prefix persists across restarts
- `automation/screenshot.sh` produces a valid screenshot file
- `automation/find_and_click.py` can match a provided template and click it reliably in the demo app

---

## 11) Troubleshooting guidance to include

Docs must include:
- Missing DLLs: use `winetricks vcrun20xx`
- 32-bit vs 64-bit prefix (`WINEARCH=win32`)
- Fonts issues (`winetricks corefonts`)
- No window focus: ensure openbox is running
- CV mismatch: enforce resolution and disable scaling
- VNC security notes (passwords, bind to localhost)

---

## 12) Development workflow for Codex

Codex should implement in this order:

1. Create repo structure and placeholder docs
2. Write Dockerfile and entrypoint
3. Add compose profiles and scripts
4. Add automation SDK scripts + demo assets
5. Validate commands (container builds and runs)
6. Polish docs and ensure reproducible usage

When unsure, prefer **simplicity**, **determinism**, and **debuggability**.
