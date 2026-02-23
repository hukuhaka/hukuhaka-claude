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

# ── Marketplace migration helper ─────────────────────────────────────
#
# Old installs registered hukuhaka-plugin as a marketplace in Claude Code.
# This removes those entries so only plugins/project-mapper/ is used.

cleanup_marketplace() {
    local installed="$CLAUDE_DIR/plugins/installed_plugins.json"
    local known="$CLAUDE_DIR/plugins/known_marketplaces.json"

    # Check if cleanup is needed
    local needed=false
    [ -d "$CLAUDE_DIR/plugins/hukuhaka-plugin" ] && needed=true
    [ -d "$CLAUDE_DIR/plugins/cache/hukuhaka-plugin" ] && needed=true
    [ -f "$installed" ] && grep -q "hukuhaka-plugin" "$installed" 2>/dev/null && needed=true
    [ -f "$known" ] && grep -q "hukuhaka-plugin" "$known" 2>/dev/null && needed=true

    $needed || return 0

    echo ""
    echo "Cleaning up hukuhaka-plugin marketplace:"

    if $DRY_RUN; then
        echo "  [dry-run] would clean installed_plugins.json, known_marketplaces.json, cache"
        return 0
    fi

    if command -v python3 &>/dev/null; then
        [ -f "$installed" ] && python3 -c "
import json,sys
f=sys.argv[1]
with open(f) as fh: d=json.load(fh)
plugins=d.get('plugins',{})
keys=[k for k in plugins if 'hukuhaka-plugin' in k]
if not keys: sys.exit(0)
for k in keys: del plugins[k]
with open(f,'w') as fh: json.dump(d,fh,indent=2); fh.write('\n')
print('  [ok] cleaned installed_plugins.json')
" "$installed" 2>/dev/null || true

        [ -f "$known" ] && python3 -c "
import json,sys
f=sys.argv[1]
with open(f) as fh: d=json.load(fh)
if 'hukuhaka-plugin' not in d: sys.exit(0)
del d['hukuhaka-plugin']
with open(f,'w') as fh: json.dump(d,fh,indent=2); fh.write('\n')
print('  [ok] cleaned known_marketplaces.json')
" "$known" 2>/dev/null || true
    elif command -v jq &>/dev/null; then
        if [ -f "$installed" ] && jq -e '.plugins | keys[] | select(contains("hukuhaka-plugin"))' "$installed" &>/dev/null; then
            jq '.plugins |= with_entries(select(.key | contains("hukuhaka-plugin") | not))' "$installed" > "$installed.tmp"
            mv "$installed.tmp" "$installed"
            echo "  [ok] cleaned installed_plugins.json"
        fi
        if [ -f "$known" ] && jq -e '.["hukuhaka-plugin"]' "$known" &>/dev/null; then
            jq 'del(.["hukuhaka-plugin"])' "$known" > "$known.tmp"
            mv "$known.tmp" "$known"
            echo "  [ok] cleaned known_marketplaces.json"
        fi
    fi

    if [ -d "$CLAUDE_DIR/plugins/cache/hukuhaka-plugin" ]; then
        rm -rf "$CLAUDE_DIR/plugins/cache/hukuhaka-plugin"
        echo "  [ok] removed cache/hukuhaka-plugin"
    fi

    if [ -d "$CLAUDE_DIR/plugins/hukuhaka-plugin" ]; then
        rm -rf "$CLAUDE_DIR/plugins/hukuhaka-plugin"
        echo "  [ok] removed plugins/hukuhaka-plugin"
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

    cleanup_marketplace

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

# Standalone skills
for skill_dir in "$SKILLS_SRC"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name="$(basename "$skill_dir")"
    [[ " $SKIP_SKILLS " == *" $skill_name "* ]] && continue
    collect "$skill_dir" "skills/$skill_name"
done

# Template
[ -f "$TEMPLATE_SRC" ] && echo "CLAUDE.md" >> "$NEW_LIST"

# ── Load old manifest (or scan for migration) ───────────────────────

if [ -f "$MANIFEST" ]; then
    manifest_files | sort > "$OLD_LIST"
else
    # First manifest-based deploy: scan existing dirs to detect stale files
    for scan_dir in "$CLAUDE_DIR/plugins/project-mapper" "$CLAUDE_DIR/plugins/hukuhaka-plugin/project-mapper"; do
        [ -d "$scan_dir" ] || continue
        find "$scan_dir" -type f | while IFS= read -r file; do
            echo "${file#"$CLAUDE_DIR"/}"
        done
    done | sort > "$OLD_LIST"
    [ -s "$OLD_LIST" ] && echo "Migrating from pre-manifest install..."
fi

sort -o "$NEW_LIST" "$NEW_LIST"

# ── Deploy files ──────────────────────────────────────────────────────

resolve_src() {
    local rel="$1"
    case "$rel" in
        plugins/project-mapper/*)
            echo "$PLUGIN_SRC/${rel#plugins/project-mapper/}" ;;
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

# ── Marketplace migration ────────────────────────────────────────────

cleanup_marketplace

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
