#!/usr/bin/env bash
# scan.sh — thin wrapper around scan.py for shell-based invocation
# Usage: bash scan.sh [project_root]   (default: cwd)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 not found. map-scan requires python3." >&2
    exit 1
fi

python3 "$SCRIPT_DIR/scan.py" "$@"
