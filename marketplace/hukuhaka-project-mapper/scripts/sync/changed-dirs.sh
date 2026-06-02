#!/usr/bin/env bash
# changed-dirs.sh — thin wrapper around changed_dirs.py for map-sync Step 1.
# Emits the scatter directories that need regeneration, one per line.
# Usage: bash changed-dirs.sh [project_root] [--full]   (default root: cwd)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 not found. map-sync requires python3." >&2
    exit 1
fi

python3 "$SCRIPT_DIR/changed_dirs.py" "$@"
