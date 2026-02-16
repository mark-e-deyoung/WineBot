#!/usr/bin/env bash
set -euo pipefail
echo "--- Running Linting (Ruff + Mypy) ---"
ruff check .
mypy api automation --ignore-missing-imports
