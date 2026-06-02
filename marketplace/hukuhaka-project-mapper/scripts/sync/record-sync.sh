#!/usr/bin/env bash
# record-sync.sh — thin wrapper around record_sync.py.
# Stamps .claude/.map-sync-state with current HEAD after a map-sync run.
# Usage: bash record-sync.sh [project_root]   (default root: cwd)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 not found. map-sync requires python3." >&2
    exit 1
fi

python3 "$SCRIPT_DIR/record_sync.py" "$@"
