#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# child.sh - Child theme setup and activation for Sapling/Stump local dev
#
# @package sapling
# @author theowolff
# ------------------------------------------------------------------------------
set -euo pipefail

# Detect docker compose command
DC="docker compose"; $DC version >/dev/null 2>&1 || DC="docker-compose"

# Load environment variables from .env file if present
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

# ------------------------------------------------------------------------------
# Determine mode (headless vs traditional)
# ------------------------------------------------------------------------------
IS_HEADLESS="${IS_HEADLESS:-}"
if [ "$IS_HEADLESS" = "true" ] || [ "$IS_HEADLESS" = "1" ]; then
  MODE="headless"
  PARENT_DIR="${PARENT_DIR:-stump-theme}"
  CHILD_REPO_DIR="${CHILD_REPO_DIR:-stump-theme-child}"
  OLD_PREFIX="stmp_"
else
  MODE="traditional"
  PARENT_DIR="${PARENT_DIR:-sapling-theme}"
  CHILD_REPO_DIR="${CHILD_REPO_DIR:-sapling-theme-child}"
  OLD_PREFIX="splng_"
fi

# Set up theme paths and inputs
THEMES_DIR="wp-content/themes"
SLUG="${CHILD_THEME_SLUG:-sapling-child}"
NAME="${CHILD_THEME_NAME:-Your Child Theme}"

WP_PATH="/var/www/html/wp"

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------
sanitize_slug_to_prefix() {
  local s="$1"
  local lower; lower="$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]')"
  local safe;  safe="$(printf '%s' "$lower" | sed -E 's/[^a-z0-9]+/_/g; s/^_+|_+$//g; s/_+/_/g')"
  printf '%s_' "$safe"
}

# ------------------------------------------------------------------------------
# Patch child theme identity and update style.css header
# ------------------------------------------------------------------------------
do_patch() {
  echo "[child] Patching child theme identity (mode: ${MODE})…"

  if [ -d "${THEMES_DIR}/${CHILD_REPO_DIR}" ] && [ "${CHILD_REPO_DIR}" != "${SLUG}" ]; then
    rm -rf "${THEMES_DIR}/${SLUG}" || true
    mv "${THEMES_DIR}/${CHILD_REPO_DIR}" "${THEMES_DIR}/${SLUG}"
    echo "[child] Renamed ${CHILD_REPO_DIR} → ${SLUG}"
  fi

  local style="${THEMES_DIR}/${SLUG}/style.css"
  if [ -f "$style" ]; then
    cat > "${style}.tmp" <<EOF
/*
 * Theme Name: ${NAME}
 * Author: Theodore Wolff
 * Author URI: https://theo.gg
 * Version: 1.0.0
 * Template: ${PARENT_DIR}
 * Text Domain: ${SLUG}
*/
EOF
    tail -n +2 "$style" >> "${style}.tmp" 2>/dev/null || true
    mv "${style}.tmp" "$style"
    echo "[child] Updated style.css header (Theme Name='${NAME}', Text Domain='${SLUG}', Template='${PARENT_DIR}')"
  else
    echo "[child] WARN: ${style} not found; skipped header update"
  fi
}

# ------------------------------------------------------------------------------
# Rewrite function prefix based on slug
# Sapling uses splng_ prefix, Stump uses stmp_ prefix
# ------------------------------------------------------------------------------
do_prefix() {
  echo "[child] Rewriting function prefix ${OLD_PREFIX} → based on slug '${SLUG}'…"
  local prefix; prefix="$(sanitize_slug_to_prefix "$SLUG")"
  local theme_dir="${THEMES_DIR}/${SLUG}"

  if [ ! -d "$theme_dir" ]; then
    echo "[child] ERROR: Theme directory not found: $theme_dir" >&2
    exit 1
  fi

  export NEW_PREFIX="$prefix"
  export OLD_PREFIX="$OLD_PREFIX"
  find "$theme_dir" -type f -name "*.php" \
    -not -path "*/vendor/*" -not -path "*/node_modules/*" -not -path "*/dist/*" -print0 \
    | xargs -0 perl -0777 -i -pe 's/\b$ENV{OLD_PREFIX}/$ENV{NEW_PREFIX}/g'

  echo "[child] Prefix rewrite complete → ${NEW_PREFIX}"
}

# ------------------------------------------------------------------------------
# Normalize PHP docblocks: set @package to slug across the theme
# ------------------------------------------------------------------------------
do_docblocks() {
  echo "[child] Normalizing PHP docblocks: @package → ${SLUG}"

  local theme_dir="${THEMES_DIR}/${SLUG}"
  [ -d "$theme_dir" ] || { echo "[child] ERROR: theme dir not found: $theme_dir"; exit 1; }

  find "$theme_dir" -type f -name "*.php" \
    -not -path "*/vendor/*" -not -path "*/node_modules/*" -not -path "*/dist/*" -print0 \
    | xargs -0 perl -0777 -i -pe "s/(\\n\\s*\\*\\s*\\@package\\s+)[^\\r\\n]*/\\1${SLUG}/g"

  echo "[child] Docblocks updated."
}

# ------------------------------------------------------------------------------
# Activate child theme via WP-CLI
# ------------------------------------------------------------------------------
do_activate() {
  echo "[child] Activating child theme '${SLUG}' via WP-CLI…"
  $DC exec php wp --allow-root theme activate "$SLUG" --path="$WP_PATH"
  $DC exec php wp --allow-root theme list --path="$WP_PATH" --status=active
}

# ------------------------------------------------------------------------------
# Run all setup steps: patch, prefix, docblocks, activate
# ------------------------------------------------------------------------------
do_all() {
  do_patch
  do_prefix
  do_docblocks
  do_activate
}

# ------------------------------------------------------------------------------
# Command dispatch
# ------------------------------------------------------------------------------
cmd="${1:-all}"
case "$cmd" in
  all)        do_all        ;;
  patch)      do_patch      ;;
  prefix)     do_prefix     ;;
  docblocks)  do_docblocks  ;;
  activate)   do_activate   ;;
  *) echo "Unknown command: $cmd"; exit 1 ;;
esac
