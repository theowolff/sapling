#!/usr/bin/env bash
set -euo pipefail

DC="docker compose"; $DC version >/dev/null 2>&1 || DC="docker-compose"

load_env() {
  if [ -f ".env" ]; then
    set -a
    set +u
    . ./.env
    set -u
    set +a
  fi
}
load_env

# summary file (repo root)
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SUMMARY="$ROOT/.setup_summary.txt"

WP_PATH="/var/www/html/wp"
SITE_URL="${WP_HOME:-http://localhost:8080}"
ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"

# Derive admin password (env > saved file > random)
if [ -n "${ADMIN_PASSWORD:-}" ]; then
  PASS="$ADMIN_PASSWORD"
elif [ -f ".admin_pass" ]; then
  PASS="$(cat .admin_pass)"
else
  PASS="$(tr -dc 'A-Za-z0-9!@#$%^&*()_+-=' < /dev/urandom | head -c 20)"
  echo "$PASS" > .admin_pass
fi

# Bring services up
$DC up -d >/dev/null

# --- Wait for DB to be ready ---
DB_HOST_INSIDE="${DB_HOST:-db}"   # in Docker, use the service name (e.g., 'db')
DB_USER_INSIDE="${DB_USER:-root}"
DB_PASS_INSIDE="${DB_PASSWORD:-}"

echo "[admin] Waiting for database at ${DB_HOST_INSIDE}..."
for i in {1..30}; do
  if $DC exec php bash -lc "mysql -h '${DB_HOST_INSIDE}' -u'${DB_USER_INSIDE}' -p'${DB_PASS_INSIDE}' -e 'SELECT 1' >/dev/null 2>&1"; then
    echo "[admin] DB is up."
    break
  fi
  sleep 2
  if [ "$i" -eq 30 ]; then
    echo "[admin] ERROR: Database not reachable. Check DB_HOST/DB_USER/DB_PASSWORD and the db service logs."
    exit 1
  fi
done
# --- end DB wait ---

# Install WordPress (idempotent)
if $DC exec php wp --allow-root core is-installed --path="$WP_PATH" >/dev/null 2>&1; then
  echo "[admin] WordPress already installed."
else
  $DC exec php wp --allow-root core install \
    --path="$WP_PATH" \
    --url="$SITE_URL" \
    --title="${CHILD_THEME_NAME:-sapling site}" \
    --admin_user="$ADMIN_USER" \
    --admin_password="$PASS" \
    --admin_email="$ADMIN_EMAIL"
fi

# Ensure the admin user exists with the desired password
$DC exec php wp --allow-root user update "$ADMIN_USER" --user_pass="$PASS" --path="$WP_PATH" >/dev/null || \
$DC exec php wp --allow-root user create "$ADMIN_USER" "$ADMIN_EMAIL" --role=administrator --user_pass="$PASS" --path="$WP_PATH" >/dev/null

# write summary (don’t print now — setup.sh will print after finalize)
{
  echo "Admin: $ADMIN_USER"
  echo "Pass:  $PASS"
  echo "Login: ${SITE_URL}/wp/wp-login.php"
} >> "$SUMMARY"

echo "[admin] Credentials captured for summary."
