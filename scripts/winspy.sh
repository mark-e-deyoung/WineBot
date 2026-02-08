#!/usr/bin/env bash
set -euo pipefail

if [ "${WINEBOT_SUPPRESS_DEPRECATION:-0}" != "1" ]; then
    echo "DEPRECATED: scripts/winspy.sh is deprecated. Use the /inspect/window API or scripts/winebotctl inspect window." >&2
fi

# Source the X11 helper
if [ -f "/scripts/lib/x11_env.sh" ]; then
    source "/scripts/lib/x11_env.sh"
elif [ -f "$(dirname "$0")/lib/x11_env.sh" ]; then
    source "$(dirname "$0")/lib/x11_env.sh"
fi

winebot_ensure_x11_env

WINSPY_DIR="/opt/winebot/windows-tools/WinSpy"
# Often standard unzip puts it in current dir or subdir.
# The zip has "winspy.exe".
EXE="$WINSPY_DIR/winspy.exe"

if [ ! -f "$EXE" ]; then
    # Try alternate location
    if [ -f "$HOME/windows-tools/WinSpy/winspy.exe" ]; then
        WINSPY_DIR="$HOME/windows-tools/WinSpy"
        EXE="$WINSPY_DIR/winspy.exe"
    fi
fi

if [ ! -f "$EXE" ]; then
    # Try finding it in case structure differs
    FOUND=$(find "$WINSPY_DIR" -iname "winspy.exe" -print -quit 2>/dev/null || true)
    if [ -z "$FOUND" ] && [ -d "$HOME/windows-tools/WinSpy" ]; then
         FOUND=$(find "$HOME/windows-tools/WinSpy" -iname "winspy.exe" -print -quit 2>/dev/null || true)
    fi
    if [ -n "$FOUND" ]; then
        EXE="$FOUND"
    else
        echo "Error: winspy.exe not found."
        echo "Please run 'bash /scripts/install-inspectors.sh' (if inside container)"
        exit 1
    fi
fi

echo "Starting WinSpy..."
wine "$EXE" &
PID=$!
echo "WinSpy started with PID $PID"
wait $PID
