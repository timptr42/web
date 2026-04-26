#!/usr/bin/env bash
set -euo pipefail

DOMAINS="${DOMAINS:-timptr.ru www.timptr.ru}"
APP_PORT="${APP_PORT:-8080}"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-timptr-pattern}"
NGINX_SITE_NAME="${NGINX_SITE_NAME:-timptr-pattern}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
NGINX_AVAILABLE="/etc/nginx/sites-available/${NGINX_SITE_NAME}.conf"
NGINX_ENABLED="/etc/nginx/sites-enabled/${NGINX_SITE_NAME}.conf"
NGINX_TEMPLATE="${REPO_DIR}/nginx/timptr.ru.conf.template"

require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Command '${command_name}' is required but was not found." >&2
    exit 1
  fi
}

ensure_docker_daemon() {
  if docker info >/dev/null 2>&1; then
    return
  fi

  echo "Docker daemon is not available. Trying to start Docker..."

  if command -v systemctl >/dev/null 2>&1; then
    systemctl enable --now docker
  elif command -v service >/dev/null 2>&1; then
    service docker start
  else
    echo "Cannot start Docker automatically: systemctl/service was not found." >&2
  fi

  if ! docker info >/dev/null 2>&1; then
    echo "Docker daemon is still unavailable." >&2
    echo "Check it manually with: sudo systemctl status docker" >&2
    echo "If Docker is not installed correctly, install docker.io and docker-compose-plugin." >&2
    exit 1
  fi
}

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script with sudo/root: sudo DOMAINS=\"${DOMAINS}\" APP_PORT=${APP_PORT} ${0}" >&2
  exit 1
fi

require_command docker
require_command nginx
ensure_docker_daemon

if ! docker compose version >/dev/null 2>&1; then
  echo "Docker Compose plugin is required. Install it and rerun the script." >&2
  exit 1
fi

if [[ ! -f "${NGINX_TEMPLATE}" ]]; then
  echo "Nginx template was not found: ${NGINX_TEMPLATE}" >&2
  exit 1
fi

echo "Building and starting Docker app on 127.0.0.1:${APP_PORT}..."
(
  cd "${REPO_DIR}"
  COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME}" APP_PORT="${APP_PORT}" docker compose up -d --build
)

echo "Writing Nginx config for ${DOMAINS}..."
mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled

sed \
  -e "s/__SERVER_NAMES__/${DOMAINS}/g" \
  -e "s/__SITE_NAME__/${NGINX_SITE_NAME}/g" \
  -e "s/__APP_PORT__/${APP_PORT}/g" \
  "${NGINX_TEMPLATE}" > "${NGINX_AVAILABLE}"

ln -sfn "${NGINX_AVAILABLE}" "${NGINX_ENABLED}"

echo "Checking Nginx configuration..."
nginx -t

echo "Reloading Nginx..."
if command -v systemctl >/dev/null 2>&1; then
  systemctl reload nginx
else
  nginx -s reload
fi

echo "Done."
echo "Open: http://timptr.ru or http://www.timptr.ru"
