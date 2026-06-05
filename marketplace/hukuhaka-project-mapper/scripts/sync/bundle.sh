#!/usr/bin/env bash
# bundle.sh — thin wrapper around bundle.py for map-sync Step 2b.
# Assembles .claude/.sync/bundle.md from skeleton + scattered CLAUDE.md + docs.
# Usage: bash bundle.sh [project_root]   (default root: cwd)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 not found. map-sync requires python3." >&2
    exit 1
fi

python3 "$SCRIPT_DIR/bundle.py" "$@"
