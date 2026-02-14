# Status

## Current state
- **Version:** v0.9.3 (Stable)
- **Build Optimization:** Removed Windows `pip` bootstrap; moved `wineboot` to build-time. Clean builds are ~20% faster.
- **CLI & Output:** Resolved Issue #2. Headless CLI apps now return `stdout`/`stderr` and exit codes correctly.
- **Network Discovery:** Issue #3 implemented (mDNS). Sessions now announce themselves as `_winebot-session._tcp.local.`.
- **Hardening:** Enhanced path validation and supervisor stability.
- **Persistence:** Refined dynamic user profile symlinking; settings now auto-persist in the dashboard.

## Next steps (pick up here)
1. Complete verification of mDNS discovery (Issue #3).
2. Implement Modular 'Slim' Build Intent (Issue #4).
3. Investigate Stripped Custom Wine Build (Issue #5).
