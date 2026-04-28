#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration (override via environment variables)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${REPO_DIR:-$(cd -- "${SCRIPT_DIR}/.." && pwd)}"
IMAGE_NAME="${IMAGE_NAME:-timptr-pattern-web:latest}"
CONTAINER_NAME="${CONTAINER_NAME:-timptr-pattern-web}"
HOST_PORT="${HOST_PORT:-8080}"
CONTAINER_PORT="${CONTAINER_PORT:-80}"
DATA_VOLUME="${DATA_VOLUME:-${CONTAINER_NAME}-data}"
CONFIG_HOST="${CONFIG_HOST:-}"
CONFIG_CONTAINER="${CONFIG_CONTAINER:-/etc/app/config}"
BUILD_ID="${BUILD_ID:-}"

# Collect APP_ENV_* variables to pass as -e flags to docker run
declare -a ENV_FLAGS=()
while IFS='=' read -r name value; do
  ENV_FLAGS+=(-e "${name}=${value}")
done < <(env | grep '^APP_ENV_' || true)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log() { echo ">>> $*"; }

# ---------------------------------------------------------------------------
# 1. Update repository
# ---------------------------------------------------------------------------
log "Updating repository in ${REPO_DIR} ..."
cd "${REPO_DIR}"
git fetch origin main
git checkout main
git pull --ff-only origin main

# ---------------------------------------------------------------------------
# 2. Determine BUILD_ID
# ---------------------------------------------------------------------------
if [[ -z "${BUILD_ID}" ]]; then
  BUILD_ID="$(git rev-parse --short HEAD)"
fi
log "Build ID: ${BUILD_ID}"

# ---------------------------------------------------------------------------
# 3. Build Docker image
# ---------------------------------------------------------------------------
log "Building Docker image ${IMAGE_NAME} ..."
docker build -t "${IMAGE_NAME}" --build-arg BUILD_ID="${BUILD_ID}" .

# ---------------------------------------------------------------------------
# 4. Remove old container
# ---------------------------------------------------------------------------
log "Removing old container ${CONTAINER_NAME} (if any) ..."
docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true

# ---------------------------------------------------------------------------
# 5. Prepare docker run arguments
# ---------------------------------------------------------------------------
declare -a RUN_ARGS=(
  -d
  --name "${CONTAINER_NAME}"
  --restart unless-stopped
  -p "127.0.0.1:${HOST_PORT}:${CONTAINER_PORT}"
  -v "${DATA_VOLUME}:/data"
  -e "BUILD_ID=${BUILD_ID}"
)

# Pass application env variables
if [[ ${#ENV_FLAGS[@]} -gt 0 ]]; then
  RUN_ARGS+=("${ENV_FLAGS[@]}")
fi

# Optional config file mount
if [[ -n "${CONFIG_HOST}" && -f "${CONFIG_HOST}" ]]; then
  log "Mounting config file ${CONFIG_HOST} -> ${CONFIG_CONTAINER}"
  RUN_ARGS+=(-v "${CONFIG_HOST}:${CONFIG_CONTAINER}:ro")
fi

# ---------------------------------------------------------------------------
# 6. Start new container
# ---------------------------------------------------------------------------
log "Starting container ${CONTAINER_NAME} on port ${HOST_PORT} ..."
docker run "${RUN_ARGS[@]}" "${IMAGE_NAME}"

# ---------------------------------------------------------------------------
# 7. Health check
# ---------------------------------------------------------------------------
HEALTH_URL="http://127.0.0.1:${HOST_PORT}/api/healthz"
MAX_ATTEMPTS=10

log "Running health check against ${HEALTH_URL} ..."
for i in $(seq 1 "${MAX_ATTEMPTS}"); do
  if curl -sfS "${HEALTH_URL}" >/dev/null 2>&1; then
    log "Health check passed (attempt ${i}/${MAX_ATTEMPTS})"
    break
  fi

  if [[ "${i}" -eq "${MAX_ATTEMPTS}" ]]; then
    echo "!!! Health check failed after ${MAX_ATTEMPTS} attempts" >&2
    echo "--- Last ${CONTAINER_NAME} logs ---" >&2
    docker logs --tail=80 "${CONTAINER_NAME}" >&2
    exit 1
  fi

  sleep 1
done

log "Deploy complete. Container ${CONTAINER_NAME} is running (build ${BUILD_ID})."
