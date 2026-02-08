# Status

## Current state
- **Wine 10.0 Hardening:** Resolved "clicks not passing through" blocker by forcing a 1920x1080 virtual desktop via registry keys and a background supervisor daemon that keeps "Wine Desktop" maximized and undecorated.
- **Recorder v2:** Segmented recording system verified. Fixed global metadata embedding in MKV files (WINEBOT_SESSION_ID) to support robust traceability.
- **Dashboard UI:** Added dynamic versioning (Release v0.9.0) and a "Reset Workspace" recovery button to fix window manager desync.
- **API Performance:** Optimized with native /proc scanning and async gathering for health checks; includes a background reaper for zombie processes and a disk space watchdog.
- **Testing:** Comprehensive recording integration tests passing; diagnostic suite verifies Mouse/Keyboard/CV/Clipboard/IO across Notepad, Regedit, and Winefile.

## Validation so far
- **Wine Desktop Maximization:** Verified via X11 probes that the Wine 10.0 desktop window now correctly covers the full 1920x1080 canvas, allowing VNC clicks to register globally.
- **Recording Tests:** `tests/run_recording_tests.sh` passes 100%, verifying video stream health, metadata tags, and event log synchronization.
- **Process Persistence:** Implemented `wineserver -p` and an explorer supervisor in `entrypoint.sh` to prevent accidental teardown of the Windows environment.
- **VNC Input Fix:** Identified and resolved a blocking issue in `x11vnc` where concurrent FramebufferUpdates prevented input injection. Added `-threads` to `x11vnc` in `entrypoint.sh`.

## Known quirks
- `docker-compose` v1 may error with `ContainerConfig` on recreate; use `down --remove-orphans` before `up`.
- `vulkan_init_once` errors in logs are harmless (no GPU in container); Wine fallback to software rendering works correctly.

## Next steps (pick up here)
1. Tag and release v0.9.0 as stable.
2. Update documentation (README.md) to reflect the new resolution/maximization requirements.
3. Clean up the `artifacts/sessions` volume and prepare for production GHCR release.
