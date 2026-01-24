# Testing

WineBot includes a simple smoke test to validate the display stack, Wine prefix, and optional VNC/noVNC services.

## Quick smoke test (headless)

`scripts/smoke-test.sh`

Checks performed:

- Xvfb and openbox are running
- A window is present on `DISPLAY=:99`
- Screenshot capture works (`/tmp/screenshot.png`)
- The Wine prefix persists across containers

## Full smoke test

`scripts/smoke-test.sh --full`

Adds a Notepad automation round-trip. The test writes a file under
`/wineprefix/drive_c/users/winebot/Temp/` for reliability in headless mode.

## Interactive checks

`scripts/smoke-test.sh --include-interactive`

Verifies `x11vnc` and noVNC/websockify are running and accepting connections.

## Debug checks

`scripts/smoke-test.sh --include-debug`

Runs a minimal winedbg command (`info proc`) in a one-off container.

`scripts/smoke-test.sh --include-debug-proxy`

Starts a one-off container under winedbg gdb proxy, verifies the target exe is running, and attaches via gdb to list threads.

Note: gdb may exit with code `137` in some container environments; the smoke test treats it as a pass when threads are reported.

## Cleanup

By default the smoke test leaves services running. To stop them:

`scripts/smoke-test.sh --cleanup`

For CI, prefer `--full --cleanup`.
