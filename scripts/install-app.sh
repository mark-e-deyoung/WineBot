#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/install-app.sh <installer> [options]

Install a Windows app into the persistent Wine prefix.

Options:
  --args "..."         Arguments for the installer (optional).
  --workdir PATH       Working directory inside the container (optional).
  --winarch win32      Use a 32-bit Wine prefix for this install.
  --headless           Run without VNC/noVNC (for silent installers).
  --interactive        Run with VNC/noVNC (default).
  --no-build           Skip building the image.
  -h, --help           Show this help.

Installer path can be:
  - /apps/Installer.exe
  - apps/Installer.exe
  - ./apps/Installer.exe
  - A bare filename that exists under ./apps
EOF
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

installer="$1"
shift

mode="interactive"
app_args=""
workdir=""
winearch=""
build="1"

while [ $# -gt 0 ]; do
  case "$1" in
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
    --headless)
      mode="headless"
      ;;
    --interactive)
      mode="interactive"
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

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)"

resolve_installer() {
  local input="$1"
  local host_path=""
  local container_path=""

  if [[ "$input" == /apps/* ]]; then
    container_path="$input"
    host_path="$repo_root/apps/${input#/apps/}"
  elif [[ "$input" == "$repo_root/apps/"* ]]; then
    host_path="$input"
    container_path="/apps/${input#"$repo_root"/apps/}"
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
    echo "Installer not found under $repo_root/apps." >&2
    exit 1
  fi

  if [ ! -f "$host_path" ]; then
    echo "Installer not found: $host_path" >&2
    exit 1
  fi

  printf '%s' "$container_path"
}

container_installer="$(resolve_installer "$installer")"

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

env_vars=(APP_EXE="$container_installer")
if [ -n "$app_args" ]; then
  env_vars+=(APP_ARGS="$app_args")
fi
if [ -n "$workdir" ]; then
  env_vars+=(WORKDIR="$workdir")
fi
if [ -n "$winearch" ]; then
  env_vars+=(WINEARCH="$winearch")
fi

compose_args=("${compose_cmd[@]}" -f "$compose_file" --profile "$profile" up --force-recreate)
if [ "$build" = "1" ]; then
  compose_args+=(--build)
fi
compose_args+=("$service")

env "${env_vars[@]}" "${compose_args[@]}"
