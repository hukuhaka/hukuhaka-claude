#!/usr/bin/env bash
# merge.sh — thin wrapper around merge.py for map-sync Step 2 (merge).
# Reads {"describe": ..., "synth": ...} on stdin, emits the 9-field JSON.
# Usage: bash merge.sh [project_root] < combined.json   (default root: cwd)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 not found. map-sync requires python3." >&2
    exit 1
fi

python3 "$SCRIPT_DIR/merge.py" "$@"
