#!/usr/bin/env bash
set -euo pipefail

display_value="${DISPLAY:-:99}"
# Default to /tmp if no argument provided
target="${1:-/tmp}"

# Generate timestamp: YYYY-MM-DD_HH-MM-SS
timestamp=$(date +%Y-%m-%d_%H-%M-%S)
filename="screenshot_${timestamp}.png"

if [ -d "$target" ]; then
    # It's a directory (remove trailing slash if present, then append filename)
    output_path="${target%/}/$filename"
else
    # It's a file path (user specified the exact filename)
    output_path="$target"
fi

import -display "$display_value" -window root "$output_path"
echo "$output_path"