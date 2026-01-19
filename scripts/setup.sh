#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# setup.sh - One-step local dev setup for Sapling/Stump child theme
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
# Determine mode (headless vs traditional)
# ------------------------------------------------------------------------------
IS_HEADLESS="${IS_HEADLESS:-}"
if [ "$IS_HEADLESS" = "true" ] || [ "$IS_HEADLESS" = "1" ]; then
  MODE="headless"
  PARENT_DIR="stump-theme"
  CHILD_REPO_DIR="stump-theme-child"
  DEFAULT_THEME_REPO="https://github.com/theowolff/stump-theme.git"
  DEFAULT_CHILD_REPO="https://github.com/theowolff/stump-theme-child.git"
  DEFAULT_PREFIX="stmp"
  echo "[setup] Mode: HEADLESS (Stump)"
else
  MODE="traditional"
  PARENT_DIR="sapling-theme"
  CHILD_REPO_DIR="sapling-theme-child"
  DEFAULT_THEME_REPO="https://github.com/theowolff/sapling-theme.git"
  DEFAULT_CHILD_REPO="https://github.com/theowolff/sapling-theme-child.git"
  DEFAULT_PREFIX="splng"
  echo "[setup] Mode: TRADITIONAL (Sapling)"
fi

# Use env overrides or defaults
THEME_REPO="${THEME_REPO:-$DEFAULT_THEME_REPO}"
CHILD_REPO="${CHILD_REPO:-$DEFAULT_CHILD_REPO}"

# Export for child scripts
export IS_HEADLESS MODE PARENT_DIR CHILD_REPO_DIR DEFAULT_PREFIX

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
if [ -z "${THEME_REPO:-}" ]; then echo "ERROR: THEME_REPO not set"; exit 1; fi
if [ ! -d "${PARENT_DIR}/.git" ]; then
  echo "[setup] Cloning parent theme: ${PARENT_DIR}"
  git clone "$THEME_REPO" "$PARENT_DIR"
else
  echo "[setup] Updating parent theme: ${PARENT_DIR}"
  (cd "$PARENT_DIR" && git pull --ff-only)
fi

# Clone/update child template repo (will be renamed/patched)
if [ -z "${CHILD_REPO:-}" ]; then echo "ERROR: CHILD_REPO not set"; exit 1; fi
if [ ! -d "${CHILD_REPO_DIR}/.git" ]; then
  echo "[setup] Cloning child theme template: ${CHILD_REPO_DIR}"
  git clone "$CHILD_REPO" "$CHILD_REPO_DIR"
else
  echo "[setup] Updating child theme template: ${CHILD_REPO_DIR}"
  (cd "$CHILD_REPO_DIR" && git pull --ff-only)
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
# Build parent (dev) INSIDE container (Linux) - only for traditional mode
# Headless (Stump) has no frontend assets to build
# ------------------------------------------------------------------------------
if [ "$MODE" = "traditional" ]; then
  $DC exec -e NPM_INSTALL_BLOCK="$npm_install_block" php bash -lc "set -e; cd wp-content/themes/${PARENT_DIR}; eval \"\$NPM_INSTALL_BLOCK\"; npx gulp dev" || true
else
  echo "[setup] Headless mode: skipping parent theme asset build"
fi

# ------------------------------------------------------------------------------
# Patch child identity, then rewrite prefixes based on slug
# ------------------------------------------------------------------------------
./scripts/child.sh patch
./scripts/child.sh prefix
./scripts/child.sh docblocks
SLUG="${CHILD_THEME_SLUG:-sapling-child}"

# ------------------------------------------------------------------------------
# Build child ON HOST (avoid esbuild mismatch) - only for traditional mode
# ------------------------------------------------------------------------------
if [ "$MODE" = "traditional" ]; then
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
else
  echo "[setup] Headless mode: skipping child theme asset build"
fi

# ------------------------------------------------------------------------------
# Install WP + admin, then activate child (admin writes creds to SUMMARY)
# ------------------------------------------------------------------------------
./scripts/salts.sh
./scripts/admin.sh
./scripts/child.sh activate

DEFAULT_HOME="http://${SLUG}.localhost:8080"
{
  echo ""
  echo "Mode: $(printf '%s' "$MODE" | tr '[:lower:]' '[:upper:]')"
  echo "Open WordPress: ${WP_HOME:-$DEFAULT_HOME}"
  echo "Adminer:        http://localhost:8081"
  if [ "$MODE" = "headless" ]; then
    echo ""
    echo "API Endpoints:"
    echo "  Health:  ${WP_HOME:-$DEFAULT_HOME}/wp-json/stump/v1/health"
    echo "  Login:   ${WP_HOME:-$DEFAULT_HOME}/wp-json/stump/v1/auth/login"
    echo "  Menus:   ${WP_HOME:-$DEFAULT_HOME}/wp-json/stump/v1/menus"
    echo "  Settings: ${WP_HOME:-$DEFAULT_HOME}/wp-json/stump/v1/settings"
  fi
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
