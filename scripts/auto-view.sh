#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/auto-view.sh [options]

Options:
  --mode auto|novnc|vnc  Viewer mode (default: auto)
  --novnc-url URL        noVNC URL (default: http://localhost:6080/vnc.html?autoconnect=1&resize=scale)
  --novnc-password PASS  noVNC password (optional; enables auto-connect without prompts)
  --vnc-host HOST        VNC host (default: localhost)
  --vnc-port PORT        VNC port (default: 5900)
  --viewer CMD           Specific VNC viewer command (optional)
  --timeout SEC          Wait for port timeout in seconds (default: 30)
  -h, --help             Show this help
EOF
}

mode="auto"
novnc_url="http://localhost:6080/vnc.html?autoconnect=1&resize=scale"
novnc_password=""
vnc_host="localhost"
vnc_port="5900"
timeout="30"
viewer_cmd=""

while [ $# -gt 0 ]; do
  case "$1" in
    --mode)
      mode="${2:-}"
      shift 2
      ;;
    --novnc-url)
      novnc_url="${2:-}"
      shift 2
      ;;
    --novnc-password)
      novnc_password="${2:-}"
      shift 2
      ;;
    --vnc-host)
      vnc_host="${2:-}"
      shift 2
      ;;
    --vnc-port)
      vnc_port="${2:-}"
      shift 2
      ;;
    --viewer)
      viewer_cmd="${2:-}"
      shift 2
      ;;
    --timeout)
      timeout="${2:-}"
      shift 2
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
done

wait_port() {
  local host="$1"
  local port="$2"
  local timeout_sec="$3"
  python3 - <<PY
import socket, time, sys
host = "${host}"
port = int("${port}")
timeout = int("${timeout_sec}")
start = time.time()
while time.time() - start < timeout:
    sock = socket.socket()
    sock.settimeout(1)
    try:
        sock.connect((host, port))
        sock.close()
        sys.exit(0)
    except OSError:
        time.sleep(0.5)
    finally:
        try:
            sock.close()
        except Exception:
            pass
sys.exit(1)
PY
}

open_browser() {
  local url="$1"
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$url" >/dev/null 2>&1 &
    return 0
  fi
  if command -v gio >/dev/null 2>&1; then
    gio open "$url" >/dev/null 2>&1 &
    return 0
  fi
  if command -v open >/dev/null 2>&1; then
    open "$url" >/dev/null 2>&1 &
    return 0
  fi
  return 1
}

if [ -n "$novnc_password" ]; then
  encoded_pass="$(NOVNC_PASSWORD="$novnc_password" python3 - <<'PY'
import os
import urllib.parse
print(urllib.parse.quote(os.environ["NOVNC_PASSWORD"]))
PY
)"
  if [[ "$novnc_url" == *\?* ]]; then
    novnc_url="${novnc_url}&password=${encoded_pass}"
  else
    novnc_url="${novnc_url}?password=${encoded_pass}"
  fi
fi

open_vnc() {
  if [ -n "$viewer_cmd" ]; then
    bash -lc "$viewer_cmd" >/dev/null 2>&1 &
    return 0
  fi

  if command -v vncviewer >/dev/null 2>&1; then
    vncviewer "${vnc_host}:${vnc_port}" >/dev/null 2>&1 &
    return 0
  fi
  if command -v gvncviewer >/dev/null 2>&1; then
    gvncviewer "${vnc_host}:${vnc_port}" >/dev/null 2>&1 &
    return 0
  fi
  if command -v remmina >/dev/null 2>&1; then
    remmina -c "vnc://${vnc_host}:${vnc_port}" >/dev/null 2>&1 &
    return 0
  fi
  if command -v vinagre >/dev/null 2>&1; then
    vinagre "vnc://${vnc_host}:${vnc_port}" >/dev/null 2>&1 &
    return 0
  fi
  if command -v krdc >/dev/null 2>&1; then
    krdc "vnc://${vnc_host}:${vnc_port}" >/dev/null 2>&1 &
    return 0
  fi
  if command -v open >/dev/null 2>&1; then
    open "vnc://${vnc_host}:${vnc_port}" >/dev/null 2>&1 &
    return 0
  fi
  return 1
}

if [ "$mode" = "auto" ] || [ "$mode" = "novnc" ]; then
  if wait_port "${vnc_host}" "${vnc_port}" "${timeout}"; then
    if open_browser "${novnc_url}"; then
      exit 0
    fi
  fi
fi

if [ "$mode" = "auto" ] || [ "$mode" = "vnc" ]; then
  if wait_port "${vnc_host}" "${vnc_port}" "${timeout}"; then
    if open_vnc; then
      exit 0
    fi
  fi
fi

echo "Failed to launch viewer automatically." >&2
echo "noVNC URL: ${novnc_url}" >&2
echo "VNC: ${vnc_host}:${vnc_port}" >&2
exit 1
