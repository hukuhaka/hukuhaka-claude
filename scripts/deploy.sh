#!/usr/bin/env bash
#
# hukuhaka-claude deploy — manifest-based
#
# Tracks installed files in ~/.claude/.hukuhaka-manifest.json
# Only removes files it deployed; safe alongside other plugins.
#
# Usage:
#   scripts/deploy.sh                     # deploy
#   scripts/deploy.sh --dry-run           # preview only
#   scripts/deploy.sh --uninstall         # remove deployed files
#   scripts/deploy.sh --uninstall --force # remove without confirmation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

PLUGIN_SRC="$REPO_DIR/marketplace/project-mapper"
SKILLS_SRC="$REPO_DIR/skills"
TEMPLATE_SRC="$REPO_DIR/templates/CLAUDE.md"
PLUGIN_JSON="$PLUGIN_SRC/.claude-plugin/plugin.json"

CLAUDE_DIR="$HOME/.claude"
MANIFEST="$CLAUDE_DIR/.hukuhaka-manifest.json"

DRY_RUN=false
UNINSTALL=false
FORCE=false
SKIP_SKILLS="mcp-builder skill-creator"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --uninstall) UNINSTALL=true; shift ;;
        --force) FORCE=true; shift ;;
        -h|--help)
            sed -n '3,13p' "$0"
            exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# ── Prereq check ──────────────────────────────────────────────────────

if ! command -v python3 &>/dev/null && ! command -v jq &>/dev/null; then
    echo "Error: python3 or jq is required." >&2
    exit 1
fi

# ── JSON helpers ──────────────────────────────────────────────────────

read_version() {
    local file="$1"
    if command -v python3 &>/dev/null; then
        python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['version'])" "$file" 2>/dev/null || true
    elif command -v jq &>/dev/null; then
        jq -r '.version' "$file" 2>/dev/null || true
    fi
}

manifest_files() {
    [ -f "$MANIFEST" ] || return 0
    if command -v python3 &>/dev/null; then
        python3 -c "
import json,sys
m=json.load(open(sys.argv[1]))
for f in m.get('files',[]):
    print(f)
" "$MANIFEST"
    elif command -v jq &>/dev/null; then
        jq -r '.files[]' "$MANIFEST"
    fi
}

manifest_write() {
    local version="$1" file_list="$2"
    mkdir -p "$(dirname "$MANIFEST")"
    if command -v python3 &>/dev/null; then
        python3 -c "
import json,sys,datetime
version=sys.argv[1]
with open(sys.argv[2]) as f:
    files=sorted(line.strip() for line in f if line.strip())
data={'version':version,'timestamp':datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),'files':files}
with open(sys.argv[3],'w') as out:
    json.dump(data,out,indent=2)
    out.write('\n')
" "$version" "$file_list" "$MANIFEST"
    elif command -v jq &>/dev/null; then
        jq -R -s --arg v "$version" --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '{version:$v,timestamp:$t,files:(split("\n")|map(select(length>0))|sort)}' \
            < "$file_list" > "$MANIFEST.tmp"
        mv "$MANIFEST.tmp" "$MANIFEST"
    fi
}

# ── Version ───────────────────────────────────────────────────────────

VERSION=""
if [ -f "$PLUGIN_JSON" ]; then
    VERSION=$(read_version "$PLUGIN_JSON")
fi

echo "hukuhaka-claude v${VERSION:-unknown}"
echo ""

# ── Uninstall ─────────────────────────────────────────────────────────

if $UNINSTALL; then
    if [ ! -f "$MANIFEST" ]; then
        echo "No manifest found — nothing to uninstall."
        exit 0
    fi

    if ! $FORCE && ! $DRY_RUN; then
        echo "This will remove all hukuhaka-claude files from $CLAUDE_DIR."
        printf "Continue? [y/N] "
        read -r answer
        [[ "$answer" =~ ^[Yy] ]] || { echo "Aborted."; exit 1; }
    fi

    echo "Uninstalling:"
    count=0
    while IFS= read -r rel; do
        [ -z "$rel" ] && continue
        target="$CLAUDE_DIR/$rel"
        if [ -f "$target" ]; then
            if $DRY_RUN; then
                echo "  [dry-run] rm $rel"
            else
                rm "$target"
                echo "  [ok] rm $rel"
            fi
            count=$((count + 1))
        fi
    done < <(manifest_files)

    if ! $DRY_RUN; then
        find "$CLAUDE_DIR/plugins" "$CLAUDE_DIR/skills" -type d -empty -delete 2>/dev/null || true
        rm -f "$MANIFEST"
    fi

    echo ""
    if $DRY_RUN; then
        echo "Dry run — no files modified."
    else
        echo "Uninstalled $count files."
    fi
    exit 0
fi

# ── Temp files ────────────────────────────────────────────────────────

NEW_LIST=$(mktemp)
OLD_LIST=$(mktemp)
STALE_LIST=$(mktemp)
cleanup() { rm -f "$NEW_LIST" "$OLD_LIST" "$STALE_LIST"; }
trap cleanup EXIT

# ── Build new file list ──────────────────────────────────────────────

collect() {
    local src_root="${1%/}" dst_prefix="$2"
    find "$src_root" -type f | while IFS= read -r file; do
        echo "$dst_prefix/${file#"$src_root"/}"
    done >> "$NEW_LIST"
}

# Plugin
[ -d "$PLUGIN_SRC" ] && collect "$PLUGIN_SRC" "plugins/project-mapper"

# Marketplace overlay (only if already installed via marketplace)
MARKETPLACE_PARENT="$CLAUDE_DIR/plugins/hukuhaka-plugin"
if [ -d "$MARKETPLACE_PARENT" ]; then
    collect "$PLUGIN_SRC" "plugins/hukuhaka-plugin/project-mapper"
fi

# Standalone skills
for skill_dir in "$SKILLS_SRC"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name="$(basename "$skill_dir")"
    [[ " $SKIP_SKILLS " == *" $skill_name "* ]] && continue
    collect "$skill_dir" "skills/$skill_name"
done

# Template
[ -f "$TEMPLATE_SRC" ] && echo "CLAUDE.md" >> "$NEW_LIST"

# ── Load old manifest & sort ─────────────────────────────────────────

manifest_files | sort > "$OLD_LIST"
sort -o "$NEW_LIST" "$NEW_LIST"

# ── Deploy files ──────────────────────────────────────────────────────

resolve_src() {
    local rel="$1"
    case "$rel" in
        plugins/project-mapper/*)
            echo "$PLUGIN_SRC/${rel#plugins/project-mapper/}" ;;
        plugins/hukuhaka-plugin/project-mapper/*)
            echo "$PLUGIN_SRC/${rel#plugins/hukuhaka-plugin/project-mapper/}" ;;
        skills/*/*)
            echo "$SKILLS_SRC/${rel#skills/}" ;;
        CLAUDE.md)
            echo "$TEMPLATE_SRC" ;;
    esac
}

echo "Deploying:"
count=0
while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    src=$(resolve_src "$rel")
    dst="$CLAUDE_DIR/$rel"
    if [ -z "$src" ] || [ ! -f "$src" ]; then
        continue
    fi
    if $DRY_RUN; then
        echo "  [dry-run] $rel"
    else
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
    fi
    count=$((count + 1))
done < "$NEW_LIST"
echo "  $count files"

# ── Remove stale files ───────────────────────────────────────────────

comm -23 "$OLD_LIST" "$NEW_LIST" > "$STALE_LIST"

if [ -s "$STALE_LIST" ]; then
    echo ""
    echo "Removing stale:"
    while IFS= read -r rel; do
        [ -z "$rel" ] && continue
        target="$CLAUDE_DIR/$rel"
        if [ -f "$target" ]; then
            if $DRY_RUN; then
                echo "  [dry-run] rm $rel"
            else
                rm "$target"
                echo "  [ok] rm $rel"
            fi
        fi
    done < "$STALE_LIST"
fi

# ── Clean empty directories ──────────────────────────────────────────

if ! $DRY_RUN; then
    find "$CLAUDE_DIR/plugins" "$CLAUDE_DIR/skills" -type d -empty -delete 2>/dev/null || true
fi

# ── Write manifest ────────────────────────────────────────────────────

if ! $DRY_RUN; then
    manifest_write "${VERSION:-unknown}" "$NEW_LIST"
fi

echo ""
if $DRY_RUN; then
    echo "Dry run complete. No files were modified."
else
    echo "Deploy complete. v${VERSION:-unknown} ($count files)"
fi
