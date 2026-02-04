#!/usr/bin/env bash
set -euo pipefail

label="${1:-}"
shift || true

if [ -z "$label" ] || [ $# -lt 1 ]; then
  echo "Usage: openbox-run-wine.sh <label> <command...>" >&2
  exit 1
fi

session_dir=""
if [ -n "${WINEBOT_SESSION_DIR:-}" ]; then
  session_dir="$WINEBOT_SESSION_DIR"
elif [ -f /tmp/winebot_current_session ]; then
  session_dir="$(cat /tmp/winebot_current_session)"
fi

if [ -z "$session_dir" ]; then
  session_dir="/tmp/winebot_session_unknown"
fi

log_dir="${session_dir}/logs/openbox"
mkdir -p "$log_dir"

ts="$(date -u +%Y%m%dT%H%M%SZ)"
slug="$(echo "$label" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '_' | sed 's/^_\\|_$//g')"
log_file="${log_dir}/${ts}_${slug}.log"

cmd=( "$@" )
if [ "${cmd[0]:-}" = "wine" ] && { [ "${cmd[1]:-}" = "cmd" ] || [ "${cmd[1]:-}" = "cmd.exe" ]; }; then
  if command -v wineconsole >/dev/null 2>&1; then
    cmd=( "wineconsole" "cmd" "${cmd[@]:2}" )
  fi
fi

{
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Openbox menu: $label"
  echo "Command: ${cmd[*]}"
} >>"$log_file"

nohup "${cmd[@]}" >>"$log_file" 2>&1 </dev/null &
