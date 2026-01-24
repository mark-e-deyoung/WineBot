#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/list-installed-apps.sh [options]

List Windows executables under Program Files in the persistent Wine prefix.

Options:
  --pattern "TEXT"   Filter results by substring (case-insensitive).
  --no-build         Skip building the image.
  -h, --help         Show this help.
EOF
}

pattern=""
build="1"

while [ $# -gt 0 ]; do
  case "$1" in
    --pattern)
      pattern="${2:-}"
      shift
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

if docker compose version >/dev/null 2>&1; then
  compose_cmd=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  compose_cmd=(docker-compose)
else
  echo "Docker Compose not found." >&2
  exit 1
fi

compose_file="$repo_root/compose/docker-compose.yml"

find_cmd='find "/wineprefix/drive_c/Program Files" "/wineprefix/drive_c/Program Files (x86)" -type f -iname "*.exe" 2>/dev/null | sort'

if [ -n "$pattern" ]; then
  pattern_escaped="$(printf '%q' "$pattern")"
  find_cmd="$find_cmd | grep -i -- $pattern_escaped"
fi

compose_args=("${compose_cmd[@]}" -f "$compose_file" --profile headless run --rm --entrypoint bash)
if [ "$build" = "1" ]; then
  compose_args+=(--build)
fi
compose_args+=(winebot -lc "$find_cmd")

"${compose_args[@]}"
