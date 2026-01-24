#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/smoke-test.sh [options]

Run a basic smoke test against the WineBot services.

Options:
  --include-interactive  Also verify VNC/noVNC services.
  --full                 Run the Notepad automation check.
  --no-build             Skip building the image.
  --cleanup              Stop services started by this script.
  -h, --help             Show this help.
EOF
}

include_interactive="0"
full="0"
build="1"
cleanup="0"

while [ $# -gt 0 ]; do
  case "$1" in
    --include-interactive)
      include_interactive="1"
      ;;
    --full)
      full="1"
      ;;
    --no-build)
      build="0"
      ;;
    --cleanup)
      cleanup="1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)"
compose_file="$repo_root/compose/docker-compose.yml"

if docker compose version >/dev/null 2>&1; then
  compose_cmd=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  compose_cmd=(docker-compose)
else
  echo "Docker Compose not found." >&2
  exit 1
fi

log() {
  printf '%s\n' "$*"
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

service_running() {
  local profile="$1"
  local service="$2"
  set +e
  "${compose_cmd[@]}" -f "$compose_file" --profile "$profile" exec -T --user winebot "$service" true >/dev/null 2>&1
  rc=$?
  set -e
  [ "$rc" -eq 0 ]
}

compose_up() {
  local profile="$1"
  local service="$2"
  local args=("${compose_cmd[@]}" -f "$compose_file" --profile "$profile" up -d)
  if [ "$build" = "1" ]; then
    args+=(--build)
  fi
  args+=("$service")
  "${args[@]}"
}

compose_exec() {
  local profile="$1"
  local service="$2"
  local cmd="$3"
  "${compose_cmd[@]}" -f "$compose_file" --profile "$profile" exec -T --user winebot "$service" bash -lc "$cmd"
}

wait_for_windows() {
  local profile="$1"
  local service="$2"
  local attempt
  for attempt in $(seq 1 20); do
    set +e
    windows="$(compose_exec "$profile" "$service" "DISPLAY=:99 wmctrl -l" 2>/dev/null)"
    rc=$?
    set -e
    if [ "$rc" -eq 0 ] && [ -n "${windows:-}" ]; then
      return 0
    fi
    sleep 0.5
  done
  fail "No windows detected on DISPLAY=:99 for $service"
}

started_headless="0"
started_interactive="0"

cleanup_services() {
  if [ "$cleanup" = "1" ]; then
    log "Stopping services started by smoke test..."
    if [ "$started_interactive" = "1" ]; then
      "${compose_cmd[@]}" -f "$compose_file" --profile interactive stop winebot-interactive
    fi
    if [ "$started_headless" = "1" ]; then
      "${compose_cmd[@]}" -f "$compose_file" --profile headless stop winebot
    fi
  fi
}

if [ "$cleanup" = "1" ]; then
  trap cleanup_services EXIT
fi

if service_running headless winebot; then
  log "Headless service already running."
else
  log "Starting headless service..."
  compose_up headless winebot
  started_headless="1"
fi

log "Waiting for headless desktop..."
wait_for_windows headless winebot

log "Checking Xvfb and openbox..."
compose_exec headless winebot "pgrep -x Xvfb >/dev/null"
compose_exec headless winebot "pgrep -x openbox >/dev/null"

log "Checking window list..."
window_count="$(compose_exec headless winebot "DISPLAY=:99 wmctrl -l | wc -l")"
window_count="$(echo "$window_count" | tr -d ' ')"
if [ "${window_count:-0}" -lt 1 ]; then
  fail "Expected at least one window, found ${window_count:-0}"
fi

log "Capturing screenshot..."
compose_exec headless winebot "./automation/screenshot.sh"
compose_exec headless winebot "test -s /tmp/screenshot.png"

log "Validating prefix persistence..."
marker="/wineprefix/drive_c/winebot_smoke_$(date +%s).txt"
compose_exec headless winebot "echo 'winebot smoke' > '$marker'"
"${compose_cmd[@]}" -f "$compose_file" --profile headless run --rm --user winebot --entrypoint bash winebot -lc "test -f '$marker'"
compose_exec headless winebot "rm -f '$marker'"

if [ "$full" = "1" ]; then
  log "Running Notepad automation..."
  notepad_output="/wineprefix/drive_c/users/winebot/Temp/winebot_smoke_test.txt"
  compose_exec headless winebot "pkill -f '[n]otepad.exe' >/dev/null 2>&1 || true"
  compose_exec headless winebot "python3 automation/notepad_create_and_verify.py --text 'WineBot smoke test' --output '$notepad_output' --launch --timeout 60 --save-timeout 60 --retry-interval 1 --delay 75"
fi

if [ "$include_interactive" = "1" ]; then
  if service_running interactive winebot-interactive; then
    log "Interactive service already running."
  else
    log "Starting interactive service..."
    compose_up interactive winebot-interactive
    started_interactive="1"
  fi

  log "Waiting for interactive desktop..."
  wait_for_windows interactive winebot-interactive

  log "Checking VNC/noVNC processes..."
  compose_exec interactive winebot-interactive "pgrep -x x11vnc >/dev/null"
  compose_exec interactive winebot-interactive "pgrep -f novnc_proxy >/dev/null || pgrep -f websockify >/dev/null"

  log "Checking VNC/noVNC ports..."
  compose_exec interactive winebot-interactive "python3 - <<'PY'
import socket
for port in (5900, 6080):
    sock = socket.socket()
    sock.settimeout(1)
    try:
        sock.connect(('127.0.0.1', port))
    except OSError as exc:
        raise SystemExit(f'Port {port} not accepting connections: {exc}') from exc
    finally:
        sock.close()
PY"
fi

log "Smoke test complete."
