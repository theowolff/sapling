#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# salts.sh - Fetch and inject fresh WordPress salts into wp-config.php
#            Also injects Stump JWT config when in headless mode
#
# @package sapling
# @author theowolff
# ------------------------------------------------------------------------------
set -euo pipefail

CFG="wp-config.php"
[ -f "$CFG" ] || { echo "wp-config.php not found"; exit 1; }

# ------------------------------------------------------------------------------
# Load environment variables
# ------------------------------------------------------------------------------
if [ -f ".env" ]; then
  set -a; set +u; . ./.env; set -u; set +a
fi

IS_HEADLESS="${IS_HEADLESS:-}"

TMP_SALTS="" TMP_BLOCK="" TMP1="" TMP2="" TMP3=""
trap 'rm -f "${TMP_SALTS:-}" "${TMP_BLOCK:-}" "${TMP1:-}" "${TMP2:-}" "${TMP3:-}"' EXIT

# --- Fetch salts into a temp file ---
TMP_SALTS="$(mktemp)"
curl -fsSL https://api.wordpress.org/secret-key/1.1/salt/ > "$TMP_SALTS"
dos2unix "$TMP_SALTS" >/dev/null 2>&1 || true

# Build a block file with markers, blank lines, and indentation
TMP_BLOCK="$(mktemp)"
{
  echo ""                     # blank line above
  echo "    /* BEGIN AUTH SALTS */"
  sed 's/^/    /' "$TMP_SALTS"
  echo "    /* END AUTH SALTS */"
  echo ""                     # blank line below
} > "$TMP_BLOCK"

# --- 1) Remove any existing marked block ---
TMP1="$(mktemp)"
awk '
  /\/\* BEGIN AUTH SALTS \*\// { inblk=1; next }
  /\/\* END AUTH SALTS \*\//   { inblk=0; next }
  { if (!inblk) print }
' "$CFG" > "$TMP1"

# --- 2) Remove any loose core salt defines (AUTH_KEY..NONCE_SALT) if present ---
TMP2="$(mktemp)"
awk '
  match($0, /^[[:space:]]*define[[:space:]]*\([[:space:]]*'\''AUTH_KEY'\''/) { indef=1; next }
  indef && match($0, /^[[:space:]]*define[[:space:]]*\([[:space:]]*'\''NONCE_SALT'\''/) { indef=0; next }
  { if (!indef) print }
' "$TMP1" > "$TMP2"

# Helper: insert block before first matching line
insert_before_pattern() {
  local pattern="$1" ; local infile="$2" ; local outfile="$3"
  awk -v blk="$TMP_BLOCK" -v pat="$pattern" '
    BEGIN{ inserted=0 }
    $0 ~ pat && !inserted {
      while ((getline L < blk) > 0) print L
      close(blk)
      print
      inserted=1
      next
    }
    { print }
    END { if (inserted==1) exit 0; else exit 1 }
  ' "$infile" > "$outfile"
}

# --- 3) Try to insert above the "That's all..." marker ---
TMP3="$(mktemp)"
if insert_before_pattern "/\\* That[''']s all, stop editing! Happy publishing\\. \\*/" "$TMP2" "$TMP3"; then
  mv "$TMP3" "$CFG"
  echo "[salts] Inserted salts above the 'That's all...' marker."
else
  rm -f "$TMP3"

  # --- 4) Try to insert above wp-settings.php require ---
  TMP3="$(mktemp)"
  WP_SETTINGS_PATTERN="require_once[[:space:]]+(ABSPATH|__DIR__)[[:space:]]*\\.[[:space:]]*['\"][^'\"]*wp-settings\\.php['\"][[:space:]]*;"
  if insert_before_pattern "$WP_SETTINGS_PATTERN" "$TMP2" "$TMP3"; then
    mv "$TMP3" "$CFG"
    echo "[salts] Inserted salts above the wp-settings.php require."
  else
    rm -f "$TMP3"

    # --- 5) Fallback: append to end ---
    cat "$TMP2" > "$CFG"
    printf "\n" >> "$CFG"
    cat "$TMP_BLOCK" >> "$CFG"
    printf "\n" >> "$CFG"
    echo "[salts] Appended salts at end of $CFG (fallback)."
  fi
fi

# ------------------------------------------------------------------------------
# Inject Stump (Headless) API configuration if IS_HEADLESS=true
# ------------------------------------------------------------------------------
if [ "$IS_HEADLESS" = "true" ] || [ "$IS_HEADLESS" = "1" ]; then
  echo "[salts] Headless mode detected — injecting Stump API configuration…"

  # Generate JWT secret if not provided
  STMP_JWT_SECRET="${STMP_JWT_SECRET:-}"
  if [ -z "$STMP_JWT_SECRET" ]; then
    STMP_JWT_SECRET="$(openssl rand -base64 32 2>/dev/null || head -c 32 /dev/urandom | base64)"
    echo "[salts] Generated STMP_JWT_SECRET (save this to .env for persistence)"
  fi

  STMP_JWT_EXPIRATION="${STMP_JWT_EXPIRATION:-3600}"
  STMP_API_DEBUG="${STMP_API_DEBUG:-false}"

  # Remove any existing Stump config block
  TMP_STUMP="$(mktemp)"
  awk '
    /\/\* BEGIN STUMP API CONFIG \*\// { inblk=1; next }
    /\/\* END STUMP API CONFIG \*\//   { inblk=0; next }
    { if (!inblk) print }
  ' "$CFG" > "$TMP_STUMP"
  mv "$TMP_STUMP" "$CFG"

  # Build Stump config block
  TMP_STUMP_BLOCK="$(mktemp)"
  {
    echo ""
    echo "    /* BEGIN STUMP API CONFIG */"
    echo "    define('STMP_JWT_SECRET', '${STMP_JWT_SECRET}');"
    echo "    define('STMP_JWT_EXPIRATION', ${STMP_JWT_EXPIRATION});"
    if [ "$STMP_API_DEBUG" = "true" ] || [ "$STMP_API_DEBUG" = "1" ]; then
      echo "    define('STMP_API_DEBUG', true);"
    else
      echo "    define('STMP_API_DEBUG', false);"
    fi
    echo "    /* END STUMP API CONFIG */"
    echo ""
  } > "$TMP_STUMP_BLOCK"

  # Insert Stump config after salts block
  TMP_FINAL="$(mktemp)"
  awk -v blk="$TMP_STUMP_BLOCK" '
    /\/\* END AUTH SALTS \*\// {
      print
      while ((getline L < blk) > 0) print L
      close(blk)
      next
    }
    { print }
  ' "$CFG" > "$TMP_FINAL"
  mv "$TMP_FINAL" "$CFG"

  echo "[salts] Stump API configuration injected."
  echo "[salts]   STMP_JWT_SECRET: ${STMP_JWT_SECRET:0:10}... (truncated)"
  echo "[salts]   STMP_JWT_EXPIRATION: ${STMP_JWT_EXPIRATION}"
  echo "[salts]   STMP_API_DEBUG: ${STMP_API_DEBUG}"

  rm -f "$TMP_STUMP_BLOCK"
fi
