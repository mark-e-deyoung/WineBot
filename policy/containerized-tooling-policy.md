# Policy: Containerized Tooling and Environment Isolation

## 1. Mandate
All software engineering tasks including building, linting, unit testing, integration testing, and end-to-end (E2E) testing **MUST** be performed within the project's defined Docker containers.

## 2. Prohibition of Host-Level Tooling
*   **No Host Virtual Environments:** Developers and agents are strictly forbidden from creating or using Python virtual environments (`.venv`, `venv`, etc.) on the host filesystem.
*   **No Host Package Installation:** System-level packages or pip packages required for the project must not be installed directly on the host. All dependencies must be defined in `requirements/*.txt` and `docker/Dockerfile`.
*   **No Host-Based Test Execution:** Commands like `pytest`, `ruff`, or `mypy` must never be executed directly on the host shell.

## 3. Approved Execution Patterns
All tasks must use the containerized runners defined in `compose/docker-compose.yml`:

| Task | Command Pattern |
| :--- | :--- |
| **Linting** | `docker compose -f compose/docker-compose.yml run --rm lint-runner` |
| **Unit/E2E Tests** | `docker compose -f compose/docker-compose.yml --profile test --profile interactive run --rm test-runner` |
| **Diagnostics** | `docker compose -f compose/docker-compose.yml run --rm winebot /scripts/diagnostics/diagnose-master.sh` |

## 5. Tooling Equivalence
To prevent "CI Surprises," the exact same commands and configurations **MUST** be used locally and in CI/CD.
*   **Unified Scripts:** All linting and testing logic must reside in `scripts/ci/` and be invoked by the container runners.
*   **Version Parity:** The `test-runner` and `lint-runner` images must be used for all local checks to ensure identical environment (Python version, OS libraries).
*   **Local Pre-verification:** Developers are encouraged to run `./scripts/bin/dev-lint.sh` and `./scripts/bin/dev-test.sh` before pushing. These helpers will wrap the necessary `docker compose` calls.
