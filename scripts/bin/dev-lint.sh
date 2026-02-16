#!/usr/bin/env bash
# Host helper to run containerized linting
set -e
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.."; pwd)"
docker compose -f "$repo_root/compose/docker-compose.yml" --profile lint run --rm lint-runner
