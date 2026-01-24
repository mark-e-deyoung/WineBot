# Status

## Current state
- Headless and interactive services are stopped (last seen as `compose_winebot_1`, `compose_winebot-interactive_1` exited).
- Default app launch is `cmd.exe` when `APP_EXE` is unset (via `wineconsole /k echo WineBot ready`).
- Xvfb stale lock cleanup and `HOME`/cache setup are in `docker/entrypoint.sh`.
- Automation commands should be run as `winebot` to avoid Wine prefix ownership issues.
- winedbg support is available for scripted commands and gdb proxy mode (external debugging).
- GitHub repo is live and release `v0.1` is published.
- Release workflow builds, smoke-tests, scans, and pushes to GHCR.

## Validation so far
- `automation/screenshot.sh` produced `/tmp/screenshot.png` inside the container.
- `automation/notepad_create_and_verify.py` succeeded in headless mode (full smoke test).
- Interactive smoke test validated VNC/noVNC processes and ports.
- winedbg command mode (`info proc`) works in headless runs.
- winedbg gdb proxy is reachable and gdb can attach and list threads.

## Known quirks
- `docker-compose` v1 is installed here (not the `docker compose` plugin).
- `docker-compose` v1 may error with `ContainerConfig` on recreate; remove the old container with `docker-compose ... rm -f -s` and re-run `up`.
- gdb may exit with code `137` in some container environments; treat it as valid if thread output is present.
- `automation/find_and_click.py` will return exit code `2` until a real template matches visible UI.

## Next steps (pick up here)
1. Install and run a real app using `scripts/install-app.sh` and `scripts/run-app.sh`.
2. Capture a real UI element and re-run `automation/find_and_click.py` with that template.
3. Add app-specific winedbg scripts (breakpoints or scripted commands) if deeper debugging is needed.
4. (Optional) Trigger the release workflow manually in GitHub Actions to publish a test image tag.
