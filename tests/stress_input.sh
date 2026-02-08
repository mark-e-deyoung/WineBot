#!/usr/bin/env bash
set -e

echo "Starting Input Stress Test..."

ITERATIONS=5
CONCURRENCY=0

usage() {
    echo "Usage: $0 [--iterations N]"
}

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --iterations) ITERATIONS="$2"; shift ;;
        *) usage; exit 1 ;;
    esac
    shift
done

# Ensure we have the tools
if [ ! -f "scripts/diagnose-input-trace.sh" ]; then
    echo "Error: scripts/diagnose-input-trace.sh not found."
    exit 1
fi

# Background load generator
start_load() {
    echo "Starting background load (simulated)..."
    # Just a simple loop consuming some CPU/IO
    ( while true; do find /wineprefix -name "*.reg" -exec cat {} \; > /dev/null 2>&1; sleep 0.5; done ) &
    LOAD_PID=$!
}

stop_load() {
    if [ -n "$LOAD_PID" ]; then
        echo "Stopping background load..."
        kill "$LOAD_PID" || true
        wait "$LOAD_PID" || true
    fi
}

trap stop_load EXIT

start_load

SUCCESS_COUNT=0
FAIL_COUNT=0

for i in $(seq 1 $ITERATIONS); do
    echo "=== Iteration $i / $ITERATIONS ==="
    
    # Run the diagnostic trace
    if ./scripts/diagnose-input-trace.sh --no-windows --no-x11 --no-x11-core; then
        echo "Iteration $i: PASS"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo "Iteration $i: FAIL"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    # Add random delay
    sleep $(( RANDOM % 3 ))
done

echo "--- Stress Test Complete ---"
echo "Pass: $SUCCESS_COUNT"
echo "Fail: $FAIL_COUNT"

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
fi
