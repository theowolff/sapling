#!/usr/bin/env bash
set -euo pipefail

DC="docker compose"; $DC version >/dev/null 2>&1 || DC="docker-compose"

load_env() {
  if [ -f ".env" ]; then
    set -a
    . ./.env
    set +a
  fi
}
load_env

WP_PATH="/var/www/html/wp"
SLUG="${CHILD_THEME_SLUG:-twwp-child}"

$DC exec php wp --allow-root theme activate "$SLUG" --path="$WP_PATH"
$DC exec php wp --allow-root theme list --path="$WP_PATH" --status=active
