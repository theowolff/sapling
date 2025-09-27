
#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# setup.sh - One-step local dev setup for Sapling child theme
#
# @package sapling
# @author theowolff
# ------------------------------------------------------------------------------
set -euo pipefail

# ------------------------------------------------------------------------------
# Docker compose command detection
# ------------------------------------------------------------------------------
DC="docker compose"; $DC version >/dev/null 2>&1 || DC="docker-compose"

# ------------------------------------------------------------------------------
# Load environment variables from .env
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# Setup summary file (repo root) — truncate
# ------------------------------------------------------------------------------
SUMMARY="$(pwd)/.setup_summary.txt"
: > "$SUMMARY"

# ------------------------------------------------------------------------------
# Clone/update parent and child theme repos
# ------------------------------------------------------------------------------
mkdir -p wp-content/themes
cd wp-content/themes

# Clone/update parent
if [ -z "${THEME_REPO:-}" ]; then echo "ERROR: THEME_REPO not set in .env"; exit 1; fi
if [ ! -d "sapling-theme/.git" ]; then
  git clone "$THEME_REPO" sapling-theme
else
  (cd sapling-theme && git pull --ff-only)
fi

# Clone/update child template repo (will be renamed/patched)
if [ -z "${CHILD_REPO:-}" ]; then echo "ERROR: CHILD_REPO not set in .env"; exit 1; fi
if [ ! -d "sapling-theme-child/.git" ]; then
  git clone "$CHILD_REPO" sapling-theme-child
else
  (cd sapling-theme-child && git pull --ff-only)
fi

cd ../../

# ------------------------------------------------------------------------------
# Start stack + composer
# ------------------------------------------------------------------------------
$DC up -d --build
$DC exec php composer install

# ------------------------------------------------------------------------------
# Helper for npm install (ci if lock exists, else i)
# ------------------------------------------------------------------------------
npm_install_block='if [ -f package-lock.json ]; then npm ci; else npm i; npm i --package-lock-only >/dev/null 2>&1 || true; fi'

# ------------------------------------------------------------------------------
# Build parent (dev) INSIDE container (Linux)
# ------------------------------------------------------------------------------
$DC exec -e NPM_INSTALL_BLOCK="$npm_install_block" php bash -lc 'set -e; cd wp-content/themes/sapling-theme; eval "$NPM_INSTALL_BLOCK"; npx gulp dev' || true

# ------------------------------------------------------------------------------
# Patch child identity, then rewrite prefixes based on slug
# ------------------------------------------------------------------------------
./scripts/child.sh patch
./scripts/child.sh prefix
./scripts/child.sh docblocks
SLUG="${CHILD_THEME_SLUG:-sapling-child}"

# ------------------------------------------------------------------------------
# Build child ON HOST (avoid esbuild mismatch)
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# Guard container-side child build if marker exists
# ------------------------------------------------------------------------------
$DC exec php bash -lc "set -e; cd wp-content/themes/${SLUG}; \
  if [ -f .use_host_node ]; then \
    echo '[setup] .use_host_node present — skipping container npm/gulp for child'; \
  else \
    ([ -f package-lock.json ] && npm ci || npm i); npx gulp dev || true; \
  fi" || true

# ------------------------------------------------------------------------------
# Install WP + admin, then activate child (admin writes creds to SUMMARY)
# ------------------------------------------------------------------------------
./scripts/salts.sh
./scripts/admin.sh
./scripts/child.sh activate

DEFAULT_HOME="http://${SLUG}.localhost:8080"
{
  echo ""
  echo "Open WordPress: ${WP_HOME:-$DEFAULT_HOME}"
  echo "Adminer:        http://localhost:8081"
} >> "$SUMMARY"

# ------------------------------------------------------------------------------
# Auto-finalize: write .gitignore + sync.sh (no env changes). Set SKIP_FINALIZE=1 to skip.
# ------------------------------------------------------------------------------
if [ "${SKIP_FINALIZE:-0}" != "1" ]; then
  echo "[setup] Finalizing repo layout (child-only tracking + sync script)"
  ./scripts/finalize.sh || true
else
  echo "[setup] Skipped finalization (SKIP_FINALIZE=1)"
fi

# ------------------------------------------------------------------------------
# Print the important info
# ------------------------------------------------------------------------------
if [ -s "$SUMMARY" ]; then
  # ANSI colors (fallback-safe)
  GREEN="$(tput setaf 2 2>/dev/null || echo '\033[0;32m')"
  RESET="$(tput sgr0 2>/dev/null || echo '\033[0m')"

  echo ""
  echo -e "${GREEN}===================="
  echo -e " Setup Summary"
  echo -e "====================${RESET}"
  sed 's/^/'"${GREEN}"'/' "$SUMMARY"
  echo -e "${RESET}${GREEN}====================${RESET}"
fi
