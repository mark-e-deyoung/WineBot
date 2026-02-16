#!/usr/bin/env bash
# Host helper to run containerized unit tests
set -e
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.."; pwd)"
docker compose -f "$repo_root/compose/docker-compose.yml" --profile test --profile interactive run --rm test-runner /scripts/ci/test.sh
