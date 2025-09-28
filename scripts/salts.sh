#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# salts.sh - Fetch and inject fresh WordPress salts into wp-config.php
#
# @package sapling
# @author theowolff
# ------------------------------------------------------------------------------
set -euo pipefail

CFG="wp-config.php"
[ -f "$CFG" ] || { echo "wp-config.php not found"; exit 1; }

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

# --- 3) Try to insert above the "That’s all..." marker ---
TMP3="$(mktemp)"
if insert_before_pattern "/\\* That[’']s all, stop editing! Happy publishing\\. \\*/" "$TMP2" "$TMP3"; then
  mv "$TMP3" "$CFG"
  echo "[salts] Inserted salts above the 'That’s all...' marker."
  exit 0
fi
rm -f "$TMP3"

# --- 4) Try to insert above wp-settings.php require ---
TMP3="$(mktemp)"
WP_SETTINGS_PATTERN="require_once[[:space:]]+(ABSPATH|__DIR__)[[:space:]]*\\.[[:space:]]*['\"][^'\"]*wp-settings\\.php['\"][[:space:]]*;"
if insert_before_pattern "$WP_SETTINGS_PATTERN" "$TMP2" "$TMP3"; then
  mv "$TMP3" "$CFG"
  echo "[salts] Inserted salts above the wp-settings.php require."
  exit 0
fi
rm -f "$TMP3"

# --- 5) Fallback: append to end ---
cat "$TMP2" > "$CFG"
printf "\n" >> "$CFG"
cat "$TMP_BLOCK" >> "$CFG"
printf "\n" >> "$CFG"
echo "[salts] Appended salts at end of $CFG (fallback)."
