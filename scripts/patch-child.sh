#!/usr/bin/env bash
set -euo pipefail
[ -f ".env" ] && export $(grep -v '^#' .env | xargs -d '\n') || true

THEMES_DIR="wp-content/themes"
PARENT_DIR="twwp-theme"
CHILD_REPO_DIR="twwp-theme-child"
SLUG="${CHILD_THEME_SLUG:-twwp-child}"
NAME="${CHILD_THEME_NAME:-Your Child Theme}"

# Rename child folder
if [ -d "${THEMES_DIR}/${CHILD_REPO_DIR}" ] && [ "${CHILD_REPO_DIR}" != "${SLUG}" ]; then
  rm -rf "${THEMES_DIR}/${SLUG}" || true
  mv "${THEMES_DIR}/${CHILD_REPO_DIR}" "${THEMES_DIR}/${SLUG}"
fi

STYLE="${THEMES_DIR}/${SLUG}/style.css"
if [ -f "$STYLE" ]; then
  cat > "$STYLE".tmp <<EOF
/*
Theme Name: ${NAME}
Template: ${PARENT_DIR}
Text Domain: ${SLUG}
Version: 0.2.0
*/
EOF
  tail -n +2 "$STYLE" >> "$STYLE".tmp || true
  mv "$STYLE".tmp "$STYLE"
fi
