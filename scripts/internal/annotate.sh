#!/usr/bin/env bash
set -e

# Wrapper for winebot_recorder annotate

SESSION_DIR=""
TEXT=""
KIND="annotation"
POS=""
STYLE=""
SOURCE="annotate.sh"

usage() {
    echo "Usage: $0 --text '...' [options]"
    echo "Options:"
    echo "  --session-dir DIR   Path to session directory (default: read from /tmp/winebot_current_session)"
    echo "  --type KIND         Event kind (subtitle, overlay, annotation... default: annotation)"
    echo "  --pos X,Y[,W,H]     Position for overlay"
    echo "  --style JSON        Style JSON"
    echo "  --source NAME       Source identifier"
}

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --session-dir)
        SESSION_DIR="$2"
        shift
        shift
        ;;
        --text)
        TEXT="$2"
        shift
        shift
        ;;
        --type)
        KIND="$2"
        shift
        shift
        ;;
        --pos)
        POS="$2"
        shift
        shift
        ;;
        --style)
        STYLE="$2"
        shift
        shift
        ;;
        --source)
        SOURCE="$2"
        shift
        shift
        ;;
        -h|--help)
        usage
        exit 0
        ;;
        *)
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
done

if [ -z "$SESSION_DIR" ]; then
    if [ -f /tmp/winebot_current_session ]; then
        SESSION_DIR=$(cat /tmp/winebot_current_session)
    fi
fi

if [ -z "$SESSION_DIR" ]; then
    echo "Error: --session-dir not specified and /tmp/winebot_current_session not found."
    exit 1
fi

if [ -z "$TEXT" ]; then
    echo "Error: --text is required."
    exit 1
fi

CMD=(python3 -m automation.recorder annotate --session-dir "$SESSION_DIR" --text "$TEXT" --kind "$KIND" --source "$SOURCE")

if [ -n "$POS" ]; then
    CMD+=(--pos "$POS")
fi
if [ -n "$STYLE" ]; then
    CMD+=(--style "$STYLE")
fi

"${CMD[@]}"
