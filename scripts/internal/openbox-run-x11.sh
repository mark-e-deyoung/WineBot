#!/usr/bin/env bash
set -euo pipefail

label="${1:-}"
shift || true

if [ -z "$label" ] || [ $# -lt 1 ]; then
  echo "Usage: openbox-run-x11.sh <label> <command...>" >&2
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
out_dir="${session_dir}/user/openbox"
mkdir -p "$log_dir" "$out_dir"

ts="$(date -u +%Y%m%dT%H%M%SZ)"
slug="$(echo "$label" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '_' | sed 's/^_\\|_$//g')"
out_file="${out_dir}/${ts}_${slug}.txt"
log_file="${log_dir}/${ts}_${slug}.log"

{
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Openbox menu: $label"
  echo "Command: $*"
} >>"$log_file"

{
  echo "WineBot Openbox: $label"
  echo "Command: $*"
  echo
  "$@"
} >"$out_file" 2>&1 || true

if command -v winepath >/dev/null 2>&1; then
  win_path="$(winepath -w "$out_file")"
else
  win_path="Z:${out_file}"
fi

nohup wine notepad "$win_path" >/dev/null 2>&1 </dev/null &
