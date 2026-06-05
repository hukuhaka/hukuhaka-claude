#!/usr/bin/env bash
# skeleton.sh — thin wrapper around skeleton.py for map-sync Step 2a.
# Writes .claude/.sync/skeleton.json (or, with --scatter D, prints the
# per-directory extract for the describe agent's scatter mode).
# Usage: bash skeleton.sh [project_root] [--scatter <dir>]   (default root: cwd)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 not found. map-sync requires python3." >&2
    exit 1
fi

python3 "$SCRIPT_DIR/skeleton.py" "$@"
