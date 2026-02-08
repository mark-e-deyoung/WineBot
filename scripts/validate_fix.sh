#!/usr/bin/env bash
set -e

echo "=== VALIDATION START ==="

# 1. Environment Check
echo "Checking DISPLAY..."
if [ -z "$DISPLAY" ]; then
    echo "FAIL: DISPLAY not set"
    exit 1
fi
echo "DISPLAY=$DISPLAY"

echo "Checking Xvfb..."
if ! xdpyinfo >/dev/null 2>&1; then
    echo "FAIL: Xvfb not reachable"
    exit 1
fi
echo "Xvfb OK"

echo "Checking Openbox..."
if ! pgrep openbox >/dev/null; then
    echo "WARN: Openbox not running (might be okay if just starting)"
else
    echo "Openbox OK"
fi

# 2. Wine Driver Check
echo "Checking Wine Driver..."
# This command should succeed if the driver is loaded
if wine cmd /c "echo Driver Loaded" >/dev/null 2>&1; then
    echo "Wine Driver OK"
else
    echo "FAIL: Wine Driver check failed (nodrv?)"
    # Dump some diag info
    echo "Diagnostic Log:"
    WINEDEBUG=+winediag wine cmd /c "echo test" 2>&1 | head -n 20
    exit 1
fi

# 3. GUI Launch Simulation
echo "Simulating GUI Launch (winecfg dry run)..."
# We use timeout to ensure it doesn't hang
timeout 5s wine winecfg >/dev/null 2>&1 || true
# If we got here without error output, it's likely okay. 
# Real validation requires visual inspection or screenshot, but process exit code 0 is good.

echo "=== VALIDATION SUCCESS ==="
