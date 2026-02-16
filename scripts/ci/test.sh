#!/usr/bin/env bash
set -euo pipefail
echo "--- Running Unit Tests ---"
pytest tests/test_api.py tests/test_input_validation.py
