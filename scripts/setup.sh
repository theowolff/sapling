#!/usr/bin/env bash
set -euo pipefail
DC="docker compose"; $DC version >/dev/null 2>&1 || DC="docker-compose"

[ -f ".env" ] || { cp .env.example .env && echo "[setup] Created .env from .env.example"; }
[ -f ".env" ] && export $(grep -v '^#' .env | xargs -d '\n') || true

mkdir -p wp-content/themes
cd wp-content/themes

# Clone/update parent
if [ -z "${THEME_REPO:-}" ]; then echo "ERROR: THEME_REPO not set in .env"; exit 1; fi
if [ ! -d "twwp-theme/.git" ]; then git clone "$THEME_REPO" twwp-theme; else (cd twwp-theme && git pull --ff-only); fi

# Clone/update child
if [ -z "${CHILD_REPO:-}" ]; then echo "ERROR: CHILD_REPO not set in .env"; exit 1; fi
if [ ! -d "twwp-theme-child/.git" ]; then git clone "$CHILD_REPO" twwp-theme-child; else (cd twwp-theme-child && git pull --ff-only); fi

cd ../../

# Start stack + composer
$DC up -d --build
$DC exec php composer install

# Build parent & child (dev)
$DC exec php bash -lc "cd wp-content/themes/twwp-theme && npm i && npx gulp dev" || true

# Patch child identity, then install and build child
./scripts/patch-child.sh
SLUG="${CHILD_THEME_SLUG:-twwp-child}"
$DC exec php bash -lc "cd wp-content/themes/${SLUG} && npm i && npx gulp dev" || true

# Install WP + admin, then activate child
./scripts/generate-salts.sh # generate new salts
./scripts/wp-admin.sh
./scripts/activate-child.sh

echo -e \"\\nOpen WordPress: ${WP_HOME:-http://$CHILD_THEME_SLUG.localhost:8080}\\nAdminer: http://localhost:8081\"
