#!/usr/bin/env bash
set -e

# Defaults
export WINEPREFIX="${WINEPREFIX:-/wineprefix}"
export DISPLAY="${DISPLAY:-:99}"
export SCREEN="${SCREEN:-1920x1080x24}"

# --- ROOT CONTEXT: User & Permission Setup ---
if [ "$(id -u)" = "0" ]; then
    USER_ID=${HOST_UID:-1000}
    GROUP_ID=${HOST_GID:-1000}

    # Update 'winebot' user to match host UID/GID if requested
    if [ "$USER_ID" != "$(id -u winebot)" ] || [ "$GROUP_ID" != "$(id -g winebot)" ]; then
        echo "--> Updating winebot user to UID:GID = $USER_ID:$GROUP_ID"
        groupmod -o -g "$GROUP_ID" winebot
        usermod -o -u "$USER_ID" -g "$GROUP_ID" winebot
    fi

    # Ensure critical directories are owned by the user
    mkdir -p "$WINEPREFIX" "/home/winebot/.cache" "/artifacts"
    chown -R winebot:winebot "/home/winebot" "$WINEPREFIX" "/artifacts"
    chmod 777 /tmp

    # Handle .X11-unix specifically for Xvfb
    mkdir -p /tmp/.X11-unix
    chmod 1777 /tmp/.X11-unix

    # Drop privileges and re-execute this script as 'winebot'
    exec gosu winebot "$0" "$@"
fi

# --- USER CONTEXT (winebot) ---

# 1. Clean up stale locks from previous runs (if any)
rm -f "/tmp/.X${DISPLAY##*:}-lock" "/tmp/.X11-unix/X${DISPLAY##*:}"

# 2. Start Xvfb
Xvfb "$DISPLAY" -screen 0 "$SCREEN" -ac +extension RANDR >/dev/null 2>&1 &
XVFB_PID=$!
sleep 1 # Give Xvfb a moment to start

if [ -n "$RECORDER_PID" ]; then
    scripts/annotate.sh --text "Xvfb ready on $DISPLAY" --type lifecycle --source entrypoint
fi

# 3. Start Window Manager (Openbox)
openbox >/dev/null 2>&1 &

# --- Recorder Setup ---
RECORDER_PID=""
if [ "${WINEBOT_RECORD:-0}" = "1" ]; then
    echo "--> Starting Recorder..."
    
    # Generate Session ID
    SESSION_TS=$(date +%s)
    SESSION_RAND=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)
    SESSION_ID="session-${SESSION_TS}-${SESSION_RAND}${WINEBOT_SESSION_LABEL:+-${WINEBOT_SESSION_LABEL}}"
    
    SESSION_ROOT="${WINEBOT_SESSION_ROOT:-/artifacts/sessions}"
    SESSION_DIR="${SESSION_ROOT}/${SESSION_ID}"
    
    # Export for other tools
    export WINEBOT_SESSION_ID="$SESSION_ID"
    export WINEBOT_SESSION_DIR="$SESSION_DIR"
    echo "$SESSION_DIR" > /tmp/winebot_current_session
    
    # Resolution parsing: handles 1920x1080x24 -> 1920x1080, and 1280x720 -> 1280x720
    if [[ "$SCREEN" == *x*x* ]]; then
        RES="${SCREEN%x*}"
    else
        RES="$SCREEN"
    fi
    
    # Start Recorder
    python3 -m automation.recorder start \
        --session-dir "$SESSION_DIR" \
        --display "$DISPLAY" \
        --resolution "$RES" \
        --fps 30 &
    RECORDER_PID=$!
    
    echo "Recorder started (PID: $RECORDER_PID) in $SESSION_DIR"
fi

stop_recorder() {
    if [ -n "$RECORDER_PID" ]; then
        echo "--> Stopping Recorder..."
        python3 -m automation.recorder stop --session-dir "$SESSION_DIR" || true
        wait "$RECORDER_PID" || true
        RECORDER_PID=""
    fi
}

trap 'stop_recorder' EXIT
# ----------------------

# 4. Start VNC/noVNC if requested
if [ "${ENABLE_VNC:-0}" = "1" ] || [ "${MODE:-headless}" = "interactive" ]; then
    echo "--> Starting VNC/noVNC services..."
    VNC_ARGS=("-display" "$DISPLAY" "-forever" "-shared" "-rfbport" "${VNC_PORT:-5900}" "-bg")
    if [ -n "${VNC_PASSWORD:-}" ]; then
        mkdir -p "$HOME/.vnc"
        x11vnc -storepasswd "$VNC_PASSWORD" "$HOME/.vnc/passwd"
        VNC_ARGS+=("-rfbauth" "$HOME/.vnc/passwd")
    else
        VNC_ARGS+=("-nopw")
    fi
    x11vnc "${VNC_ARGS[@]}" >/dev/null 2>&1

    # Start noVNC (websockify)
    websockify --web /usr/share/novnc/ "${NOVNC_PORT:-6080}" "localhost:${VNC_PORT:-5900}" >/dev/null 2>&1 &
fi

# 5. Initialize Wine Prefix (if needed)
if [ "${INIT_PREFIX:-1}" = "1" ] && [ ! -f "$WINEPREFIX/system.reg" ]; then
    echo "--> Initializing WINEPREFIX..."
    [ -n "$RECORDER_PID" ] && scripts/annotate.sh --text "Initializing WINEPREFIX..." --type lifecycle --source entrypoint
    wineboot --init >/dev/null 2>&1
    [ -n "$RECORDER_PID" ] && scripts/annotate.sh --text "WINEPREFIX ready" --type lifecycle --source entrypoint
else
    # Ensure Wine services (explorer, etc.) are running
    wine explorer >/dev/null 2>&1 &
fi

# 6. Execute under winedbg if requested
# ... (omitting winedbg block context for brevity in replace, but I'll include enough) ...
if [ "${ENABLE_WINEDBG:-0}" = "1" ]; then
# ...
    echo "--> Running under winedbg ($WINEDBG_MODE): ${CMD[*]}"
    [ -n "$RECORDER_PID" ] && scripts/annotate.sh --text "Launching app under winedbg: ${CMD[*]}" --type lifecycle --source entrypoint
    exec winedbg "${WINEDBG_ARGS[@]}" "${CMD[@]}"
fi

# Start API if enabled
if [ "${ENABLE_API:-0}" = "1" ]; then
    echo "Starting API server on port 8000..."
    [ -n "$RECORDER_PID" ] && scripts/annotate.sh --text "Starting API server" --type lifecycle --source entrypoint
    # Ensure X11 env is sourced for the python process if needed, 
    # though subprocess calls in server.py usually source x11_env.sh via wrapper scripts.
    # We run it as winebot user.
    if [ "$(id -u)" = "0" ]; then
        gosu winebot uvicorn api.server:app --host 0.0.0.0 --port 8000 &
    else
        uvicorn api.server:app --host 0.0.0.0 --port 8000 &
    fi
fi

# Keep container alive (if no command provided)
if [ -z "$@" ]; then
    [ -n "$RECORDER_PID" ] && scripts/annotate.sh --text "Container idle (waiting)" --type lifecycle --source entrypoint
    tail -f /dev/null
else
    [ -n "$RECORDER_PID" ] && scripts/annotate.sh --text "Launching: $@" --type lifecycle --source entrypoint
    "$@"
    EXIT_CODE=$?
    [ -n "$RECORDER_PID" ] && scripts/annotate.sh --text "App exited with code $EXIT_CODE" --type lifecycle --source entrypoint
    exit $EXIT_CODE
fi