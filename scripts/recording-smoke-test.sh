#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-${1:-http://localhost:8000}}"
API_TOKEN="${API_TOKEN:-}"
SESSION_ROOT="${SESSION_ROOT:-/artifacts/sessions}"
API_WAIT_SECONDS="${API_WAIT_SECONDS:-60}"

PERF_START_MS="${PERF_START_MS:-2000}"
PERF_PAUSE_MS="${PERF_PAUSE_MS:-2500}"
PERF_RESUME_MS="${PERF_RESUME_MS:-2500}"
MARKER_ALIGNMENT_TOLERANCE_MS="${MARKER_ALIGNMENT_TOLERANCE_MS:-2500}"
PERF_STOP_MS="${PERF_STOP_MS:-8000}"

auth_args=()
if [ -n "$API_TOKEN" ]; then
  auth_args=(-H "X-API-Key: $API_TOKEN")
fi

now_ms() {
  python3 - <<'PY'
import time
print(int(time.time() * 1000))
PY
}

json_field_into() {
  local __var="$1"
  local key="$2"
  local raw="$3"
  local value
  if ! value="$(RAW="$raw" python3 - "$key" <<'PY'
import json
import os
import sys

raw = os.environ.get("RAW", "")
if not raw.strip():
    sys.stderr.write("json_field: empty input\n")
    sys.exit(1)

try:
    data = json.loads(raw)
except json.JSONDecodeError as exc:
    sys.stderr.write(f"json_field: invalid JSON: {exc}\n")
    sys.exit(1)

key = sys.argv[1]
value = data
for part in key.split("."):
    if isinstance(value, dict):
        value = value.get(part)
    else:
        value = None
        break
if isinstance(value, bool):
    print("true" if value else "false")
elif value is None:
    print("")
else:
    print(value)
PY
  )"; then
    echo "Failed to read JSON field '$key'." >&2
    exit 1
  fi
  printf -v "$__var" '%s' "$value"
}

api_get_into() {
  local __var="$1"
  local path="$2"
  local resp
  if ! resp="$(curl -s --fail "${auth_args[@]}" "${BASE_URL}${path}")"; then
    echo "API GET failed: ${BASE_URL}${path}" >&2
    exit 1
  fi
  if [ -z "$resp" ]; then
    echo "API GET empty response: ${BASE_URL}${path}" >&2
    exit 1
  fi
  printf -v "$__var" '%s' "$resp"
}

api_post_into() {
  local __var="$1"
  local path="$2"
  local resp
  if ! resp="$(curl -s --fail -X POST "${auth_args[@]}" "${BASE_URL}${path}")"; then
    echo "API POST failed: ${BASE_URL}${path}" >&2
    exit 1
  fi
  if [ -z "$resp" ]; then
    echo "API POST empty response: ${BASE_URL}${path}" >&2
    exit 1
  fi
  printf -v "$__var" '%s' "$resp"
}

api_post_json_into() {
  local __var="$1"
  local endpoint="$2"
  local body="$3"
  local resp
  if ! resp="$(curl -s --fail -X POST "${auth_args[@]}" -H 'Content-Type: application/json' \
    -d "$body" "${BASE_URL}${endpoint}")"; then
    echo "API POST failed: ${BASE_URL}${endpoint}" >&2
    exit 1
  fi
  if [ -z "$resp" ]; then
    echo "API POST empty response: ${BASE_URL}${endpoint}" >&2
    exit 1
  fi
  printf -v "$__var" '%s' "$resp"
}

wait_for_api() {
  local timeout="${1:-60}"
  local waited=0
  while [ "$waited" -lt "$timeout" ]; do
    if curl -s --fail "${auth_args[@]}" "${BASE_URL}/health" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
    waited=$((waited + 1))
  done
  return 1
}

await_state() {
  local expected="$1"
  local timeout="${2:-10}"
  local _
  for _ in $(seq 1 "$((timeout * 10))"); do
    local health
    local state
    api_get_into health "/health/recording"
    json_field_into state "state" "$health"
    if [ "$state" = "$expected" ]; then
      return 0
    fi
    sleep 0.1
  done
  echo "Expected state '$expected' but last state was '$state'." >&2
  return 1
}

assert_perf() {
  local action="$1"
  local elapsed="$2"
  local threshold="$3"
  if [ "$elapsed" -gt "$threshold" ]; then
    echo "Recording ${action} too slow: ${elapsed}ms > ${threshold}ms" >&2
    return 1
  fi
}

wait_for_file() {
  local path="$1"
  local timeout="${2:-10}"
  local _
  for _ in $(seq 1 "$((timeout * 10))"); do
    if [ -s "$path" ]; then
      return 0
    fi
    sleep 0.1
  done
  echo "Expected file not found: $path" >&2
  return 1
}

annotate_marker() {
  local session_dir="$1"
  local marker="$2"
  if [ -x /scripts/annotate.sh ]; then
    /scripts/annotate.sh --session-dir "$session_dir" --text "$marker" --type subtitle --source recording-smoke-test
  else
    python3 -m automation.recorder annotate --session-dir "$session_dir" --text "$marker" --kind subtitle --source recording-smoke-test
  fi
}

validate_segment_artifacts() {
  local session_dir="$1"
  local segment="$2"
  local marker_csv="$3"
  local require_pause_resume="$4"

  local suffix
  suffix="$(printf '%03d' "$segment")"
  local video_file="${session_dir}/video_${suffix}.mkv"
  local events_file="${session_dir}/events_${suffix}.jsonl"
  local vtt_file="${session_dir}/events_${suffix}.vtt"
  local ass_file="${session_dir}/events_${suffix}.ass"
  local segment_manifest="${session_dir}/segment_${suffix}.json"
  local session_manifest="${session_dir}/session.json"
  local parts_file="${session_dir}/parts_${suffix}.txt"

  wait_for_file "$video_file" 20
  wait_for_file "$events_file" 20
  wait_for_file "$vtt_file" 20
  wait_for_file "$ass_file" 20
  wait_for_file "$segment_manifest" 20
  wait_for_file "$session_manifest" 20

  RECORDING_SMOKE_VIDEO="$video_file" \
  RECORDING_SMOKE_EVENTS="$events_file" \
  RECORDING_SMOKE_VTT="$vtt_file" \
  RECORDING_SMOKE_ASS="$ass_file" \
  RECORDING_SMOKE_SEGMENT_MANIFEST="$segment_manifest" \
  RECORDING_SMOKE_SESSION_MANIFEST="$session_manifest" \
  RECORDING_SMOKE_PARTS_FILE="$parts_file" \
  RECORDING_SMOKE_SEGMENT="$segment" \
  RECORDING_SMOKE_MARKERS="$marker_csv" \
  RECORDING_SMOKE_MARKER_TOLERANCE_MS="$MARKER_ALIGNMENT_TOLERANCE_MS" \
  RECORDING_SMOKE_REQUIRE_PAUSE="$require_pause_resume" \
  python3 - <<'PY'
import json
import os
import subprocess
import sys
from pathlib import Path

video = Path(os.environ["RECORDING_SMOKE_VIDEO"])
events_path = Path(os.environ["RECORDING_SMOKE_EVENTS"])
vtt_path = Path(os.environ["RECORDING_SMOKE_VTT"])
ass_path = Path(os.environ["RECORDING_SMOKE_ASS"])
segment_manifest_path = Path(os.environ["RECORDING_SMOKE_SEGMENT_MANIFEST"])
session_manifest_path = Path(os.environ["RECORDING_SMOKE_SESSION_MANIFEST"])
parts_file_path = Path(os.environ["RECORDING_SMOKE_PARTS_FILE"])
segment = int(os.environ["RECORDING_SMOKE_SEGMENT"])
markers = [m for m in os.environ.get("RECORDING_SMOKE_MARKERS", "").split(",") if m]
marker_tolerance_ms = int(os.environ.get("RECORDING_SMOKE_MARKER_TOLERANCE_MS", "2500"))
require_pause = os.environ.get("RECORDING_SMOKE_REQUIRE_PAUSE", "0") == "1"

def fail(msg: str):
    print(f"recording-artifact-validate: {msg}", file=sys.stderr)
    sys.exit(1)

def parse_ms(ts: str) -> int:
    # HH:MM:SS.mmm
    h, m, s = ts.split(":")
    sec, ms = s.split(".")
    return ((int(h) * 60 + int(m)) * 60 + int(sec)) * 1000 + int(ms)

for p in (video, events_path, vtt_path, ass_path, segment_manifest_path, session_manifest_path):
    if not p.exists() or p.stat().st_size == 0:
        fail(f"missing/empty artifact: {p}")

try:
    session_manifest = json.loads(session_manifest_path.read_text())
    segment_manifest = json.loads(segment_manifest_path.read_text())
except Exception as exc:
    fail(f"failed to parse manifest JSON: {exc}")

for key in ("session_id", "start_time_epoch", "resolution", "fps"):
    if key not in session_manifest:
        fail(f"session.json missing key {key}")

for key in ("session_id", "segment", "start_time_epoch", "resolution", "fps"):
    if key not in segment_manifest:
        fail(f"segment manifest missing key {key}")

if int(segment_manifest["segment"]) != segment:
    fail(f"segment manifest index mismatch: expected {segment} got {segment_manifest['segment']}")
if str(segment_manifest["session_id"]) != str(session_manifest["session_id"]):
    fail("segment/session manifest session_id mismatch")

events = []
for lineno, line in enumerate(events_path.read_text().splitlines(), start=1):
    if not line.strip():
        continue
    try:
        evt = json.loads(line)
    except json.JSONDecodeError as exc:
        fail(f"invalid JSON at {events_path}:{lineno}: {exc}")
    for req in ("session_id", "t_rel_ms", "t_epoch_ms", "kind", "message"):
        if req not in evt:
            fail(f"event missing required field '{req}' at line {lineno}")
    events.append(evt)

if not events:
    fail("events file has no events")

prev_rel = -1
for evt in events:
    rel = int(evt["t_rel_ms"])
    if rel < 0:
        fail("negative t_rel_ms in events")
    if rel < prev_rel:
        fail("event t_rel_ms is not monotonic")
    prev_rel = rel

kinds = {e.get("kind") for e in events}
required_kinds = {"lifecycle", "recorder_start", "recorder_stop"}
missing = required_kinds - kinds
if missing:
    fail(f"missing required event kinds: {sorted(missing)}")

if require_pause:
    for k in ("recorder_pause", "recorder_resume"):
        if k not in kinds:
            fail(f"missing pause/resume event kind: {k}")
    if not parts_file_path.exists() or parts_file_path.stat().st_size == 0:
        fail(f"missing/empty parts list: {parts_file_path}")
    part_lines = [ln.strip() for ln in parts_file_path.read_text().splitlines() if ln.strip()]
    if len(part_lines) < 2:
        fail("expected >=2 parts for pause/resume segment")
    pause_rel = min(int(e["t_rel_ms"]) for e in events if e.get("kind") == "recorder_pause")
    resume_rel = min(int(e["t_rel_ms"]) for e in events if e.get("kind") == "recorder_resume")
    if resume_rel < pause_rel:
        fail("recorder_resume occurs before recorder_pause in adjusted timeline")

vtt_lines = vtt_path.read_text().splitlines()
if not vtt_lines or vtt_lines[0].strip() != "WEBVTT":
    fail("VTT header missing")

cue_starts = []
cue_texts = []
i = 0
while i < len(vtt_lines):
    line = vtt_lines[i].strip()
    if "-->" in line:
        start = line.split("-->")[0].strip()
        cue_starts.append(parse_ms(start))
        text_line = ""
        j = i + 1
        while j < len(vtt_lines) and vtt_lines[j].strip():
            text_line += (" " if text_line else "") + vtt_lines[j].strip()
            j += 1
        cue_texts.append(text_line)
    i += 1

if len(cue_starts) < len(events):
    fail("VTT cue count is lower than events count")
if cue_starts != sorted(cue_starts):
    fail("VTT cue starts are not monotonic")

ass_text = ass_path.read_text()
if "[Events]" not in ass_text or "Dialogue:" not in ass_text:
    fail("ASS file missing dialogue events")

def ffprobe_json(path: Path) -> dict:
    cmd = [
        "ffprobe", "-v", "error", "-of", "json",
        "-show_format", "-show_streams", str(path),
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        fail(f"ffprobe failed for {path}: {proc.stderr.strip()}")
    try:
        return json.loads(proc.stdout)
    except Exception as exc:
        fail(f"invalid ffprobe JSON for {path}: {exc}")

probe = ffprobe_json(video)
streams = probe.get("streams", [])
format_info = probe.get("format", {})
video_streams = [s for s in streams if s.get("codec_type") == "video"]
subtitle_streams = [s for s in streams if s.get("codec_type") == "subtitle"]
if not video_streams:
    fail("video stream missing from MKV")
if len(subtitle_streams) < 2:
    fail("expected at least two subtitle streams (ASS+VTT)")

duration_s = float(format_info.get("duration", 0.0) or 0.0)
if duration_s <= 0.5:
    fail(f"video duration too short: {duration_s}s")
duration_ms = int(duration_s * 1000)

tags = format_info.get("tags", {})
if tags.get("WINEBOT_SESSION_ID") != str(session_manifest["session_id"]):
    fail("WINEBOT_SESSION_ID metadata mismatch")

max_event_rel = max(int(e["t_rel_ms"]) for e in events)
if max_event_rel > duration_ms + 5000:
    fail(f"events extend too far past video duration ({max_event_rel}ms vs {duration_ms}ms)")
if cue_starts and cue_starts[-1] > duration_ms + 5000:
    fail("VTT cues extend too far past video duration")

for marker in markers:
    event_times = [int(e["t_rel_ms"]) for e in events if marker in str(e.get("message", ""))]
    if not event_times:
        fail(f"marker missing from events: {marker}")
    cue_times = [cue_starts[idx] for idx, text in enumerate(cue_texts) if marker in text]
    if not cue_times:
        fail(f"marker missing from VTT: {marker}")
    if marker not in ass_text:
        fail(f"marker missing from ASS: {marker}")
    if abs(cue_times[0] - event_times[0]) > marker_tolerance_ms:
        fail(f"marker timing misalignment for {marker}: event={event_times[0]} cue={cue_times[0]}")

print(f"recording-artifact-validate: OK segment={segment} duration_ms={duration_ms} events={len(events)} cues={len(cue_starts)}")
PY
}

mkdir -p "$SESSION_ROOT"

echo "Recording API smoke test (base: ${BASE_URL})..."
if ! wait_for_api "$API_WAIT_SECONDS"; then
  echo "API not ready at ${BASE_URL} after ${API_WAIT_SECONDS}s" >&2
  exit 1
fi

# Set dynamic variables explicitly; these are later populated via printf -v helpers.
enabled=""
start_resp=""
start_status=""
pause_resp=""
pause_status=""
id_pause_resp=""
id_pause_status=""
resume_resp=""
resume_status=""
id_resume_resp=""
id_resume_status=""
stop_resp=""
stop_status=""
id_stop_resp=""
id_stop_status=""
start2_resp=""

api_get_into health "/health/recording"
json_field_into enabled "enabled" "$health"
if [ "$enabled" != "true" ]; then
  echo "Recording API disabled in /health/recording." >&2
  exit 1
fi

# Ensure clean state
api_post_into _stop_resp "/recording/stop" >/dev/null 2>&1 || true
await_state "idle" 10

start_body="{\"session_root\":\"$SESSION_ROOT\",\"new_session\":true}"
start_ms="$(now_ms)"
api_post_json_into start_resp "/recording/start" "$start_body"
start_elapsed="$(( $(now_ms) - start_ms ))"
assert_perf "start" "$start_elapsed" "$PERF_START_MS"

json_field_into start_status "status" "$start_resp"
json_field_into session_dir "session_dir" "$start_resp"
json_field_into segment "segment" "$start_resp"
if [ "$start_status" != "started" ] || [ -z "$session_dir" ] || [ -z "$segment" ]; then
  echo "Start response invalid: $start_resp" >&2
  exit 1
fi

await_state "recording" 10
marker1="recording-smoke-before-pause-${segment}-$(date +%s)"
annotate_marker "$session_dir" "$marker1"
sleep 0.3

pause_ms="$(now_ms)"
api_post_into pause_resp "/recording/pause"
pause_elapsed="$(( $(now_ms) - pause_ms ))"
assert_perf "pause" "$pause_elapsed" "$PERF_PAUSE_MS"
json_field_into pause_status "status" "$pause_resp"
if [ "$pause_status" != "paused" ]; then
  echo "Pause response invalid: $pause_resp" >&2
  exit 1
fi
await_state "paused" 10

api_post_into id_pause_resp "/recording/pause"
json_field_into id_pause_status "status" "$id_pause_resp"
if [ "$id_pause_status" != "already_paused" ]; then
  echo "Expected already_paused, got: $id_pause_resp" >&2
  exit 1
fi

resume_ms="$(now_ms)"
api_post_into resume_resp "/recording/resume"
resume_elapsed="$(( $(now_ms) - resume_ms ))"
assert_perf "resume" "$resume_elapsed" "$PERF_RESUME_MS"
json_field_into resume_status "status" "$resume_resp"
if [ "$resume_status" != "resumed" ]; then
  echo "Resume response invalid: $resume_resp" >&2
  exit 1
fi
await_state "recording" 10
marker2="recording-smoke-after-resume-${segment}-$(date +%s)"
annotate_marker "$session_dir" "$marker2"
sleep 0.3

api_post_into id_resume_resp "/recording/resume"
json_field_into id_resume_status "status" "$id_resume_resp"
if [ "$id_resume_status" != "already_recording" ]; then
  echo "Expected already_recording, got: $id_resume_resp" >&2
  exit 1
fi

stop_ms="$(now_ms)"
api_post_into stop_resp "/recording/stop"
stop_elapsed="$(( $(now_ms) - stop_ms ))"
assert_perf "stop" "$stop_elapsed" "$PERF_STOP_MS"
json_field_into stop_status "status" "$stop_resp"
if [ "$stop_status" != "stopped" ]; then
  echo "Stop response invalid: $stop_resp" >&2
  exit 1
fi
await_state "idle" 10

segment_suffix="$(printf '%03d' "$segment")"
final_video="${session_dir}/video_${segment_suffix}.mkv"
wait_for_file "$final_video" 10
validate_segment_artifacts "$session_dir" "$segment" "${marker1},${marker2}" "1"

api_post_into id_stop_resp "/recording/stop"
json_field_into id_stop_status "status" "$id_stop_resp"
if [ "$id_stop_status" != "already_stopped" ]; then
  echo "Expected already_stopped, got: $id_stop_resp" >&2
  exit 1
fi

start_body="{\"session_root\":\"$SESSION_ROOT\",\"new_session\":false}"
api_post_json_into start2_resp "/recording/start" "$start_body"
json_field_into segment2 "segment" "$start2_resp"
if [ -z "$segment2" ] || [ "$segment2" -le "$segment" ]; then
  echo "Expected segment increment, got: $start2_resp" >&2
  exit 1
fi
await_state "recording" 10
marker3="recording-smoke-segment2-${segment2}-$(date +%s)"
annotate_marker "$session_dir" "$marker3"
sleep 0.3
api_post_into _stop_resp2 "/recording/stop" >/dev/null
await_state "idle" 10
segment2_suffix="$(printf '%03d' "$segment2")"
final_video2="${session_dir}/video_${segment2_suffix}.mkv"
wait_for_file "$final_video2" 10
validate_segment_artifacts "$session_dir" "$segment2" "${marker3}" "0"

echo "Recording API smoke test OK."
