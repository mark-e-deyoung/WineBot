# Status

## Current state
- **Version:** v0.9.5 (Stable)
- **Status:** **Verified Stable** (All Unit/E2E Tests Passing)
- **Robustness:** 
    - Resolved `wmctrl` segfaults by migrating to `xdotool` and `xprop`.
    - Implemented supervisor loops for critical automation tracers (AHK).
    - Fixed AutoHotkey input capture logic for synthetic events in Wine.
- **Dashboard UI Overhaul:**
    - **Developer Mode:** Diagnostic panels hidden by default to reduce cognitive load.
    - **Floating Toolbar:** Viewer-centric controls (Scale, Focus, Inject) moved to a canvas overlay.
    - **System Health Summary:** Consolidated 10+ badges into a single, high-level status card.
    - **Feedback Loops:** Implemented Toast notifications for all major actions (Screenshots, Recording).
    - **Visual Artifacts:** Added screenshot thumbnails for immediate visual verification.
    - **Mobile Optimized:** Implementation of a sliding drawer menu for control panel on small screens.
- **API Stability & Correctness:** 
    - **Non-blocking Input:** Refactored `/input/mouse/click` to use asynchronous subprocess execution, preventing event-loop stalls.
    - **Comprehensive Validation:** Implemented boundary checks, window targeting, and relative coordinate clicking.
    - **Atomic Sessions:** Session directory creation is now atomic (temp initialization followed by rename).
- **Security Hardening:**
    - **Least Privilege:** Volume mounts for `apps` and `automation` are now Read-Only by default.
    - **VNC Lockdown:** API now detects and warns if VNC is exposed on a public IP without protection.
    - **Policy:** Formalized `SECURITY.md` for SSH tunneling and isolation guidance.
- **Modular 'Slim' Build Intent:** (DONE) Image refactor saves 1.4GB in CI by making pre-warmed prefix template optional.
- **Quality Assurance:**
    - **UI/UX Suite:** Implemented `tests/e2e/test_ux_quality.py` for automated visual and functional UX testing.
    - **Fast-Fail CI:** Refactored GitHub Actions into Pre-flight (Lint/Unit) and Integration (Integration) stages.
    - **Local Guardrails:** Integrated `pre-commit` and `dev-watch.sh` for near-instant developer feedback.

## Next steps (pick up here)
1. Investigate Stripped Custom Wine Build (Issue #5).
2. Enhance `inspect/window` API to return geometry for precise automation.
3. Integrate Google Lighthouse CI for automated A11y/Performance scoring.
