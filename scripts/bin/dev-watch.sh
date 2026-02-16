#!/usr/bin/env bash
# scripts/bin/dev-watch.sh: Run pytest-watch inside the container for rapid feedback.

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

echo "--> Starting pytest-watch inside test-runner container..."
echo "--> Note: This requires the 'interactive' profile to be running."

docker compose -f compose/docker-compose.yml --profile interactive --profile test 
    run --rm --entrypoint "ptw --ext .py,.html,.js --ignore .git,.pytest_cache /work -- -v tests/test_api.py tests/e2e/test_ux_quality.py" test-runner
