#!/usr/bin/env bash
set -euo pipefail

export WINEPREFIX="${WINEPREFIX:-/wineprefix}"
export DISPLAY="${DISPLAY:-:99}"
export SCREEN="${SCREEN:-1920x1080x24}"
export MODE="${MODE:-headless}"
export INIT_PREFIX="${INIT_PREFIX:-1}"
export ENABLE_VNC="${ENABLE_VNC:-0}"
export VNC_PORT="${VNC_PORT:-5900}"
export NOVNC_PORT="${NOVNC_PORT:-6080}"

display_number="${DISPLAY##*:}"
display_number="${display_number%%.*}"
if [ -z "$display_number" ]; then
  display_number="99"
fi
lock_file="/tmp/.X${display_number}-lock"
socket_file="/tmp/.X11-unix/X${display_number}"
if [ -f "$lock_file" ]; then
  lock_pid="$(cat "$lock_file" 2>/dev/null || true)"
  if [ -z "$lock_pid" ] || ! kill -0 "$lock_pid" 2>/dev/null; then
    rm -f "$lock_file" "$socket_file"
  fi
fi

if [ -n "${WINEARCH:-}" ]; then
  export WINEARCH
else
  unset WINEARCH
fi

if [ "${1:-}" = "--run-as-user" ]; then
  shift
fi

if [ "$(id -u)" = "0" ]; then
  export HOME=/home/winebot
  export XDG_CACHE_HOME=/home/winebot/.cache
  mkdir -p /tmp/.X11-unix
  chmod 1777 /tmp/.X11-unix
  mkdir -p "$WINEPREFIX"
  prefix_owner="$(stat -c %u "$WINEPREFIX" 2>/dev/null || echo 0)"
  winebot_uid="$(id -u winebot)"
  if [ "$prefix_owner" != "$winebot_uid" ]; then
    chown -R winebot:winebot "$WINEPREFIX"
  fi
  mkdir -p "$XDG_CACHE_HOME"
  chown -R winebot:winebot "$XDG_CACHE_HOME"
  exec su -s /bin/bash -p winebot -c "/entrypoint.sh --run-as-user"
fi

if [ -z "${HOME:-}" ] || [ "$HOME" = "/root" ]; then
  export HOME=/home/winebot
fi
if [ -z "${XDG_CACHE_HOME:-}" ]; then
  export XDG_CACHE_HOME="$HOME/.cache"
fi
mkdir -p "$XDG_CACHE_HOME"

Xvfb "$DISPLAY" -screen 0 "$SCREEN" -ac +extension RANDR &
xvfb_pid=$!

sleep 1
openbox &

if [ "$INIT_PREFIX" = "1" ] && [ ! -f "$WINEPREFIX/system.reg" ]; then
  wineboot --init
fi

enable_vnc="0"
if [ "$MODE" = "interactive" ]; then
  enable_vnc="1"
fi
if [ "$ENABLE_VNC" = "1" ]; then
  enable_vnc="1"
fi

if [ "$enable_vnc" = "1" ]; then
  vnc_bind="${VNC_BIND:-0.0.0.0}"
  x11vnc_opts=( -display "$DISPLAY" -rfbport "$VNC_PORT" -forever -shared -noshm )
  if [ "$vnc_bind" = "127.0.0.1" ] || [ "$vnc_bind" = "localhost" ]; then
    x11vnc_opts+=( -localhost )
  fi
  if [ -n "${VNC_PASSWORD:-}" ]; then
    vnc_pass_file="/tmp/vncpass"
    x11vnc -storepasswd "$VNC_PASSWORD" "$vnc_pass_file"
    x11vnc "${x11vnc_opts[@]}" -rfbauth "$vnc_pass_file" &
  else
    if [ "$vnc_bind" != "127.0.0.1" ] && [ "$vnc_bind" != "localhost" ]; then
      vnc_bind="127.0.0.1"
      echo "VNC_PASSWORD is empty, binding VNC to localhost only"
    fi
    x11vnc_opts=( -display "$DISPLAY" -rfbport "$VNC_PORT" -forever -shared -noshm -localhost )
    x11vnc "${x11vnc_opts[@]}" -nopw &
  fi

  if [ -x /usr/share/novnc/utils/novnc_proxy ]; then
    /usr/share/novnc/utils/novnc_proxy --vnc "localhost:${VNC_PORT}" --listen "$NOVNC_PORT" &
  elif command -v websockify >/dev/null 2>&1; then
    websockify --web /usr/share/novnc "$NOVNC_PORT" "localhost:${VNC_PORT}" &
  fi

  novnc_host="${NOVNC_HOST:-localhost}"
  novnc_title="${NOVNC_TITLE:-}"
  if [ -z "$novnc_title" ] && [ -n "${APP_NAME:-}" ]; then
    novnc_title="$APP_NAME"
  fi
  if [ -z "$novnc_title" ] && [ -n "${APP_EXE:-}" ]; then
    app_base="$(basename "$APP_EXE")"
    novnc_title="${app_base%.*}"
  fi
  if [ -n "$novnc_title" ]; then
    novnc_title_encoded="$(NOVNC_TITLE="$novnc_title" python3 - <<'PY'
import os
import urllib.parse

print(urllib.parse.quote(os.environ["NOVNC_TITLE"]))
PY
)"
    echo "noVNC URL: http://${novnc_host}:${NOVNC_PORT}/vnc.html?host=${novnc_host}&port=${NOVNC_PORT}&title=${novnc_title_encoded}"
  else
    echo "noVNC URL: http://${novnc_host}:${NOVNC_PORT}/vnc.html?host=${novnc_host}&port=${NOVNC_PORT}"
  fi
fi

default_app="0"
use_wineconsole="0"
if [ -z "${APP_EXE:-}" ]; then
  APP_EXE="cmd.exe"
  default_app="1"
fi

if [ -n "${APP_EXE:-}" ]; then
  if [ -n "${WORKDIR:-}" ]; then
    cd "$WORKDIR"
  else
    cd "$(dirname "$APP_EXE")"
  fi
  if [ "$APP_EXE" = "cmd.exe" ] && [ -z "${APP_ARGS:-}" ] && [ "$default_app" = "1" ]; then
    APP_ARGS="/k echo WineBot ready"
    use_wineconsole="1"
  fi
  if [ -n "${APP_ARGS:-}" ]; then
    if [ "$use_wineconsole" = "1" ]; then
      wineconsole "$APP_EXE" $APP_ARGS &
    else
      wine "$APP_EXE" $APP_ARGS &
    fi
  else
    wine "$APP_EXE" &
  fi
  app_pid=$!
fi

if [ "${RUN_AUTOMATION:-0}" = "1" ] && [ -n "${AUTOMATION_CMD:-}" ]; then
  bash -lc "$AUTOMATION_CMD" &
  automation_pid=$!
fi

if [ -n "${app_pid:-}" ]; then
  wait "$app_pid"
else
  wait "$xvfb_pid"
fi
