#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../"; pwd)"
cd "$REPO_ROOT"

# Setup
mkdir -p artifacts
rm -rf artifacts/sessions
mkdir -p artifacts/sessions

echo "--> Running Unit Tests..."
PYTHONPATH=. python3 tests/test_recorder_unit.py

echo "--> Running Integration Test (using docker directly)..."

# Build image
echo "Building image..."
docker build -t winebot:test -f docker/Dockerfile .

# Run headless with recording
echo "Starting container with recording..."
# We run as user 1000:1000 (winebot) inside, map volumes
container_id=$(docker run -d \
    --name winebot-test \
    -e MODE=headless \
    -e WINEBOT_RECORD=1 \
    -e SCREEN=1920x1080x24 \
    -e DISPLAY=:99 \
    -v "$REPO_ROOT/artifacts:/artifacts" \
    -v "$REPO_ROOT/apps:/apps" \
    winebot:test \
    /entrypoint.sh cmd /c timeout 15)

trap "docker rm -f winebot-test >/dev/null 2>&1 || true" EXIT

echo "Container ID: $container_id"

# Give it a moment to start and stabilize
echo "Waiting for startup..."
sleep 5

echo "Injecting annotations..."
docker exec winebot-test scripts/annotate.sh --text "Hello World" --pos "100,100,200,50" --type overlay

sleep 5

echo "Stopping container..."
docker stop winebot-test

echo "Verifying artifacts..."
# Find the most recent session directory
SESSION_DIR=$(ls -td artifacts/sessions/* 2>/dev/null | head -1)

if [ -z "$SESSION_DIR" ]; then
    echo "FAIL: No session directory found in artifacts/sessions/"
    ls -R artifacts/
    exit 1
fi

echo "Session Dir: $SESSION_DIR"

check_file() {
    if [ ! -f "$1" ]; then
        echo "FAIL: File missing: $1"
        exit 1
    fi
}

VIDEO_FILE="$SESSION_DIR/video_001_part001.mkv"
check_file "$VIDEO_FILE"
check_file "$SESSION_DIR/events_001.jsonl"
check_file "$SESSION_DIR/session.json"

# Check video properties
echo "Checking video stream..."
ffprobe -v error -show_entries stream=width,height,codec_name -of default=noprint_wrappers=1 "$VIDEO_FILE"

echo "Checking global metadata..."
if ffprobe -v error -show_entries format_tags=WINEBOT_SESSION_ID,encoder -of default=noprint_wrappers=1 "$VIDEO_FILE" | grep -q "WINEBOT_SESSION_ID="; then
    echo "PASS: Global metadata found"
else
    echo "FAIL: Global metadata missing"
    ffprobe -v error -show_entries format_tags -of default=noprint_wrappers=1 "$VIDEO_FILE"
    exit 1
fi

# Check events log
if grep -q "lifecycle" "$SESSION_DIR/events_001.jsonl" && grep -q "Hello World" "$SESSION_DIR/events_001.jsonl"; then
    echo "PASS: Events log looks good"
else
    echo "FAIL: Events log missing expected entries"
    head "$SESSION_DIR/events_001.jsonl"
    exit 1
fi

echo "ALL RECORDING TESTS PASSED"
