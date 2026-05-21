#!/usr/bin/env bash
# init.sh — create .claude/ with 4 template files
# Usage: bash init.sh [target_dir]   (default: .claude)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/../templates"
TARGET_DIR="${1:-.claude}"

if [ ! -d "$TEMPLATES_DIR" ]; then
    echo "ERROR: templates directory not found: $TEMPLATES_DIR" >&2
    exit 1
fi

mkdir -p "$TARGET_DIR"

files=(map.md design.md backlog.md changelog.md)
for f in "${files[@]}"; do
    src="$TEMPLATES_DIR/$f"
    dst="$TARGET_DIR/$f"
    if [ ! -f "$src" ]; then
        echo "ERROR: template missing: $src" >&2
        exit 1
    fi
    cp "$src" "$dst"
done

echo "Init complete — created $TARGET_DIR/ with 4 template files."
echo "  - $TARGET_DIR/map.md (sections: Entry Points, Data Flow, Components, Structure)"
echo "  - $TARGET_DIR/design.md (sections: Stack, Patterns, Decisions)"
echo "  - $TARGET_DIR/backlog.md (sections: ## Planned, ## In Progress, ## Discovered TODOs)"
echo "  - $TARGET_DIR/changelog.md (sections: Recent, Archive)"
echo ""
echo "Run \`/hukuhaka-project-mapper:map-spec generate\` to create spec.md."
