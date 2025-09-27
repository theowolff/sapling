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

[ -f ".env" ] || { cp .env.example .env && echo "[setup] Created .env from .env.example"; }
load_env

mkdir -p wp-content/themes
cd wp-content/themes

# Clone/update parent
if [ -z "${THEME_REPO:-}" ]; then echo "ERROR: THEME_REPO not set in .env"; exit 1; fi
if [ ! -d "twwp-theme/.git" ]; then
  git clone "$THEME_REPO" twwp-theme
else
  (cd twwp-theme && git pull --ff-only)
fi

# Clone/update child
if [ -z "${CHILD_REPO:-}" ]; then echo "ERROR: CHILD_REPO not set in .env"; exit 1; fi
if [ ! -d "twwp-theme-child/.git" ]; then
  git clone "$CHILD_REPO" twwp-theme-child
else
  (cd twwp-theme-child && git pull --ff-only)
fi

cd ../../

# Start stack + composer
$DC up -d --build
$DC exec php composer install

# Helper for npm install (ci if lock exists, else i) — single line, safe to pass via env
npm_install_block='if [ -f package-lock.json ]; then npm ci; else npm i; npm i --package-lock-only >/dev/null 2>&1 || true; fi'

# Build parent (dev)
$DC exec -e NPM_INSTALL_BLOCK="$npm_install_block" php bash -lc 'set -e; cd wp-content/themes/twwp-theme; eval "$NPM_INSTALL_BLOCK"; npx gulp dev' || true

# Patch child identity, then install and build child
./scripts/patch-child.sh
SLUG="${CHILD_THEME_SLUG:-twwp-child}"

$DC exec -e NPM_INSTALL_BLOCK="$npm_install_block" php bash -lc "set -e; cd wp-content/themes/${SLUG}; eval \"\$NPM_INSTALL_BLOCK\"; npx gulp dev" || true

# Install WP + admin, then activate child
./scripts/generate-salts.sh
./scripts/wp-admin.sh
./scripts/activate-child.sh

DEFAULT_HOME="http://${SLUG}.localhost:8080"
echo -e "\nOpen WordPress: ${WP_HOME:-$DEFAULT_HOME}"
echo "Adminer:        http://localhost:8081"
