#!/usr/bin/env bash
set -euo pipefail

docker compose -f compose/docker-compose.yml --profile interactive up --build

