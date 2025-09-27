
#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# salts.sh - Fetch and inject fresh WordPress salts into wp-config.php
#
# @package sapling
# @author theowolff
# ------------------------------------------------------------------------------
set -euo pipefail

# ------------------------------------------------------------------------------
# Check for wp-config.php
# ------------------------------------------------------------------------------
CFG="wp-config.php"
if [ ! -f "$CFG" ]; then
  echo "wp-config.php not found"; exit 1
fi

# ------------------------------------------------------------------------------
# 1) Fetch new salts (8 define() lines) into a temp file
# ------------------------------------------------------------------------------
TMP_SALTS="$(mktemp)"; trap 'rm -f "$TMP_SALTS" "$TMP_NOSALTS"' EXIT
curl -fsSL https://api.wordpress.org/secret-key/1.1/salt/ > "$TMP_SALTS" || {
  echo "Failed to fetch salts"; exit 2;
}
# Normalize endings if dos2unix exists
dos2unix "$TMP_SALTS" >/dev/null 2>&1 || true

# ------------------------------------------------------------------------------
# 2) Strip any existing salts block from the config
# ------------------------------------------------------------------------------
TMP_NOSALTS="$(mktemp)"
awk '
  /\/\* BEGIN AUTH SALTS \*\// { inblk=1; next }
  /\/\* END AUTH SALTS \*\//   { inblk=0; next }
  { if (!inblk) print }
' "$CFG" > "$TMP_NOSALTS"

# ------------------------------------------------------------------------------
# 3) Inject the fresh salts block BEFORE wp-settings.php require
#    If that line is not found (unlikely), append the block at the end.
# ------------------------------------------------------------------------------
awk -v saltsf="$TMP_SALTS" '
  BEGIN { inserted=0 }
  # Match: require_once ABSPATH . "wp-settings.php"; (single or double quotes)
  /require_once[[:space:]]+ABSPATH[[:space:]]*\.[[:space:]]*["'\'\"]wp-settings\.php["'\'\"][[:space:]]*;/ && !inserted {
    print "/* BEGIN AUTH SALTS */"
    while ((getline line < saltsf) > 0) print line
    close(saltsf)
    print "/* END AUTH SALTS */"
    print ""  # spacer
    print      # the require line itself
    inserted=1
    next
  }
  { print }
  END {
    if (!inserted) {
      print ""
      print "/* BEGIN AUTH SALTS */"
      while ((getline line < saltsf) > 0) print line
      close(saltsf)
      print "/* END AUTH SALTS */"
      print ""
    }
  }
' "$TMP_NOSALTS" > "$CFG.tmp" && mv "$CFG.tmp" "$CFG"

echo "[salts] Injected new salts ABOVE wp-settings.php in $CFG"
