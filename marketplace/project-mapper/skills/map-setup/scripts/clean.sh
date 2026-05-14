#!/usr/bin/env bash
# clean.sh — remove scattered CLAUDE.md from subdirectories (root preserved)
# Usage: bash clean.sh [search_dir]   (default: .)
set -euo pipefail

SEARCH_DIR="${1:-.}"
ROOT_FILE="$(cd "$SEARCH_DIR" && pwd)/CLAUDE.md"

deleted=()
while IFS= read -r f; do
    abs="$(cd "$(dirname "$f")" && pwd)/$(basename "$f")"
    if [ "$abs" = "$ROOT_FILE" ]; then
        continue
    fi
    rm "$f"
    deleted+=("$f")
done < <(find "$SEARCH_DIR" -name "CLAUDE.md" -type f 2>/dev/null)

count=${#deleted[@]}
echo "Clean complete — deleted $count scattered CLAUDE.md file(s)."
for d in "${deleted[@]}"; do
    echo "  - $d"
done
if [ $count -eq 0 ]; then
    echo "  (none found)"
fi
