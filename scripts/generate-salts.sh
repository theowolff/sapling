#!/usr/bin/env bash
set -euo pipefail

CFG="wp-config.php"
if [ ! -f "$CFG" ]; then
  echo "wp-config.php not found"; exit 1
fi

SALTS="$(curl -fsSL https://api.wordpress.org/secret-key/1.1/salt/)"
if [ -z "$SALTS" ]; then
  echo "Failed to fetch salts"; exit 2
fi

ESCAPED=$(printf '%s\n' "$SALTS" | sed -e 's/[\/&]/\\&/g')

awk -v repl="$ESCAPED" '
  BEGIN { inblk=0 }
  /\/\* BEGIN AUTH SALTS \*\// { print "/* BEGIN AUTH SALTS */\n" repl; inblk=1; next }
  /\/\* END AUTH SALTS \*\// { print "/* END AUTH SALTS */"; inblk=0; next }
  { if (!inblk) print }
' "$CFG" > "$CFG.tmp" && mv "$CFG.tmp" "$CFG"

echo "[salts] Injected new salts into wp-config.php"
