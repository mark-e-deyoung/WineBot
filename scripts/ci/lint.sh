#!/usr/bin/env bash
set -euo pipefail
echo "--- Running Linting (Ruff + Mypy) ---"
ruff check .
mypy api automation tests --ignore-missing-imports
