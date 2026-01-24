#!/usr/bin/env bash
set -euo pipefail

display_value="${DISPLAY:-:99}"
output_path="${1:-/tmp/screenshot.png}"

import -display "$display_value" -window root "$output_path"
echo "$output_path"

