#!/usr/bin/env bash
#
# Local Deploy — development/testing only
#
# Copies marketplace plugin and standalone skills to ~/.claude/
# For production, use GitHub Marketplace.
#
# Usage:
#   scripts/deploy.sh              # deploy
#   scripts/deploy.sh --dry-run    # preview only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

PLUGIN_SRC="$REPO_DIR/marketplace/project-mapper"
SKILLS_SRC="$REPO_DIR/skills"
TEMPLATE_SRC="$REPO_DIR/templates/CLAUDE.md"
PLUGIN_JSON="$PLUGIN_SRC/.claude-plugin/plugin.json"

CLAUDE_DIR="$HOME/.claude"
PLUGIN_DST="$CLAUDE_DIR/plugins/project-mapper"
MARKETPLACE_DST="$CLAUDE_DIR/plugins/hukuhaka-plugin/project-mapper"
SKILLS_DST="$CLAUDE_DIR/skills"

DRY_RUN=false
SKIP_SKILLS="mcp-builder skill-creator"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        -h|--help)
            sed -n '3,9p' "$0"
            exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# Read version from plugin.json
VERSION=""
if command -v python3 &>/dev/null; then
    VERSION=$(python3 -c "import json; print(json.load(open('$PLUGIN_JSON'))['version'])" 2>/dev/null)
elif command -v jq &>/dev/null; then
    VERSION=$(jq -r '.version' "$PLUGIN_JSON" 2>/dev/null)
fi

echo "hukuhaka-claude deploy v${VERSION:-unknown}"
echo ""

# Choose copy command
COPY_CMD="cp -R"
if command -v rsync &>/dev/null; then
    COPY_CMD="rsync -a --delete"
fi

deploy_dir() {
    local src="$1" dst="$2" label="$3"
    if [ ! -d "$src" ]; then
        echo "  [skip] $label — source not found: $src"
        return
    fi

    if $DRY_RUN; then
        echo "  [dry-run] $label: $src → $dst"
        return
    fi

    mkdir -p "$dst"
    if [[ "$COPY_CMD" == rsync* ]]; then
        $COPY_CMD "$src/" "$dst/"
    else
        rm -rf "$dst"
        $COPY_CMD "$src" "$dst"
    fi
    echo "  [ok] $label → $dst"
}

# 0. Clear plugin cache (stale cached versions override local deploy)
CACHE_DIR="$CLAUDE_DIR/plugins/cache"
if [ -d "$CACHE_DIR" ]; then
    if $DRY_RUN; then
        echo "Cache:"
        echo "  [dry-run] Would remove $CACHE_DIR"
    else
        echo "Cache:"
        rm -rf "$CACHE_DIR"
        echo "  [ok] Cleared $CACHE_DIR"
    fi
    echo ""
fi

# 1. Deploy plugin
echo "Plugin:"
deploy_dir "$PLUGIN_SRC" "$PLUGIN_DST" "project-mapper"

# 1b. Deploy to marketplace source (Claude Code loads from here)
if [ -d "$(dirname "$MARKETPLACE_DST")" ]; then
    deploy_dir "$PLUGIN_SRC" "$MARKETPLACE_DST" "project-mapper (marketplace)"
fi

# 2. Deploy standalone skills
echo ""
echo "Standalone skills:"
for skill_dir in "$SKILLS_SRC"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name="$(basename "$skill_dir")"
    if [[ " $SKIP_SKILLS " == *" $skill_name "* ]]; then
        echo "  [skip] $skill_name — excluded from public deploy"
        continue
    fi
    deploy_dir "$skill_dir" "$SKILLS_DST/$skill_name" "$skill_name"
done

# 3. Deploy CLAUDE.md template
echo ""
echo "Template:"
if [ -f "$TEMPLATE_SRC" ]; then
    if $DRY_RUN; then
        echo "  [dry-run] CLAUDE.md: $TEMPLATE_SRC → $CLAUDE_DIR/CLAUDE.md"
    else
        cp "$TEMPLATE_SRC" "$CLAUDE_DIR/CLAUDE.md"
        echo "  [ok] CLAUDE.md → $CLAUDE_DIR/CLAUDE.md"
    fi
else
    echo "  [skip] CLAUDE.md — source not found: $TEMPLATE_SRC"
fi

echo ""
if $DRY_RUN; then
    echo "Dry run complete. No files were modified."
else
    echo "Deploy complete. v${VERSION:-unknown}"
fi
