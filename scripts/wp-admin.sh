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
SITE_URL="${WP_HOME:-http://localhost:8080}"
ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"

if [ -n "${ADMIN_PASSWORD:-}" ]; then
  PASS="$ADMIN_PASSWORD"
elif [ -f ".admin_pass" ]; then
  PASS="$(cat .admin_pass)"
else
  PASS="$(tr -dc 'A-Za-z0-9!@#$%^&*()_+-=' < /dev/urandom | head -c 20)"
  echo "$PASS" > .admin_pass
fi

$DC up -d >/dev/null

if $DC exec php wp --allow-root core is-installed --path="$WP_PATH" >/dev/null 2>&1; then
  echo "[wp-admin] WordPress already installed."
else
  $DC exec php wp --allow-root core install --path="$WP_PATH" --url="$SITE_URL" --title="twwp site" \
    --admin_user="$ADMIN_USER" --admin_password="$PASS" --admin_email="$ADMIN_EMAIL"
fi

$DC exec php wp --allow-root user update "$ADMIN_USER" --user_pass="$PASS" --path="$WP_PATH" >/dev/null || \
$DC exec php wp --allow-root user create "$ADMIN_USER" "$ADMIN_EMAIL" --role=administrator --user_pass="$PASS" --path="$WP_PATH" >/dev/null

echo "Admin: $ADMIN_USER"
echo "Pass:  $PASS"
echo "Login: ${SITE_URL}/wp/wp-login.php"
