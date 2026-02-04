# Status

## Current state
- **Dashboard UI:** Integrated noVNC with advanced settings (Scale-to-fit, View-only), activity log, and a real-time **Artifacts Viewer** for recordings and logs.
- **API Performance:** Optimized with **native /proc scanning** and async gathering for health checks; includes a background reaper for zombie processes and a **disk space watchdog**.
- **Correctness:** Enforced via **RecorderState Enums** and non-blocking **async subprocesses** across the API surface.
- **Openbox:** Fixed regression in `rc.xml` by restoring `Client` context mouse bindings (identified via bisection against `v0.8.0`).
- **Testing:** 39 unit tests passing (`pytest`); diagnostic suite verifies Mouse/Keyboard/CV/Clipboard/IO across Notepad, Regedit, and Winefile.

## Validation so far
- **Unit Tests:** `pytest /tests` passes 100%.
- **Bisection:** Confirmed `v0.8.0` had working mouse input; regression was caused by custom `rc.xml` missing pass-through bindings.
- **Diagnostics:** `scripts/diagnose-input-suite.sh` passes for Notepad (CV Mouse & Keyboard).
- **Automation Tools:** Parallel diagnostics for **AutoHotkey (AHK)** and **AutoIt** implemented and verified.
- **Performance:** Native process scanning reduced health-check latency and CPU overhead significantly.

## Known quirks
- **Persistent Mouse Issue:** Despite `xdotool` and Openbox fixes, direct clicks via VNC/noVNC are still failing to reach Wine apps.
- `docker-compose` v1 may error with `ContainerConfig` on recreate; use `down --remove-orphans` before `up`.

## Next steps (pick up here)
1. **Analyze x11vnc verbose logs:** Inspect `$SESSION_DIR/logs/x11vnc.log` to see if client clicks are being received and injected via XTest.
2. **Investigate X11 Pointer Grabs:** Check if Wine or Openbox is unexpectedly grabbing the pointer and preventing VNC injection.
3. **Verify Canvas Event Handling:** Test browser-side pointer event propagation in `api/ui/index.html` to rule out JS-level blocking.
4. **Finalize Input Fix:** Resolve the remaining VNC-to-Wine click gap.
