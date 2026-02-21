# Status

## Current state
- **Version:** v0.9.5 (Stable)
- **Status:** **Verified Stable & Published** (CI/CD Release Complete)
- **Registry:** `ghcr.io/SemperSupra/winebot:v0.9.5` (Signed via Cosign/OIDC)
- **Release Highlights:**
    - **Security:** Patched CVE-2026-26007 by upgrading `cryptography` to `46.0.5`.
    - **CI/CD Reliability:** 
        - Resolved prefix initialization race conditions by implementing API-driven healthchecks in `smoke-test.sh`.
        - Standardized image tagging (`verify-test-final-test`) to ensure environment parity across testing stages.
        - Hardened Dockerfile by removing `--ignore-installed` to prevent package version drift.
- **Robustness:** 
    - Resolved `wmctrl` segfaults by migrating to `xdotool` and `xprop`.
    - Implemented supervisor loops for critical automation tracers (AHK).
    - Fixed AutoHotkey input capture logic for synthetic events in Wine.
- **Dashboard UI Overhaul:**
    - **Developer Mode:** Diagnostic panels hidden by default to reduce cognitive load.
    - **Floating Toolbar:** Viewer-centric controls moved to a canvas overlay.
    - **System Health Summary:** Consolidated status badges into a single high-level card.
    - **Mobile Optimized:** Implementation of a sliding drawer menu for control panel.
- **API Stability:** 
    - **Non-blocking Input:** Asynchronous subprocess execution for mouse/keyboard events.
    - **Comprehensive Validation:** Boundary checks and window targeting.
- **Modular Build Intent:** Image refactor saves 1.4GB in CI via optional pre-warmed prefix templates.
- **Quality Assurance:**
    - **E2E UX Suite:** Automated visual and functional UX testing (`tests/e2e/test_ux_quality.py`).
    - **Fast-Fail CI:** Multi-stage GitHub Actions with verification of signed artifacts.

## Next steps
1. Implement Visual Regression diffing (Tier 3 UX enforcement).
2. Investigate Stripped Custom Wine Build (Issue #5).
3. Integrate Google Lighthouse CI for automated A11y/Performance scoring.
