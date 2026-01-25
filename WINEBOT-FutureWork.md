# WineBot Future Work & Improvements

These recommendations aim to streamline the usage of `ghcr.io/mark-e-deyoung/winebot` as a base for CI/CD toolchains and automation, specifically resolving friction points encountered in the `borland-toolchains` project.

## 1. Expected Impact on Toolchain Projects

With the changes to `Dockerfile` and `entrypoint.sh` (see below), the `borland-toolchains` scripts can be significantly simplified:

1.  **Removal of Entrypoint Bypass:**
    *   Scripts will no longer need `--entrypoint bash`.
    *   Commands can be run naturally: `docker run ... bcb6-toolchain make target`.

2.  **Removal of Host-Side Permission Fixes:**
    *   By passing `-e HOST_UID=$(id -u)`, files generated in `/work` will naturally belong to the host user.
    *   The `chown -R ...` cleanup steps in `bcb6-toolchain.sh`, `delphi7-toolchain.sh`, and E2E scripts can be removed.

3.  **Simplified E2E Tests:**
    *   Manual setup of `Xvfb`, `DISPLAY`, and `wineserver` management in E2E scripts becomes unnecessary as the entrypoint handles it.
    *   Tests becomes as simple as `docker run -e HOST_UID=$(id -u) ... wine my_test_app.exe`.

## 2. Completed Improvements (Implemented 2026-01-25)

### A. Update `Dockerfile`
Added `gosu` to the install list in the `Dockerfile`. `gosu` is the recommended standard for robust signal handling and user switching in Docker entrypoints.

### B. Rewrite `entrypoint.sh`
Replaced the `entrypoint.sh` with logic that achieves:
1.  **Pass-through Execution:** Directly executes arguments passed to `docker run` (e.g., `docker run winebot make`).
2.  **Native Host UID/GID Mapping:** Dynamically updates the container user to match the host user, eliminating permission issues on mounted volumes.
3.  **Automatic Xvfb Lifecycle:** Handles display setup/teardown automatically for every command.