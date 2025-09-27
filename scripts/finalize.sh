
#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# finalize.sh - Finalize and prepare child theme repo for client delivery
#
# @package sapling
# @author theowolff
# ------------------------------------------------------------------------------
set -euo pipefail

# ------------------------------------------------------------------------------
# Set repo root and change to it
# ------------------------------------------------------------------------------
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# ------------------------------------------------------------------------------
# Read environment variables (no writes)
# ------------------------------------------------------------------------------
if [ -f ".env" ]; then
  set -a; set +u; . ./.env; set -u; set +a
fi

SLUG="${CHILD_THEME_SLUG:-}"
REMOTE_URL="${GIT_REMOTE_URL:-}"

[ -n "${SLUG}" ] || { echo "[finalize] ERROR: CHILD_THEME_SLUG not set in .env"; exit 1; }
[ -d "wp-content/themes/${SLUG}" ] || { echo "[finalize] ERROR: child theme folder wp-content/themes/${SLUG} not found"; exit 1; }

# ------------------------------------------------------------------------------
# 1) Write .gitignore (strict: track only child + composer + sync.sh)
# ------------------------------------------------------------------------------
cat > .gitignore <<EOF
# ...existing code...
EOF
echo "[finalize] Wrote .gitignore"

# ------------------------------------------------------------------------------
# 2) Install sync.sh (rehydrates core + parent, links child) — no env writes
# ------------------------------------------------------------------------------
cat > scripts/sync.sh <<'EOSH'
# ...existing code...
EOSH
chmod +x scripts/sync.sh
echo "[finalize] Installed sync.sh"

# ------------------------------------------------------------------------------
# 3) Remove nested repos (parent + child)
# ------------------------------------------------------------------------------
[ -d "wp-content/themes/sapling-theme/.git" ] && rm -rf "wp-content/themes/sapling-theme/.git"
[ -d "wp-content/themes/${SLUG}/.git" ] && rm -rf "wp-content/themes/${SLUG}/.git"

# ------------------------------------------------------------------------------
# 4) Remove root git (wipe history)
# ------------------------------------------------------------------------------
[ -d ".git" ] && rm -rf .git

# ------------------------------------------------------------------------------
# 5) Re-init new repo & push
# ------------------------------------------------------------------------------
git init
git branch -M main
git add -A
git commit -m "Initial commit (client child theme + sync script)"

if [ -n "$REMOTE_URL" ]; then
  git remote add origin "$REMOTE_URL" || git remote set-url origin "$REMOTE_URL"
  git push -u origin main
  echo "[finalize] Pushed to $REMOTE_URL (branch: main)"
else
  echo "[finalize] No GIT_REMOTE_URL in .env — skipped adding/pushing remote."
fi

echo "[finalize] Done."
