#!/usr/bin/env bash
set -euo pipefail

CFG="wp-config.php"
if [ ! -f "$CFG" ]; then
  echo "wp-config.php not found"; exit 1
fi

# Fetch new salts from WordPress.org
SALTS="$(curl -fsSL https://api.wordpress.org/secret-key/1.1/salt/)"
if [ -z "$SALTS" ]; then
  echo "Failed to fetch salts"; exit 2
fi

# Normalize endings to unix
SALTS="$(printf '%s\n' "$SALTS")"

# Build replacement block (we keep the BEGIN/END markers and the same formatting style)
REPL="/* BEGIN AUTH SALTS */\n$SALTS\n/* END AUTH SALTS */"

# Use perl to replace the entire block between markers (or append if missing)
if grep -q "/\\* BEGIN AUTH SALTS \\*/" "$CFG"; then
  # Use perl in-place multiline substitution (dot matches newline with s)
  perl -0777 -pe "s{/\* BEGIN AUTH SALTS \*/.*?/\* END AUTH SALTS \*/}{$REPL}s" -i "$CFG"
  echo "[salts] Injected new salts into $CFG"
else
  {
    printf '%s\n' "/* BEGIN AUTH SALTS */"
    printf '%s\n' "$SALTS"
    printf '%s\n' "/* END AUTH SALTS */"
  } >> "$CFG"
  echo "[salts] Appended salts to $CFG"
fi
