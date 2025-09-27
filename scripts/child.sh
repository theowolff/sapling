#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/child.sh                # run all: patch + prefix + activate
#   ./scripts/child.sh all
#   ./scripts/child.sh patch
#   ./scripts/child.sh prefix
#   ./scripts/child.sh activate
#   ./scripts/child.sh help

# --- env + docker compose shim ---
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

# --- paths & inputs ---
THEMES_DIR="wp-content/themes"
PARENT_DIR="${PARENT_DIR:-twwp-theme}"         # can override via env if needed
CHILD_REPO_DIR="${CHILD_REPO_DIR:-twwp-theme-child}"

SLUG="${CHILD_THEME_SLUG:-twwp-child}"
NAME="${CHILD_THEME_NAME:-Your Child Theme}"

WP_PATH="/var/www/html/wp"

# --- helpers ---
sanitize_slug_to_prefix() {
  # lower + non-alnum → _ ; collapse/trim _ ; suffix underscore
  local s="$1"
  local lower; lower="$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]')"
  local safe;  safe="$(printf '%s' "$lower" | sed -E 's/[^a-z0-9]+/_/g; s/^_+|_+$//g; s/_+/_/g')"
  printf '%s_' "$safe"
}

do_patch() {
  echo "[child] Patching child theme identity…"

  # rename folder from template repo name to desired slug
  if [ -d "${THEMES_DIR}/${CHILD_REPO_DIR}" ] && [ "${CHILD_REPO_DIR}" != "${SLUG}" ]; then
    rm -rf "${THEMES_DIR}/${SLUG}" || true
    mv "${THEMES_DIR}/${CHILD_REPO_DIR}" "${THEMES_DIR}/${SLUG}"
    echo "[child] Renamed ${CHILD_REPO_DIR} → ${SLUG}"
  fi

  local style="${THEMES_DIR}/${SLUG}/style.css"
  if [ -f "$style" ]; then
    cat > "${style}.tmp" <<EOF
/*
Theme Name: ${NAME}
Template: ${PARENT_DIR}
Text Domain: ${SLUG}
Version: 0.2.0
*/
EOF
    # keep anything after the first line of original (if present)
    tail -n +2 "$style" >> "${style}.tmp" 2>/dev/null || true
    mv "${style}.tmp" "$style"
    echo "[child] Updated style.css header (Theme Name='${NAME}', Text Domain='${SLUG}', Template='${PARENT_DIR}')"
  else
    echo "[child] WARN: ${style} not found; skipped header update"
  fi
}

do_prefix() {
  echo "[child] Rewriting function prefix twwp_ → based on slug '${SLUG}'…"
  local prefix; prefix="$(sanitize_slug_to_prefix "$SLUG")"
  local theme_dir="${THEMES_DIR}/${SLUG}"

  if [ ! -d "$theme_dir" ]; then
    echo "[child] ERROR: Theme directory not found: $theme_dir" >&2
    exit 1
  fi

  export NEW_PREFIX="$prefix"
  # Replace only token-start "twwp_" (word boundary) in PHP files, skip vendor/node_modules/dist
  find "$theme_dir" -type f -name "*.php" \
    -not -path "*/vendor/*" -not -path "*/node_modules/*" -not -path "*/dist/*" -print0 \
    | xargs -0 perl -0777 -i -pe 's/\btwwp_/$ENV{NEW_PREFIX}/g'

  echo "[child] Prefix rewrite complete → ${NEW_PREFIX}"
}

do_activate() {
  echo "[child] Activating child theme '${SLUG}' via WP-CLI…"
  $DC exec php wp --allow-root theme activate "$SLUG" --path="$WP_PATH"
  $DC exec php wp --allow-root theme list --path="$WP_PATH" --status=active
}

do_all() {
  do_patch
  do_prefix
  do_activate
}

cmd="${1:-all}"
case "$cmd" in
  all)      do_all      ;;
  patch)    do_patch    ;;
  prefix)   do_prefix   ;;
  activate) do_activate ;;
  *) echo "Unknown command: $cmd"; exit 1 ;;
esac
