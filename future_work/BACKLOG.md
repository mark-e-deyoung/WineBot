# WineBot Feature Backlog & Future Work

This document tracks identified architectural improvements, feature requests, and technical debt deferred during active sprints.

## 1. Discoverability & Multi-Node Support
### **WineBot Hub**
- **Description:** A central dashboard that aggregates mDNS (Bonjour) records from all WineBot instances on the local network.
- **Why:** Allows users to manage multiple containers/nodes from a single interface.
- **Status:** Recommended (UX Review 2026-02-15).

## 2. Resiliency & Correctness
### **Global Command Timeouts**
- **Description:** Implement a `WINEBOT_COMMAND_TIMEOUT` environment variable to allow global configuration of subprocess execution limits (currently hardcoded to 5s in many places).
- **Target:** `api/utils/process.py` and `api/routers/input.py`.

### **Wine Registry Checkpointing**
- **Description:** Implement "Auto-Snapshotting" for the Wine Registry (`system.reg`, `user.reg`).
- **Why:** Allows a session to resume from a known good state if the container crashes or is restarted during long-running automations.

## 3. Performance & Optimization
### **Log Compression (zstd)**
- **Description:** Use the `zstandard` library to compress high-frequency `.jsonl` trace logs.
- **Benefit:** Reduces Disk I/O pressure and storage footprint for intensive automation traces.
- **Status:** Requirements added; implementation pending.

### **Modular 'Slim' Build Intent**
- **Description:** Create a production-hardened image intent that strips build tools, compilers, and development headers.
- **Status:** Next Step #2 in STATUS.md.

## 4. Security & Safety
### **Mandatory Authentication**
- **Description:** Generate a unique random API token on startup if `API_TOKEN` is not provided, rather than allowing unauthenticated access.
- **Benefit:** Hardens deployments against remote takeover by default.

### **VNC Rate Limiting**
- **Description:** Implement connection rate limiting for `x11vnc` to mitigate brute-force password attacks.

### **Privacy Masking (Recorder)**
- **Description:** Add a configuration to the video recorder to blur specific regions of the screen (e.g., system clock, sensitive fields) using positional overlays.

### **Automated Security Scanning**
- **Description:** Integrate `trivy` or `snyk` into the GitHub Actions CI pipeline to scan for vulnerabilities in the base image and Python dependencies.

## 5. Testing & Assurance (Containerized)
### **Chaos Resiliency Suite**
- **Description:** A containerized diagnostic tool that randomly kills non-critical processes (`explorer.exe`, `tint2`, `openbox`) while automation is active.
- **Requirement:** Must run via `docker compose exec` to verify the supervisor's self-healing capabilities without host dependencies.

### **API Stress & Fuzzing**
- **Description:** A `pytest` suite targeting the API with high-frequency requests and malformed payloads.
- **Requirement:** Executed within the `playwright-tests` container or a dedicated `api-tester` service.

### **Latency-Aware Input Metrics**
- **Description:** Extend tracing to calculate "Mean Time to Action" (MTA), identifying performance regressions in the input stack.
- **Requirement:** Integrated into the standard `smoke-test.sh` routine.

### **Visual Regression (Dashboard)**
- **Description:** Automated pixel-comparison tests for the Dashboard UI using Playwright.
- **Requirement:** Run within the `test-runner` container to ensure the UI remains consistent across different builds and browsers.
- **Goal:** Enforce the "Cyber-Industrial Dark" aesthetic defined in `policy/visual-style-and-ux-policy.md`.

## 8. User Experience & Accessibility
### **Automated A11y Scanning (Lighthouse)**
- **Description:** Integrate Google Lighthouse CI to scan the dashboard for Accessibility (A11y) and Performance.
- **Goal:** Maintain a minimum score of 90/100 for all release builds.

### **Keyboard Navigation Testing**
- **Description:** Implement Playwright interaction tests that verify the dashboard is fully usable without a mouse.
- **Requirement:** Ensure logical Tab ordering and proper focus indicators for all controls.

## 7. Internal Versioning & Compatibility
### **Configuration Schema Versioning**
- **Description:** Add a `WINEBOT_CONFIG_SCHEMA_VERSION` to `winebot.env`.
- **Why:** Allows the API to validate that the provided environment variables match the expected schema of the current build, preventing runtime errors due to stale configuration.

### **Wine Prefix Compatibility Guard**
- **Description:** Store the Wine version string in `/opt/winebot/prefix-template/metadata.json` during build.
- **Why:** Prevents subtle binary compatibility issues if a container is updated to a newer Wine version but resumes an old session directory.

### **API Version Negotiation**
- **Description:** Implement a `/handshake` or `/negotiate` endpoint.
- **Why:** Allows autonomous agents to discover which API features and schema versions are supported by a specific WineBot node.
