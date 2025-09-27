#!/usr/bin/env bash
set -euo pipefail

SLUG="${CHILD_THEME_SLUG:-twwp-child}"
THEME_DIR="wp-content/themes/${SLUG}"

lower="$(printf '%s' "$SLUG" | tr '[:upper:]' '[:lower:]')"
safe="$(printf '%s' "$lower" | sed -E 's/[^a-z0-9]+/_/g; s/^_+|_+$//g; s/_+/_/g')"
NEW_PREFIX="${safe}_"

if [ ! -d "$THEME_DIR" ]; then
  echo "[prefix] ERROR: Theme directory not found: $THEME_DIR" >&2
  exit 1
fi

export NEW_PREFIX
echo "[prefix] Rewriting function prefix: twwp_ → ${NEW_PREFIX} under ${THEME_DIR}"

find "$THEME_DIR" -type f -name "*.php" \
  -not -path "*/vendor/*" -not -path "*/node_modules/*" -not -path "*/dist/*" -print0 \
  | xargs -0 perl -0777 -i -pe 's/\btwwp_/$ENV{NEW_PREFIX}/g'

echo "[prefix] Done."
