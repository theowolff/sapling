#!/usr/bin/env bash
set -euo pipefail
DC="docker compose"; $DC version >/dev/null 2>&1 || DC="docker-compose"
[ -f ".env" ] && export $(grep -v '^#' .env | xargs -d '\n') || true
WP_PATH="/var/www/html/wp"
SLUG="${CHILD_THEME_SLUG:-twwp-child}"
$DC exec php wp theme activate "$SLUG" --path="$WP_PATH"
$DC exec php wp theme list --path="$WP_PATH" --status=active
