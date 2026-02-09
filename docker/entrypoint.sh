#!/usr/bin/env bash
set -e

# Defaults
export WINEPREFIX="${WINEPREFIX:-/wineprefix}"
export DISPLAY="${DISPLAY:-:99}"
export SCREEN="${SCREEN:-1280x720x24}"

# 1. Root Level Setup (User creation, permissions)
source /scripts/init/00-setup-user.sh

# Drop privileges and re-execute this script as 'winebot'
if [ "$(id -u)" = "0" ]; then
    exec gosu winebot "$0" "$@"
fi

# --- USER CONTEXT (winebot) ---

# Prevent multiple entrypoint runs
if [ -f /tmp/entrypoint.user.pid ] && ps -p $(cat /tmp/entrypoint.user.pid) > /dev/null 2>&1; then
    echo "--> Entrypoint already running for user $(id -un) (PID $(cat /tmp/entrypoint.user.pid))."
    if [ $# -gt 0 ]; then
        exec "$@"
    else
        exit 0
    fi
fi
echo $$ > /tmp/entrypoint.user.pid

# Load runtime configuration overrides
WINEBOT_CONFIG_FILE="/wineprefix/winebot.env"
WINEBOT_INSTANCE_CONFIG="/wineprefix/winebot.${HOSTNAME}.env"

if [ -f "$WINEBOT_CONFIG_FILE" ]; then
    chmod 600 "$WINEBOT_CONFIG_FILE"
    set -a; source "$WINEBOT_CONFIG_FILE"; set +a
fi
if [ -f "$WINEBOT_INSTANCE_CONFIG" ]; then
    chmod 600 "$WINEBOT_INSTANCE_CONFIG"
    set -a; source "$WINEBOT_INSTANCE_CONFIG"; set +a
fi

# 2. Infrastructure Setup (Session, X11, WM)
echo "--> Pass 2: Infrastructure..."
source /scripts/init/10-setup-infra.sh

# 3. Wine Environment Setup (Prefix, Theme, VNC)
echo "--> Pass 3: Wine Environment..."
source /scripts/init/20-setup-wine.sh

# 4. Service Startup (API, Recorder, Supervisor)
echo "--> Pass 4: Services..."
source /scripts/init/30-start-services.sh

if [ "${DEBUG:-0}" = "1" ]; then
    echo "--> DEBUG: Windows automation tool versions..."
    (autoit /? | head -n 2) || true
    (ahk /? | head -n 2) || true
    (winpy -c "import sys; print(sys.version)" | head -n 1) || true
fi

# Keep container alive
if [ $# -eq 0 ]; then
    tail -f /dev/null
else
    "$@"
    EXIT_CODE=$?
    exit $EXIT_CODE
fi
