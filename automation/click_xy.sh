#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: click_xy.sh X Y" >&2
  exit 1
fi

x_coord="$1"
y_coord="$2"

focused_window="$(xdotool getwindowfocus)"
if [ -n "$focused_window" ]; then
  xdotool windowactivate --sync "$focused_window"
fi

xdotool mousemove --sync "$x_coord" "$y_coord" click 1

