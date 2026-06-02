#!/usr/bin/env bash
# preflight.sh — load .claude/ docs into stdout for orchestrator context
# Usage: bash preflight.sh [target_dir]   (default: .claude)
set -euo pipefail

TARGET_DIR="${1:-.claude}"

if [ ! -d "$TARGET_DIR" ]; then
    echo "Preflight: $TARGET_DIR does not exist (no .claude/ initialized yet)"
    exit 0
fi

loaded=0
for f in map.md design.md spec.md scan.md; do
    path="$TARGET_DIR/$f"
    if [ -f "$path" ]; then
        echo "===== $path ====="
        cat "$path"
        echo ""
        loaded=$((loaded + 1))
    fi
done

echo "Preflight: loaded $loaded .claude/ doc(s) from $TARGET_DIR (map.md, design.md, spec.md, scan.md if present)"
