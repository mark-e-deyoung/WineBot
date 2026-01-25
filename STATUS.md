# Status

## Current state
- Headless and interactive services are stopped (last seen as `compose_winebot_1`, `compose_winebot-interactive_1` exited).
- Default app launch is `cmd.exe` when `APP_EXE` is unset (via `wineconsole /k echo WineBot ready`).
- **New Entrypoint (v0.4+ dev):** Supports pass-through execution (`docker run ... winebot make`), host UID mapping (`-e HOST_UID=$(id -u)`), and automatic Xvfb lifecycle.
- **Windows Automation:** AutoIt v3, AutoHotkey v1.1, and Python 3.11 (embedded) are installed and available in PATH.
- **Screenshots:** `automation/screenshot.sh` now generates timestamped filenames by default (`screenshot_YYYY-MM-DD_HH-MM-SS.png`) and supports custom directory targets.
- Xvfb stale lock cleanup and `HOME`/cache setup are in `docker/entrypoint.sh`.
- Automation commands should be run as `winebot` to avoid Wine prefix ownership issues.
- winedbg support is available for scripted commands and gdb proxy mode (external debugging).
- GitHub repo is live and release `v0.3` is published.
- Release workflow builds, smoke-tests (including debug checks), scans, and pushes to GHCR.

## Validation so far
- `automation/screenshot.sh` produced `/tmp/screenshot.png` inside the container.
- `automation/notepad_create_and_verify.py` succeeded in headless mode (full smoke test).
- Interactive smoke test validated VNC/noVNC processes and ports.
- winedbg command mode (`info proc`) works in headless runs.
- winedbg gdb proxy is reachable and gdb can attach and list threads.
- **Windows Automation Tools:** `autoit` and `ahk` verified against Notepad. `pywinauto` was removed due to Wine UIA incompatibility.
- GHCR image `ghcr.io/mark-e-deyoung/winebot:v0.3` is published and pullable.

## Known quirks
- `docker-compose` v1 is installed here (not the `docker compose` plugin).
- `docker-compose` v1 may error with `ContainerConfig` on recreate; remove the old container with `docker-compose ... rm -f -s` and re-run `up`.
- gdb may exit with code `137` in some container environments; treat it as valid if thread output is present.
- `automation/find_and_click.py` will return exit code `2` until a real template matches visible UI.

## Next steps (pick up here)
1. Install and run a real app using `scripts/install-app.sh` and `scripts/run-app.sh`.
2. Create specific automation scripts (using AutoIt or AHK) for target applications.
3. (Optional) Trigger the release workflow manually in GitHub Actions to publish a test image tag.
