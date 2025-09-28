
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
# Ignore everything at repo root
/*

# Keep these root files
!/.gitignore
!/composer.json
!/composer.lock

# Keep only scripts/sync.sh (ignore any other scripts)
!/scripts/
!/scripts/sync.sh
/scripts/*
!/scripts/sync.sh

# Re-allow wp-content + themes directory
!/wp-content/
!/wp-content/themes/

# Include ONLY the child theme
!/wp-content/themes/${SLUG}/
!/wp-content/themes/${SLUG}/**

# Re-ignore build/vendor folders inside the child
# Node, build outputs, caches, envs
/wp-content/themes/${SLUG}/node_modules/**
/wp-content/themes/${SLUG}/dist/**
/wp-content/themes/${SLUG}/.cache/**
/wp-content/themes/${SLUG}/.sass-cache/**
/wp-content/themes/${SLUG}/.parcel-cache/**
/wp-content/themes/${SLUG}/.next/**
/wp-content/themes/${SLUG}/.nuxt/**
/wp-content/themes/${SLUG}/.env
/wp-content/themes/${SLUG}/.env.*

# Force-ignore everything else under wp-content we don't want
/wp-content/plugins/
/wp-content/themes/sapling-theme/
/wp-content/uploads/
/wp-content/mu-plugins/
/wp-content/cache/
/wp-content/upgrade/
/wp-content/languages/
/wp-content/debug.log

# Composer vendor should not be tracked
/vendor/
EOF
echo "[finalize] Wrote .gitignore"

# ------------------------------------------------------------------------------
# 2) Install sync.sh (rehydrates core + parent, links child) — no env writes
# ------------------------------------------------------------------------------
cat > scripts/sync.sh <<'EOSH'
#!/usr/bin/env bash
set -euo pipefail

CORE_REPO="${CORE_REPO:-https://github.com/theowolff/sapling-infra.git}"
PARENT_REPO="${PARENT_REPO:-https://github.com/theowolff/sapling-theme.git}"

ROOT="$(cd "$(dirname "$0")" && pwd)"
CORE_DIR="$ROOT/core"

# Load env to read CHILD_THEME_SLUG (user must provide .env manually)
if [ -f "$CORE_DIR/.env" ]; then
  set -a; set +u; . "$CORE_DIR/.env"; set -u; set +a
elif [ -f "$ROOT/.env" ]; then
  set -a; set +u; . "$ROOT/.env"; set -u; set +a
fi
SLUG="${CHILD_THEME_SLUG:-}"
[ -n "$SLUG" ] || { echo "[sync] CHILD_THEME_SLUG not set. Create ./core/.env or ./.env and retry."; exit 1; }

# 1) clone/update core
if [ ! -d "$CORE_DIR/.git" ]; then
  echo "[sync] Cloning core → $CORE_DIR"
  git clone "$CORE_REPO" "$CORE_DIR"
else
  echo "[sync] Updating core"
  (cd "$CORE_DIR" && git pull --ff-only || true)
fi

# 2) clone/update parent
mkdir -p "$CORE_DIR/wp-content/themes"
if [ ! -d "$CORE_DIR/wp-content/themes/sapling-theme/.git" ]; then
  echo "[sync] Cloning parent theme"
  git clone "$PARENT_REPO" "$CORE_DIR/wp-content/themes/sapling-theme"
else
  echo "[sync] Updating parent theme"
  (cd "$CORE_DIR/wp-content/themes/sapling-theme" && git pull --ff-only || true)
fi

# 3) link child (from this repo) into core
if [ ! -d "$ROOT/wp-content/themes/$SLUG" ]; then
  echo "[sync] ERROR: child theme not found at wp-content/themes/$SLUG"; exit 1
fi
rm -rf "$CORE_DIR/wp-content/themes/$SLUG" 2>/dev/null || true
ln -s "$ROOT/wp-content/themes/$SLUG" "$CORE_DIR/wp-content/themes/$SLUG"
echo "[sync] Linked child → core/wp-content/themes/$SLUG"

# 4) start & build (no config changes)
cd "$CORE_DIR"
DC="docker compose"; $DC version >/dev/null 2>&1 || DC="docker-compose"

$DC up -d --build
$DC exec php composer install
$DC exec php bash -lc 'set -e; cd wp-content/themes/sapling-theme; ([ -f package-lock.json ] && npm ci || npm i); npx gulp dev' || true

# Child build inside container ONLY if we are not using host node for the child
$DC exec php bash -lc "set -e; cd wp-content/themes/$SLUG; \
  if [ -f .use_host_node ]; then \
    echo '[sync] .use_host_node present — skipping container npm/gulp for child'; \
  else \
    ([ -f package-lock.json ] && npm ci || npm i); npx gulp dev || true; \
  fi" || true

./scripts/salts.sh
./scripts/admin.sh
./scripts/child.sh activate

echo
echo "✅ Sync complete."
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
