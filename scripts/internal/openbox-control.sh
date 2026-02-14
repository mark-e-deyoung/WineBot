#!/usr/bin/env bash
set -euo pipefail

action="${1:-}"

usage() {
  cat <<'EOF'
Usage: scripts/openbox-control.sh <reconfigure|restart>

Attempts to call the WineBot API for logging; falls back to openbox command directly.
EOF
}

if [ -z "$action" ]; then
  usage
  exit 1
fi

case "$action" in
  reconfigure|restart)
    ;;
  *)
    echo "Unknown action: $action" >&2
    usage
    exit 1
    ;;
esac

api_url="${WINEBOT_API_URL:-${WINEBOT_BASE_URL:-http://localhost:8000}}"
token="${API_TOKEN:-${WINEBOT_API_TOKEN:-}}"
endpoint="${api_url}/openbox/${action}"

curl_args=(-sS -X POST)
if [ -n "$token" ]; then
  curl_args+=(-H "X-API-Key: $token")
fi

if command -v curl >/dev/null 2>&1; then
  if curl "${curl_args[@]}" "$endpoint" >/dev/null 2>&1; then
    exit 0
  fi
fi

exec openbox "--${action}"
