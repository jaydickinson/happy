#!/bin/bash
#
# Purge reproducible local artifacts to reclaim disk space.
#
# Removes all node_modules (~8GB) and package build dist/ folders. The repo,
# git history, source, and your local-only files (CLAUDE.md,
# .claude/settings.local.json) are left untouched.
#
# To restore for development, run:  pnpm install
#
# Usage: bash scripts/purge-local.sh

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
echo "Purging reproducible artifacts in: $ROOT"

before=$(du -sh "$ROOT" 2>/dev/null | cut -f1)

# All node_modules (root + every workspace package)
find "$ROOT" -type d -name node_modules -prune -exec rm -rf '{}' +

# Package build outputs (regenerated on build); skip any nested in node_modules
for d in packages/*/dist; do
    [ -d "$d" ] && rm -rf "$d"
done

# pnpm store-linked virtual dir, if present
rm -rf "$ROOT/.pnpm-store" 2>/dev/null || true

after=$(du -sh "$ROOT" 2>/dev/null | cut -f1)

echo "Done. Size: $before -> $after"
echo "Restore with: pnpm install"
