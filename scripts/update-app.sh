#!/usr/bin/env bash
set -euo pipefail

APP_PORT="${APP_PORT:-8080}"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-timptr-pattern}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon is unavailable. Start Docker and rerun this script." >&2
  exit 1
fi

cd "${REPO_DIR}"

COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME}" APP_PORT="${APP_PORT}" docker compose up -d --build
