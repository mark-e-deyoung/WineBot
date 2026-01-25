#!/usr/bin/env bash
set -e

echo "--- Starting Windows Automation Smoke Tests ---"

# Ensure we have a display
if [ -z "$DISPLAY" ]; then
    echo "Error: DISPLAY not set. Are you running inside the container?"
    exit 1
fi

# Helper to take screenshot
take_screenshot() {
    local name="$1"
    echo "Taking screenshot: $name"
    import -window root "/tmp/screenshot_${name}.png" || echo "Warning: screenshot failed"
}

# 1. AutoIt
echo "Testing AutoIt..."
autoit tests/test_autoit.au3
take_screenshot "autoit"
echo "AutoIt test complete."

# 2. AutoHotkey
echo "Testing AutoHotkey..."
ahk tests/test_ahk.ahk
take_screenshot "ahk"
echo "AutoHotkey test complete."

echo "--- All tests passed! ---"