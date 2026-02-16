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

## 4. Rationale
This policy ensures:
1.  **Reproducibility:** Every developer and CI/CD environment uses the exact same toolchain versions.
2.  **Host Integrity:** Prevents pollution of the user's system with project-specific dependencies.
3.  **Security:** Minimizes the risk of malicious or buggy code affecting the host system.
