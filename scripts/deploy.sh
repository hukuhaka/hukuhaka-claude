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

MARKETPLACE_NAME="hukuhaka-plugin"
PLUGIN_NAME="project-mapper"
PLUGIN_KEY="${PLUGIN_NAME}@${MARKETPLACE_NAME}"

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

# ── Plugin registration ──────────────────────────────────────────────
#
# Ensures project-mapper is registered as a plugin in Claude Code's
# marketplace system (settings.json, installed_plugins.json, known_marketplaces.json).

ensure_plugin_registered() {
    local version="$1"
    local settings="$CLAUDE_DIR/settings.json"
    local installed="$CLAUDE_DIR/plugins/installed_plugins.json"
    local known="$CLAUDE_DIR/plugins/known_marketplaces.json"
    local mkt_dir="$CLAUDE_DIR/plugins/$MARKETPLACE_NAME"
    local now
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    echo ""
    echo "Plugin registration:"

    if $DRY_RUN; then
        echo "  [dry-run] would register $PLUGIN_KEY in settings/installed/known"
        return 0
    fi

    if command -v python3 &>/dev/null; then
        python3 -c "
import json,sys,os

claude_dir=sys.argv[1]
mkt_name=sys.argv[2]
plugin_key=sys.argv[3]
version=sys.argv[4]
now=sys.argv[5]
mkt_dir=sys.argv[6]

# settings.json
sf=os.path.join(claude_dir,'settings.json')
if os.path.isfile(sf):
    with open(sf) as f: s=json.load(f)
else:
    s={}
changed=False
ep=s.setdefault('enabledPlugins',{})
if plugin_key not in ep:
    ep[plugin_key]=True; changed=True
ekm=s.setdefault('extraKnownMarketplaces',{})
if mkt_name not in ekm:
    ekm[mkt_name]={'source':{'source':'directory','path':mkt_dir}}; changed=True
if changed:
    with open(sf,'w') as f: json.dump(s,f,indent=2); f.write('\n')
    print('  [ok] settings.json')
else:
    print('  [ok] settings.json (no change)')

# installed_plugins.json
ip=os.path.join(claude_dir,'plugins','installed_plugins.json')
if os.path.isfile(ip):
    with open(ip) as f: d=json.load(f)
else:
    d={'version':2,'plugins':{}}
plugins=d.setdefault('plugins',{})
entry={'scope':'user','installPath':os.path.join(mkt_dir,'project-mapper'),'version':version,'installedAt':now,'lastUpdated':now}
existing=plugins.get(plugin_key,[])
if existing:
    existing[0]['version']=version
    existing[0]['lastUpdated']=now
    existing[0]['installPath']=entry['installPath']
else:
    plugins[plugin_key]=[entry]
with open(ip,'w') as f: json.dump(d,f,indent=2); f.write('\n')
print('  [ok] installed_plugins.json')

# known_marketplaces.json
kf=os.path.join(claude_dir,'plugins','known_marketplaces.json')
if os.path.isfile(kf):
    with open(kf) as f: k=json.load(f)
else:
    k={}
if mkt_name not in k:
    k[mkt_name]={'source':{'source':'directory','path':mkt_dir},'installLocation':mkt_dir,'lastUpdated':now}
    with open(kf,'w') as f: json.dump(k,f,indent=2); f.write('\n')
    print('  [ok] known_marketplaces.json')
else:
    print('  [ok] known_marketplaces.json (no change)')
" "$CLAUDE_DIR" "$MARKETPLACE_NAME" "$PLUGIN_KEY" "$version" "$now" "$mkt_dir"
    elif command -v jq &>/dev/null; then
        # settings.json
        if [ -f "$settings" ]; then
            jq --arg pk "$PLUGIN_KEY" --arg mn "$MARKETPLACE_NAME" --arg mp "$mkt_dir" \
                '.enabledPlugins[$pk] = true
                 | .extraKnownMarketplaces[$mn] = {"source":{"source":"directory","path":$mp}}' \
                "$settings" > "$settings.tmp"
            mv "$settings.tmp" "$settings"
        else
            jq -n --arg pk "$PLUGIN_KEY" --arg mn "$MARKETPLACE_NAME" --arg mp "$mkt_dir" \
                '{enabledPlugins:{($pk):true},extraKnownMarketplaces:{($mn):{"source":{"source":"directory","path":$mp}}}}' \
                > "$settings"
        fi
        echo "  [ok] settings.json"

        # installed_plugins.json
        local install_path="$mkt_dir/$PLUGIN_NAME"
        if [ -f "$installed" ]; then
            jq --arg pk "$PLUGIN_KEY" --arg v "$version" --arg t "$now" --arg ip "$install_path" \
                '.plugins[$pk] = [{"scope":"user","installPath":$ip,"version":$v,"installedAt":$t,"lastUpdated":$t}]' \
                "$installed" > "$installed.tmp"
            mv "$installed.tmp" "$installed"
        else
            mkdir -p "$(dirname "$installed")"
            jq -n --arg pk "$PLUGIN_KEY" --arg v "$version" --arg t "$now" --arg ip "$install_path" \
                '{version:2,plugins:{($pk):[{"scope":"user","installPath":$ip,"version":$v,"installedAt":$t,"lastUpdated":$t}]}}' \
                > "$installed"
        fi
        echo "  [ok] installed_plugins.json"

        # known_marketplaces.json
        if [ -f "$known" ]; then
            jq --arg mn "$MARKETPLACE_NAME" --arg mp "$mkt_dir" --arg t "$now" \
                '.[$mn] //= {"source":{"source":"directory","path":$mp},"installLocation":$mp,"lastUpdated":$t}' \
                "$known" > "$known.tmp"
            mv "$known.tmp" "$known"
        else
            jq -n --arg mn "$MARKETPLACE_NAME" --arg mp "$mkt_dir" --arg t "$now" \
                '{($mn):{"source":{"source":"directory","path":$mp},"installLocation":$mp,"lastUpdated":$t}}' \
                > "$known"
        fi
        echo "  [ok] known_marketplaces.json"
    fi
}

# ── Unregister plugin ────────────────────────────────────────────────

unregister_plugin() {
    local settings="$CLAUDE_DIR/settings.json"
    local installed="$CLAUDE_DIR/plugins/installed_plugins.json"
    local known="$CLAUDE_DIR/plugins/known_marketplaces.json"

    echo ""
    echo "Unregistering plugin:"

    if $DRY_RUN; then
        echo "  [dry-run] would remove $PLUGIN_KEY from settings/installed/known"
        return 0
    fi

    if command -v python3 &>/dev/null; then
        python3 -c "
import json,sys,os
claude_dir=sys.argv[1]
mkt_name=sys.argv[2]
plugin_key=sys.argv[3]

for name,path,action in [
    ('settings.json', os.path.join(claude_dir,'settings.json'), 'settings'),
    ('installed_plugins.json', os.path.join(claude_dir,'plugins','installed_plugins.json'), 'installed'),
    ('known_marketplaces.json', os.path.join(claude_dir,'plugins','known_marketplaces.json'), 'known'),
]:
    if not os.path.isfile(path): continue
    with open(path) as f: d=json.load(f)
    changed=False
    if action=='settings':
        ep=d.get('enabledPlugins',{})
        if plugin_key in ep: del ep[plugin_key]; changed=True
        if not ep and 'enabledPlugins' in d: del d['enabledPlugins']; changed=True
        ekm=d.get('extraKnownMarketplaces',{})
        if mkt_name in ekm: del ekm[mkt_name]; changed=True
        if not ekm and 'extraKnownMarketplaces' in d: del d['extraKnownMarketplaces']; changed=True
    elif action=='installed':
        plugins=d.get('plugins',{})
        if plugin_key in plugins: del plugins[plugin_key]; changed=True
    elif action=='known':
        if mkt_name in d: del d[mkt_name]; changed=True
    if changed:
        with open(path,'w') as f: json.dump(d,f,indent=2); f.write('\n')
        print(f'  [ok] {name}')
" "$CLAUDE_DIR" "$MARKETPLACE_NAME" "$PLUGIN_KEY"
    elif command -v jq &>/dev/null; then
        if [ -f "$settings" ] && grep -q "$MARKETPLACE_NAME" "$settings" 2>/dev/null; then
            jq --arg pk "$PLUGIN_KEY" --arg mn "$MARKETPLACE_NAME" \
                'del(.enabledPlugins[$pk]) | if .enabledPlugins == {} then del(.enabledPlugins) else . end
                 | del(.extraKnownMarketplaces[$mn]) | if .extraKnownMarketplaces == {} then del(.extraKnownMarketplaces) else . end' \
                "$settings" > "$settings.tmp"
            mv "$settings.tmp" "$settings"
            echo "  [ok] settings.json"
        fi
        if [ -f "$installed" ]; then
            jq --arg pk "$PLUGIN_KEY" 'del(.plugins[$pk])' "$installed" > "$installed.tmp"
            mv "$installed.tmp" "$installed"
            echo "  [ok] installed_plugins.json"
        fi
        if [ -f "$known" ]; then
            jq --arg mn "$MARKETPLACE_NAME" 'del(.[$mn])' "$known" > "$known.tmp"
            mv "$known.tmp" "$known"
            echo "  [ok] known_marketplaces.json"
        fi
    fi

    # Remove cache
    if [ -d "$CLAUDE_DIR/plugins/cache/$MARKETPLACE_NAME" ]; then
        rm -rf "$CLAUDE_DIR/plugins/cache/$MARKETPLACE_NAME"
        echo "  [ok] removed cache/$MARKETPLACE_NAME"
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

    unregister_plugin

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

# Plugin — deploy to marketplace path
[ -d "$PLUGIN_SRC" ] && collect "$PLUGIN_SRC" "plugins/$MARKETPLACE_NAME/$PLUGIN_NAME"

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
    for scan_dir in "$CLAUDE_DIR/plugins/project-mapper" "$CLAUDE_DIR/plugins/$MARKETPLACE_NAME/$PLUGIN_NAME"; do
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
        plugins/$MARKETPLACE_NAME/$PLUGIN_NAME/*)
            echo "$PLUGIN_SRC/${rel#plugins/$MARKETPLACE_NAME/$PLUGIN_NAME/}" ;;
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

# ── Generate marketplace manifest ────────────────────────────────────

generate_marketplace_manifest() {
    local mkt_manifest="$CLAUDE_DIR/plugins/$MARKETPLACE_NAME/.claude-plugin/marketplace.json"
    local version="${VERSION:-unknown}"

    if $DRY_RUN; then
        echo "  [dry-run] marketplace.json"
        return 0
    fi

    mkdir -p "$(dirname "$mkt_manifest")"
    if command -v python3 &>/dev/null; then
        python3 -c "
import json,sys
d={
    'name':sys.argv[1],
    'description':'Codebase analysis and .claude/ documentation generation',
    'owner':{'name':'hukuhaka'},
    'plugins':[{
        'name':sys.argv[2],
        'description':'Codebase analysis and .claude/ documentation generation',
        'version':sys.argv[3],
        'author':{'name':'hukuhaka'},
        'source':'./'+sys.argv[2]
    }]
}
with open(sys.argv[4],'w') as f: json.dump(d,f,indent=2); f.write('\n')
" "$MARKETPLACE_NAME" "$PLUGIN_NAME" "$version" "$mkt_manifest"
    elif command -v jq &>/dev/null; then
        jq -n --arg mn "$MARKETPLACE_NAME" --arg pn "$PLUGIN_NAME" --arg v "$version" \
            '{name:$mn,description:"Codebase analysis and .claude/ documentation generation",
              owner:{name:"hukuhaka"},
              plugins:[{name:$pn,description:"Codebase analysis and .claude/ documentation generation",
                        version:$v,author:{name:"hukuhaka"},source:("./"+$pn)}]}' \
            > "$mkt_manifest"
    fi

    # Add to file list for manifest tracking
    echo "plugins/$MARKETPLACE_NAME/.claude-plugin/marketplace.json" >> "$NEW_LIST"
    sort -o "$NEW_LIST" "$NEW_LIST"
    echo "  [ok] marketplace.json"
}

generate_marketplace_manifest

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

# ── Remove standalone path (migration) ───────────────────────────────

if [ -d "$CLAUDE_DIR/plugins/$PLUGIN_NAME" ] && ! $DRY_RUN; then
    echo ""
    echo "Removing standalone plugins/$PLUGIN_NAME:"
    rm -rf "$CLAUDE_DIR/plugins/$PLUGIN_NAME"
    echo "  [ok] removed"
fi

# ── Invalidate cache ─────────────────────────────────────────────────

if ! $DRY_RUN && [ -d "$CLAUDE_DIR/plugins/cache/$MARKETPLACE_NAME" ]; then
    rm -rf "$CLAUDE_DIR/plugins/cache/$MARKETPLACE_NAME"
    echo "  [ok] cache invalidated"
fi

# ── Register plugin ──────────────────────────────────────────────────

ensure_plugin_registered "${VERSION:-unknown}"

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
