#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/openbox-menu-test.sh [options]

Validate Openbox menu commands for WineBot.

Options:
  --menu PATH     Path to openbox menu.xml (default: /etc/xdg/openbox/menu.xml or docker/openbox/menu.xml)
  --run-x11       Run non-interactive X11 checks (xdpyinfo, xprop -root, xwininfo -root)
  --run-wine      Run a basic wine version check
  -h, --help      Show this help
EOF
}

menu_path=""
run_x11="0"
run_wine="0"

while [ $# -gt 0 ]; do
  case "$1" in
    --menu)
      menu_path="${2:-}"
      shift 2
      ;;
    --run-x11)
      run_x11="1"
      shift
      ;;
    --run-wine)
      run_wine="1"
      shift
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

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)"
if [ -z "$menu_path" ]; then
  if [ -f /etc/xdg/openbox/menu.xml ]; then
    menu_path="/etc/xdg/openbox/menu.xml"
  else
    menu_path="$repo_root/docker/openbox/menu.xml"
  fi
fi

if [ ! -f "$menu_path" ]; then
  echo "Openbox menu not found at $menu_path" >&2
  exit 1
fi

parse_cmd() {
  python3 - "$1" <<'PY'
import shlex
import sys

cmd = sys.argv[1]
try:
    parts = shlex.split(cmd)
except ValueError:
    parts = []
print(parts[0] if parts else "")
PY
}

missing=0
count=0

while IFS=$'\t' read -r label cmd; do
  if [ -z "${cmd:-}" ]; then
    continue
  fi
  count=$((count + 1))
  first="$(parse_cmd "$cmd")"
  if [ -z "$first" ]; then
    echo "Could not parse command for menu item: $label -> $cmd" >&2
    missing=$((missing + 1))
    continue
  fi
  if [[ "$first" = /* ]]; then
    if [ ! -x "$first" ]; then
      echo "Missing executable for menu item: $label -> $cmd" >&2
      missing=$((missing + 1))
    fi
    continue
  fi
  if ! command -v "$first" >/dev/null 2>&1; then
    echo "Command not found for menu item: $label -> $cmd" >&2
    missing=$((missing + 1))
  fi
done < <(python3 - "$menu_path" <<'PY'
import sys
import xml.etree.ElementTree as ET

path = sys.argv[1]
tree = ET.parse(path)
root = tree.getroot()
ns = ""
if root.tag.startswith("{"):
    ns = root.tag.split("}")[0].strip("{")

def q(tag):
    return f"{{{ns}}}{tag}" if ns else tag

for item in root.iter(q("item")):
    label = item.get("label", "").strip()
    cmd = item.findtext(f".//{q('command')}")
    if cmd:
        cmd = cmd.strip()
    else:
        cmd = ""
    print(f"{label}\t{cmd}")
PY
)

if [ "$run_x11" = "1" ]; then
  export DISPLAY="${DISPLAY:-:99}"
  timeout 5 xdpyinfo >/dev/null
  timeout 5 xprop -root >/dev/null
  timeout 5 xwininfo -root >/dev/null
fi

if [ "$run_wine" = "1" ]; then
  wine --version >/dev/null
fi

if [ "$missing" -ne 0 ]; then
  echo "Openbox menu validation failed: $missing missing command(s) out of $count." >&2
  exit 1
fi

echo "Openbox menu validation OK ($count commands)."
