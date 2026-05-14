#!/usr/bin/env bash
# preflight.sh — load backlog.md (required) + map/design (optional) for context
# Usage: bash preflight.sh [target_dir]   (default: .claude)
#
# Exits 1 if backlog.md is missing — caller must STOP and tell user to
# run /project-mapper:map-init.
set -euo pipefail

TARGET_DIR="${1:-.claude}"
BACKLOG="$TARGET_DIR/backlog.md"

if [ ! -f "$BACKLOG" ]; then
    echo "Preflight: $BACKLOG not found — run /project-mapper:map-init first"
    exit 1
fi

echo "===== $BACKLOG ====="
cat "$BACKLOG"
echo ""

for f in map.md design.md; do
    path="$TARGET_DIR/$f"
    if [ -f "$path" ]; then
        echo "===== $path ====="
        cat "$path"
        echo ""
    fi
done

echo "Preflight: backlog.md loaded; context complete."
