#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/run-app.sh <app-exe> [options]

Run a Windows app from either /apps or the Wine prefix.

Options:
  --mode headless|interactive  Run mode (default: headless).
  --args "..."                 Arguments for the app (optional).
  --workdir PATH               Working directory inside the container (optional).
  --winarch win32              Use a 32-bit Wine prefix for this run.
  --automation "CMD"           Run an automation command after launch.
  --winedbg                    Launch under winedbg.
  --winedbg-mode gdb|default   Set winedbg mode (default: gdb).
  --winedbg-port PORT          Set gdb proxy port (default: 2345).
  --winedbg-no-start           Do not auto-start gdb (default).
  --winedbg-command "CMD"      Run a winedbg command (default mode only).
  --winedbg-script PATH        Run winedbg commands from a file (default mode only).
  --detach, -d                 Run in the background.
  --no-build                   Skip building the image.
  -h, --help                   Show this help.

App path can be:
  - /apps/MyApp.exe (maps from ./apps on the host)
  - /wineprefix/drive_c/Program Files/MyApp/MyApp.exe
  - C:\\Program Files\\MyApp\\MyApp.exe (quote/escape backslashes)
EOF
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

app_exe="$1"
shift

mode="headless"
app_args=""
workdir=""
winearch=""
automation_cmd=""
enable_winedbg="0"
winedbg_mode=""
winedbg_port=""
winedbg_no_start=""
winedbg_command=""
winedbg_script=""
build="1"
detach="0"

while [ $# -gt 0 ]; do
  case "$1" in
    --mode)
      mode="${2:-}"
      shift
      ;;
    --headless)
      mode="headless"
      ;;
    --interactive)
      mode="interactive"
      ;;
    --args)
      app_args="${2:-}"
      shift
      ;;
    --workdir)
      workdir="${2:-}"
      shift
      ;;
    --winarch)
      winearch="${2:-}"
      shift
      ;;
    --automation)
      automation_cmd="${2:-}"
      shift
      ;;
    --winedbg)
      enable_winedbg="1"
      ;;
    --winedbg-mode)
      enable_winedbg="1"
      winedbg_mode="${2:-}"
      shift
      ;;
    --winedbg-port)
      enable_winedbg="1"
      winedbg_port="${2:-}"
      shift
      ;;
    --winedbg-no-start)
      enable_winedbg="1"
      winedbg_no_start="1"
      ;;
    --winedbg-command)
      enable_winedbg="1"
      winedbg_command="${2:-}"
      shift
      ;;
    --winedbg-script)
      enable_winedbg="1"
      winedbg_script="${2:-}"
      shift
      ;;
    --detach|-d)
      detach="1"
      ;;
    --no-build)
      build="0"
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

if [ "$mode" != "headless" ] && [ "$mode" != "interactive" ]; then
  echo "Invalid mode: $mode (expected headless or interactive)" >&2
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)"

resolve_app_exe() {
  local input="$1"
  local host_path=""
  local container_path=""

  if [[ "$input" == /apps/* ]]; then
    container_path="$input"
    host_path="$repo_root/apps/${input#/apps/}"
  elif [[ "$input" == "$repo_root/apps/"* ]]; then
    host_path="$input"
    container_path="/apps/${input#$repo_root/apps/}"
  elif [[ "$input" == ./apps/* ]]; then
    host_path="$repo_root/${input#./}"
    container_path="/${input#./}"
  elif [[ "$input" == apps/* ]]; then
    host_path="$repo_root/$input"
    container_path="/$input"
  elif [[ -f "$repo_root/apps/$input" ]]; then
    host_path="$repo_root/apps/$input"
    container_path="/apps/$input"
  else
    container_path="$input"
  fi

  if [ -n "$host_path" ] && [ ! -f "$host_path" ]; then
    echo "App executable not found: $host_path" >&2
    exit 1
  fi

  printf '%s\n' "$container_path"
}

container_app_exe="$(resolve_app_exe "$app_exe")"

if docker compose version >/dev/null 2>&1; then
  compose_cmd=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  compose_cmd=(docker-compose)
else
  echo "Docker Compose not found." >&2
  exit 1
fi

compose_file="$repo_root/compose/docker-compose.yml"

if [ "$mode" = "interactive" ]; then
  profile="interactive"
  service="winebot-interactive"
else
  profile="headless"
  service="winebot"
fi

env_vars=(APP_EXE="$container_app_exe")
if [ -n "$app_args" ]; then
  env_vars+=(APP_ARGS="$app_args")
fi
if [ -n "$workdir" ]; then
  env_vars+=(WORKDIR="$workdir")
fi
if [ -n "$winearch" ]; then
  env_vars+=(WINEARCH="$winearch")
fi
if [ -n "$automation_cmd" ]; then
  env_vars+=(RUN_AUTOMATION="1" AUTOMATION_CMD="$automation_cmd")
fi
if [ "$enable_winedbg" = "1" ]; then
  env_vars+=(ENABLE_WINEDBG="1")
fi
if [ -n "$winedbg_mode" ]; then
  env_vars+=(WINEDBG_MODE="$winedbg_mode")
fi
if [ -n "$winedbg_port" ]; then
  env_vars+=(WINEDBG_PORT="$winedbg_port")
fi
if [ -n "$winedbg_no_start" ]; then
  env_vars+=(WINEDBG_NO_START="$winedbg_no_start")
fi
if [ -n "$winedbg_command" ]; then
  env_vars+=(WINEDBG_COMMAND="$winedbg_command")
fi
if [ -n "$winedbg_script" ]; then
  env_vars+=(WINEDBG_SCRIPT="$winedbg_script")
fi

compose_args=("${compose_cmd[@]}" -f "$compose_file" --profile "$profile" up --force-recreate)
if [ "$build" = "1" ]; then
  compose_args+=(--build)
fi
if [ "$detach" = "1" ]; then
  compose_args+=(-d)
fi
compose_args+=("$service")

env "${env_vars[@]}" "${compose_args[@]}"
