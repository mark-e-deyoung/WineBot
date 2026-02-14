#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$(dirname "${BASH_SOURCE[0]}")/../diagnostics/diag_bundle.py" "$@"
