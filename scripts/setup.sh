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

# summary file (repo root) — truncate
SUMMARY="$(pwd)/.setup_summary.txt"
: > "$SUMMARY"

mkdir -p wp-content/themes
cd wp-content/themes

# Clone/update parent
if [ -z "${THEME_REPO:-}" ]; then echo "ERROR: THEME_REPO not set in .env"; exit 1; fi
if [ ! -d "twwp-theme/.git" ]; then
  git clone "$THEME_REPO" twwp-theme
else
  (cd twwp-theme && git pull --ff-only)
fi

# Clone/update child template repo (will be renamed/patched)
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

# Build parent (dev) INSIDE container (Linux)
$DC exec -e NPM_INSTALL_BLOCK="$npm_install_block" php bash -lc 'set -e; cd wp-content/themes/twwp-theme; eval "$NPM_INSTALL_BLOCK"; npx gulp dev' || true

# Patch child identity, then rewrite prefixes based on slug
./scripts/patch-child.sh
SLUG="${CHILD_THEME_SLUG:-twwp-child}"
./scripts/prefix-child-functions.sh

# Build child ON HOST (avoid esbuild mismatch)
echo "[setup] Installing child theme deps on HOST (wp-content/themes/${SLUG})..."
if [ -d "wp-content/themes/${SLUG}" ]; then
  pushd "wp-content/themes/${SLUG}" >/dev/null
  if [ -f package-lock.json ]; then
    npm ci || npm i
  else
    npm i
    npm i --package-lock-only >/dev/null 2>&1 || true
  fi
  npx gulp dev || true
  touch .use_host_node
  popd >/dev/null
else
  echo "[setup] ERROR: child theme folder wp-content/themes/${SLUG} not found"
fi

# Guard container-side child build if marker exists
$DC exec php bash -lc "set -e; cd wp-content/themes/${SLUG}; \
  if [ -f .use_host_node ]; then \
    echo '[setup] .use_host_node present — skipping container npm/gulp for child'; \
  else \
    ([ -f package-lock.json ] && npm ci || npm i); npx gulp dev || true; \
  fi" || true

# Install WP + admin, then activate child (wp-admin writes creds to SUMMARY)
./scripts/generate-salts.sh
./scripts/wp-admin.sh
./scripts/activate-child.sh

DEFAULT_HOME="http://${SLUG}.localhost:8080"
{
  echo ""
  echo "Open WordPress: ${WP_HOME:-$DEFAULT_HOME}"
  echo "Adminer:        http://localhost:8081"
} >> "$SUMMARY"

# Auto-finalize: write .gitignore + project-sync.sh (no env changes). Set SKIP_FINALIZE=1 to skip.
if [ "${SKIP_FINALIZE:-0}" != "1" ]; then
  echo "[setup] Finalizing repo layout (child-only tracking + sync script)"
  ./scripts/finalize.sh || true
else
  echo "[setup] Skipped finalization (SKIP_FINALIZE=1)"
fi

# --- Print the important info LAST (after any git push logs) ---
if [ -s "$SUMMARY" ]; then
  echo ""
  echo "===================="
  echo " Setup Summary"
  echo "===================="
  cat "$SUMMARY"
  echo "===================="
  # don’t commit this; it’s already excluded by .gitignore pattern we generate
fi
