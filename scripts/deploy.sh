#!/usr/bin/env bash
#
# hukuhaka-claude deploy — manifest-based
#
# Tracks installed files in ~/.claude/.hukuhaka-manifest.json
# Only removes files it deployed; safe alongside other plugins.
#
# Usage:
#   scripts/deploy.sh                          # deploy everything
#   scripts/deploy.sh --components a,b,c       # deploy only listed components
#   scripts/deploy.sh --dry-run                # preview only
#   scripts/deploy.sh --uninstall              # remove deployed files
#   scripts/deploy.sh --uninstall --force      # remove without confirmation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

MARKETPLACE_DIR="$REPO_DIR/marketplace"
SKILLS_SRC="$REPO_DIR/skills"
TEMPLATE_SRC="$REPO_DIR/templates/CLAUDE.md"

CLAUDE_DIR="$HOME/.claude"
MANIFEST="$CLAUDE_DIR/.hukuhaka-manifest.json"

MARKETPLACE_NAME="hukuhaka-plugin"

# ── Plugin discovery (every marketplace/<name>/.claude-plugin/plugin.json) ──
PLUGIN_NAMES=()
for plugin_dir in "$MARKETPLACE_DIR"/*/; do
    [ -f "$plugin_dir/.claude-plugin/plugin.json" ] || continue
    PLUGIN_NAMES+=("$(basename "${plugin_dir%/}")")
done
if [ "${#PLUGIN_NAMES[@]}" -eq 0 ]; then
    echo "Error: no plugins found under $MARKETPLACE_DIR" >&2
    exit 1
fi

# Project-level version source: /VERSION file at repo root. Independent
# of any individual plugin's plugin.json — plugins track their own
# lifecycles, this file tracks the install/deploy bundle as a whole.
PROJECT_VERSION_FILE="$REPO_DIR/VERSION"

plugin_src() { echo "$MARKETPLACE_DIR/$1"; }
plugin_json() { echo "$MARKETPLACE_DIR/$1/.claude-plugin/plugin.json"; }
plugin_key() { echo "$1@$MARKETPLACE_NAME"; }
plugin_install_path() { echo "$CLAUDE_DIR/plugins/$MARKETPLACE_NAME/$1"; }

DRY_RUN=false
UNINSTALL=false
FORCE=false
COMPONENTS=""
COMPONENTS_PROVIDED=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --uninstall) UNINSTALL=true; shift ;;
        --force) FORCE=true; shift ;;
        --components) COMPONENTS="$2"; COMPONENTS_PROVIDED=true; shift 2 ;;
        -h|--help)
            sed -n '3,13p' "$0"
            exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# ── Component selection helpers ──────────────────────────────────────
# When COMPONENTS_PROVIDED=true, only items whose canonical name appears
# in COMPONENTS (csv) are deployed. When false, everything is installed.
#
# Canonical names:
#   plugins  : as-discovered from marketplace/<name>/
#   skills   : as-discovered from skills/<name>/
#   features : statusline, agent-teams
#   template : claude-md
has_component() {
    local name="$1"
    if ! $COMPONENTS_PROVIDED; then return 0; fi
    [[ ",${COMPONENTS}," == *",${name},"* ]]
}

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
    local version="$1" file_list="$2" components_csv="${3:-}"
    mkdir -p "$(dirname "$MANIFEST")"
    if command -v python3 &>/dev/null; then
        python3 -c "
import json,sys,datetime
version=sys.argv[1]
with open(sys.argv[2]) as f:
    files=sorted(line.strip() for line in f if line.strip())
components_csv=sys.argv[4]
components=[c for c in components_csv.split(',') if c]
data={'version':version,'timestamp':datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),'components':sorted(components),'files':files}
with open(sys.argv[3],'w') as out:
    json.dump(data,out,indent=2)
    out.write('\n')
" "$version" "$file_list" "$MANIFEST" "$components_csv"
    elif command -v jq &>/dev/null; then
        local comp_json
        comp_json=$(printf '%s' "$components_csv" | tr ',' '\n' | jq -R -s 'split("\n")|map(select(length>0))|sort')
        jq -R -s --arg v "$version" --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson c "$comp_json" \
            '{version:$v,timestamp:$t,components:$c,files:(split("\n")|map(select(length>0))|sort)}' \
            < "$file_list" > "$MANIFEST.tmp"
        mv "$MANIFEST.tmp" "$MANIFEST"
    fi
}

manifest_components() {
    [ -f "$MANIFEST" ] || return 0
    if command -v python3 &>/dev/null; then
        python3 -c "
import json,sys
m=json.load(open(sys.argv[1]))
for c in m.get('components',[]):
    print(c)
" "$MANIFEST" 2>/dev/null
    elif command -v jq &>/dev/null; then
        jq -r '.components[]?' "$MANIFEST" 2>/dev/null
    fi
}

# ── Plugin registration ──────────────────────────────────────────────
#
# Ensures project-mapper is registered as a plugin in Claude Code's
# marketplace system (settings.json, installed_plugins.json, known_marketplaces.json).

ensure_plugin_registered() {
    local plugin_name="$1"
    local version="$2"
    local plugin_key
    plugin_key="$(plugin_key "$plugin_name")"
    local settings="$CLAUDE_DIR/settings.json"
    local installed="$CLAUDE_DIR/plugins/installed_plugins.json"
    local known="$CLAUDE_DIR/plugins/known_marketplaces.json"
    local mkt_dir="$CLAUDE_DIR/plugins/$MARKETPLACE_NAME"
    local now
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    if $DRY_RUN; then
        echo "  [dry-run] would register $plugin_key in settings/installed/known"
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
plugin_name=sys.argv[7]
entry={'scope':'user','installPath':os.path.join(mkt_dir,plugin_name),'version':version,'installedAt':now,'lastUpdated':now}
existing=plugins.get(plugin_key,[])
if existing:
    existing[0]['version']=version
    existing[0]['lastUpdated']=now
    existing[0]['installPath']=entry['installPath']
else:
    plugins[plugin_key]=[entry]
with open(ip,'w') as f: json.dump(d,f,indent=2); f.write('\n')
print('  [ok] installed_plugins.json (' + plugin_key + ')')

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
    pass
" "$CLAUDE_DIR" "$MARKETPLACE_NAME" "$plugin_key" "$version" "$now" "$mkt_dir" "$plugin_name"
    elif command -v jq &>/dev/null; then
        # settings.json
        if [ -f "$settings" ]; then
            jq --arg pk "$plugin_key" --arg mn "$MARKETPLACE_NAME" --arg mp "$mkt_dir" \
                '.enabledPlugins[$pk] = true
                 | .extraKnownMarketplaces[$mn] = {"source":{"source":"directory","path":$mp}}' \
                "$settings" > "$settings.tmp"
            mv "$settings.tmp" "$settings"
        else
            jq -n --arg pk "$plugin_key" --arg mn "$MARKETPLACE_NAME" --arg mp "$mkt_dir" \
                '{enabledPlugins:{($pk):true},extraKnownMarketplaces:{($mn):{"source":{"source":"directory","path":$mp}}}}' \
                > "$settings"
        fi

        # installed_plugins.json
        local install_path="$mkt_dir/$plugin_name"
        if [ -f "$installed" ]; then
            jq --arg pk "$plugin_key" --arg v "$version" --arg t "$now" --arg ip "$install_path" \
                '.plugins[$pk] = [{"scope":"user","installPath":$ip,"version":$v,"installedAt":$t,"lastUpdated":$t}]' \
                "$installed" > "$installed.tmp"
            mv "$installed.tmp" "$installed"
        else
            mkdir -p "$(dirname "$installed")"
            jq -n --arg pk "$plugin_key" --arg v "$version" --arg t "$now" --arg ip "$install_path" \
                '{version:2,plugins:{($pk):[{"scope":"user","installPath":$ip,"version":$v,"installedAt":$t,"lastUpdated":$t}]}}' \
                > "$installed"
        fi
        echo "  [ok] installed_plugins.json ($plugin_key)"

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
    fi
}

ensure_all_plugins_registered() {
    echo ""
    echo "Plugin registration:"
    for pn in "${PLUGIN_NAMES[@]}"; do
        has_component "$pn" || continue
        local v
        v="$(read_version "$(plugin_json "$pn")")"
        ensure_plugin_registered "$pn" "${v:-unknown}"
    done
}

# ── Unregister plugin ────────────────────────────────────────────────

unregister_plugin_one() {
    local plugin_name="$1"
    local plugin_key
    plugin_key="$(plugin_key "$plugin_name")"
    local settings="$CLAUDE_DIR/settings.json"
    local installed="$CLAUDE_DIR/plugins/installed_plugins.json"
    local known="$CLAUDE_DIR/plugins/known_marketplaces.json"

    if $DRY_RUN; then
        echo "  [dry-run] would remove $plugin_key from settings/installed/known"
        return 0
    fi

    if command -v python3 &>/dev/null; then
        python3 -c "
import json,sys,os
claude_dir=sys.argv[1]
plugin_key=sys.argv[2]

# settings.enabledPlugins[plugin_key]
sf=os.path.join(claude_dir,'settings.json')
if os.path.isfile(sf):
    with open(sf) as f: s=json.load(f)
    ep=s.get('enabledPlugins',{})
    if plugin_key in ep:
        del ep[plugin_key]
        if not ep: s.pop('enabledPlugins',None)
        with open(sf,'w') as f: json.dump(s,f,indent=2); f.write('\n')
        print(f'  [ok] settings.json ({plugin_key})')

# installed_plugins.plugins[plugin_key]
ip=os.path.join(claude_dir,'plugins','installed_plugins.json')
if os.path.isfile(ip):
    with open(ip) as f: d=json.load(f)
    plugins=d.get('plugins',{})
    if plugin_key in plugins:
        del plugins[plugin_key]
        with open(ip,'w') as f: json.dump(d,f,indent=2); f.write('\n')
        print(f'  [ok] installed_plugins.json ({plugin_key})')
" "$CLAUDE_DIR" "$plugin_key"
    elif command -v jq &>/dev/null; then
        if [ -f "$settings" ]; then
            jq --arg pk "$plugin_key" \
                'del(.enabledPlugins[$pk]) | if .enabledPlugins == {} then del(.enabledPlugins) else . end' \
                "$settings" > "$settings.tmp"
            mv "$settings.tmp" "$settings"
            echo "  [ok] settings.json ($plugin_key)"
        fi
        if [ -f "$installed" ]; then
            jq --arg pk "$plugin_key" 'del(.plugins[$pk])' "$installed" > "$installed.tmp"
            mv "$installed.tmp" "$installed"
            echo "  [ok] installed_plugins.json ($plugin_key)"
        fi
    fi
}

# Cleanup shared marketplace + optional-features state (only on full uninstall).
unregister_marketplace_state() {
    local settings="$CLAUDE_DIR/settings.json"
    local known="$CLAUDE_DIR/plugins/known_marketplaces.json"

    if $DRY_RUN; then
        echo "  [dry-run] would remove marketplace + optional features"
        return 0
    fi

    if command -v python3 &>/dev/null; then
        python3 -c "
import json,sys,os
claude_dir=sys.argv[1]
mkt_name=sys.argv[2]

# settings.extraKnownMarketplaces + optional features
sf=os.path.join(claude_dir,'settings.json')
if os.path.isfile(sf):
    with open(sf) as f: s=json.load(f)
    changed=False
    ekm=s.get('extraKnownMarketplaces',{})
    if mkt_name in ekm:
        del ekm[mkt_name]
        if not ekm: s.pop('extraKnownMarketplaces',None)
        changed=True
        print(f'  [ok] settings.json (marketplace {mkt_name})')
    env=s.get('env',{})
    if 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS' in env:
        del env['CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS']
        if not env: s.pop('env',None)
        changed=True
        print('  [ok] removed agent teams')
    if 'statusLine' in s:
        del s['statusLine']
        changed=True
        print('  [ok] removed statusline config')
    if changed:
        with open(sf,'w') as f: json.dump(s,f,indent=2); f.write('\n')

# known_marketplaces[mkt_name]
kf=os.path.join(claude_dir,'plugins','known_marketplaces.json')
if os.path.isfile(kf):
    with open(kf) as f: k=json.load(f)
    if mkt_name in k:
        del k[mkt_name]
        with open(kf,'w') as f: json.dump(k,f,indent=2); f.write('\n')
        print(f'  [ok] known_marketplaces.json ({mkt_name})')

# Statusline script
sl=os.path.join(claude_dir,'statusline.sh')
if os.path.isfile(sl):
    os.remove(sl)
    print('  [ok] removed statusline.sh')
" "$CLAUDE_DIR" "$MARKETPLACE_NAME"
    fi

    # Remove cache
    if [ -d "$CLAUDE_DIR/plugins/cache/$MARKETPLACE_NAME" ]; then
        rm -rf "$CLAUDE_DIR/plugins/cache/$MARKETPLACE_NAME"
        echo "  [ok] removed cache/$MARKETPLACE_NAME"
    fi
}

unregister_all_plugins() {
    echo ""
    echo "Unregistering plugins:"
    for pn in "${PLUGIN_NAMES[@]}"; do
        unregister_plugin_one "$pn"
    done
    unregister_marketplace_state
}

# ── Version ───────────────────────────────────────────────────────────

# Project-level version (independent of any plugin's plugin.json — see
# PROJECT_VERSION_FILE comment near the top).
VERSION=""
if [ -f "$PROJECT_VERSION_FILE" ]; then
    VERSION=$(head -n1 "$PROJECT_VERSION_FILE" | tr -d '[:space:]')
fi

PREV_VERSION=""
if [ -f "$MANIFEST" ]; then
    PREV_VERSION=$(read_version "$MANIFEST")
fi

if [ -n "$PREV_VERSION" ] && [ "$PREV_VERSION" != "${VERSION:-unknown}" ]; then
    echo "hukuhaka-claude v${PREV_VERSION} → v${VERSION:-unknown} (plugins: ${PLUGIN_NAMES[*]})"
elif [ -n "$PREV_VERSION" ]; then
    echo "hukuhaka-claude v${VERSION:-unknown} (reinstall — plugins: ${PLUGIN_NAMES[*]})"
else
    echo "hukuhaka-claude v${VERSION:-unknown} (fresh install — plugins: ${PLUGIN_NAMES[*]})"
fi
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

    unregister_all_plugins

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

# Plugins — deploy each under marketplace path
for pn in "${PLUGIN_NAMES[@]}"; do
    has_component "$pn" || continue
    psrc="$(plugin_src "$pn")"
    [ -d "$psrc" ] && collect "$psrc" "plugins/$MARKETPLACE_NAME/$pn"
done

# Standalone skills
for skill_dir in "$SKILLS_SRC"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name="$(basename "$skill_dir")"
    has_component "$skill_name" || continue
    collect "$skill_dir" "skills/$skill_name"
done

# Template
if [ -f "$TEMPLATE_SRC" ] && has_component "claude-md"; then
    echo "CLAUDE.md" >> "$NEW_LIST"
fi

# ── Load old manifest (or scan for migration) ───────────────────────

if [ -f "$MANIFEST" ]; then
    manifest_files | sort > "$OLD_LIST"
else
    # First manifest-based deploy: scan existing dirs to detect stale files
    {
        for scan_dir in "$CLAUDE_DIR/plugins/project-mapper"; do
            [ -d "$scan_dir" ] || continue
            find "$scan_dir" -type f | while IFS= read -r file; do
                echo "${file#"$CLAUDE_DIR"/}"
            done
        done
        for pn in "${PLUGIN_NAMES[@]}"; do
            scan_dir="$CLAUDE_DIR/plugins/$MARKETPLACE_NAME/$pn"
            [ -d "$scan_dir" ] || continue
            find "$scan_dir" -type f | while IFS= read -r file; do
                echo "${file#"$CLAUDE_DIR"/}"
            done
        done
    } | sort > "$OLD_LIST"
    [ -s "$OLD_LIST" ] && echo "Migrating from pre-manifest install..."
fi

sort -o "$NEW_LIST" "$NEW_LIST"

# ── Deploy files ──────────────────────────────────────────────────────

resolve_src() {
    local rel="$1"
    case "$rel" in
        plugins/$MARKETPLACE_NAME/*/*)
            local rest="${rel#plugins/$MARKETPLACE_NAME/}"
            local pn="${rest%%/*}"
            local sub="${rest#*/}"
            echo "$MARKETPLACE_DIR/$pn/$sub" ;;
        skills/*/*)
            echo "$SKILLS_SRC/${rel#skills/}" ;;
        CLAUDE.md)
            echo "$TEMPLATE_SRC" ;;
    esac
}

echo "Deploying:"
count=0
added=0
updated=0
unchanged=0
while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    src=$(resolve_src "$rel")
    dst="$CLAUDE_DIR/$rel"
    if [ -z "$src" ] || [ ! -f "$src" ]; then
        continue
    fi
    if $DRY_RUN; then
        echo "  [dry-run] $rel"
    elif [ ! -f "$dst" ]; then
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
        added=$((added + 1))
    elif ! cmp -s "$src" "$dst"; then
        cp "$src" "$dst"
        updated=$((updated + 1))
    else
        unchanged=$((unchanged + 1))
    fi
    count=$((count + 1))
done < "$NEW_LIST"
if $DRY_RUN; then
    echo "  $count files"
else
    summary=""
    [ "$added" -gt 0 ] && summary="$added added"
    [ "$updated" -gt 0 ] && summary="${summary:+$summary, }$updated updated"
    [ "$unchanged" -gt 0 ] && summary="${summary:+$summary, }$unchanged unchanged"
    echo "  ${summary:-$count files}"
fi

# ── Generate marketplace manifest ────────────────────────────────────

generate_marketplace_manifest() {
    local mkt_manifest="$CLAUDE_DIR/plugins/$MARKETPLACE_NAME/.claude-plugin/marketplace.json"

    if $DRY_RUN; then
        echo "  [dry-run] marketplace.json"
        return 0
    fi

    mkdir -p "$(dirname "$mkt_manifest")"

    # Build a JSON document listing every plugin from PLUGIN_NAMES,
    # filtered by the active component selection.
    local plugin_meta
    plugin_meta=$(mktemp)
    for pn in "${PLUGIN_NAMES[@]}"; do
        has_component "$pn" || continue
        local v desc
        v=$(read_version "$(plugin_json "$pn")")
        desc=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('description',''))" "$(plugin_json "$pn")" 2>/dev/null || echo "")
        printf '%s\t%s\t%s\n' "$pn" "${v:-unknown}" "$desc" >> "$plugin_meta"
    done

    if command -v python3 &>/dev/null; then
        python3 -c "
import json,sys
mkt_name=sys.argv[1]
meta_file=sys.argv[2]
out_file=sys.argv[3]
plugins=[]
with open(meta_file) as f:
    for line in f:
        parts=line.rstrip('\n').split('\t')
        if len(parts)<3: continue
        name,version,desc=parts[0],parts[1],parts[2]
        plugins.append({
            'name':name,
            'description':desc,
            'version':version,
            'author':{'name':'hukuhaka'},
            'source':'./'+name,
        })
d={
    'name':mkt_name,
    'description':'hukuhaka plugin marketplace',
    'owner':{'name':'hukuhaka'},
    'plugins':plugins,
}
with open(out_file,'w') as f: json.dump(d,f,indent=2); f.write('\n')
" "$MARKETPLACE_NAME" "$plugin_meta" "$mkt_manifest"
    fi

    rm -f "$plugin_meta"

    # Add to file list for manifest tracking
    echo "plugins/$MARKETPLACE_NAME/.claude-plugin/marketplace.json" >> "$NEW_LIST"
    sort -o "$NEW_LIST" "$NEW_LIST"
    echo "  [ok] marketplace.json (${#PLUGIN_NAMES[@]} plugin(s))"
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

# Old install layouts had plugins/project-mapper/ at the top level.
# Clean up if present.
for legacy in "$CLAUDE_DIR/plugins/project-mapper"; do
    if [ -d "$legacy" ] && ! $DRY_RUN; then
        echo ""
        echo "Removing legacy $(basename "$legacy"):"
        rm -rf "$legacy"
        echo "  [ok] removed"
    fi
done

# ── Invalidate cache ─────────────────────────────────────────────────

if ! $DRY_RUN && [ -d "$CLAUDE_DIR/plugins/cache/$MARKETPLACE_NAME" ]; then
    rm -rf "$CLAUDE_DIR/plugins/cache/$MARKETPLACE_NAME"
    echo "  [ok] cache invalidated"
fi

# ── Unregister dropped plugins ───────────────────────────────────────
# When --components is used and the new selection drops a plugin that was
# previously registered, tear down its settings/installed_plugins entries
# and remove its install/cache dirs so `claude plugin list` doesn't keep
# showing it.

unregister_dropped_plugins() {
    $COMPONENTS_PROVIDED || return 0
    [ -f "$MANIFEST" ] || return 0

    # Determine which plugins were previously installed. Prefer manifest
    # .components when present; fall back to inferring from file paths
    # (handles pre-extension manifests).
    local prev=()
    while IFS= read -r c; do
        [ -z "$c" ] && continue
        for pn in "${PLUGIN_NAMES[@]}"; do
            [ "$c" = "$pn" ] && prev+=("$c") && break
        done
    done < <(manifest_components)

    if [ "${#prev[@]}" -eq 0 ]; then
        while IFS= read -r f; do
            case "$f" in
                plugins/$MARKETPLACE_NAME/*)
                    local rest="${f#plugins/$MARKETPLACE_NAME/}"
                    local pn="${rest%%/*}"
                    [ -z "$pn" ] && continue
                    [ "$pn" = ".claude-plugin" ] && continue
                    local already=false
                    for p in "${prev[@]+"${prev[@]}"}"; do
                        [ "$p" = "$pn" ] && already=true && break
                    done
                    $already || prev+=("$pn")
                    ;;
            esac
        done < <(manifest_files)
    fi

    local dropped=()
    for c in "${prev[@]}"; do
        if ! has_component "$c"; then
            dropped+=("$c")
        fi
    done
    [ "${#dropped[@]}" -eq 0 ] && return 0

    echo ""
    echo "Unregistering dropped plugins:"
    for pn in "${dropped[@]}"; do
        unregister_plugin_one "$pn"
        local install_dir="$CLAUDE_DIR/plugins/$MARKETPLACE_NAME/$pn"
        local cache_dir="$CLAUDE_DIR/plugins/cache/$MARKETPLACE_NAME/$pn"
        if ! $DRY_RUN; then
            [ -d "$install_dir" ] && rm -rf "$install_dir" && echo "  [ok] removed $install_dir"
            [ -d "$cache_dir" ] && rm -rf "$cache_dir" && echo "  [ok] removed cache for $pn"
        fi
    done
}

unregister_dropped_plugins

# ── Register plugins ─────────────────────────────────────────────────

ensure_all_plugins_registered

# ── Optional features (agent-teams only) ─────────────────────────────
#
# Third-party extras (rtk, ccstatusline-usage) are managed by install_helper.sh
# — see scripts/install.sh which invokes it after deploy.

configure_agent_teams() {
    local settings="$CLAUDE_DIR/settings.json"
    local currently=false
    if [ -f "$settings" ] && command -v python3 &>/dev/null; then
        currently=$(python3 -c "
import json,sys
with open(sys.argv[1]) as f: s=json.load(f)
print('true' if s.get('env',{}).get('CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS') else 'false')
" "$settings")
    fi

    echo ""
    echo "Agent teams:"
    if $DRY_RUN; then
        echo "  [dry-run] would (de)configure agent teams"
        return 0
    fi

    if has_component "agent-teams"; then
        if [ "$currently" = "true" ]; then
            echo "  [ok] agent teams (already enabled)"
        else
            if command -v python3 &>/dev/null; then
                python3 -c "
import json,sys,os
sf=sys.argv[1]
s=json.load(open(sf)) if os.path.isfile(sf) else {}
s.setdefault('env',{})['CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS']='1'
with open(sf,'w') as f: json.dump(s,f,indent=2); f.write('\n')
" "$settings"
                echo "  [ok] agent teams enabled"
            fi
        fi
    else
        if [ "$currently" = "true" ] && command -v python3 &>/dev/null; then
            python3 -c "
import json,sys
sf=sys.argv[1]
with open(sf) as f: s=json.load(f)
env=s.get('env',{})
if 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS' in env:
    del env['CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS']
    if not env: s.pop('env',None)
    with open(sf,'w') as f: json.dump(s,f,indent=2); f.write('\n')
" "$settings"
            echo "  [ok] agent teams disabled"
        fi
    fi
}

configure_agent_teams

# ── Clean empty directories ──────────────────────────────────────────

if ! $DRY_RUN; then
    find "$CLAUDE_DIR/plugins" "$CLAUDE_DIR/skills" -type d -empty -delete 2>/dev/null || true
fi

# ── Write manifest ────────────────────────────────────────────────────

# Compute components CSV that gets recorded. When --components was passed,
# record exactly that. Otherwise, record the full universe of what was
# actually deployed (everything discovered).
compute_components_csv() {
    if $COMPONENTS_PROVIDED; then
        echo "$COMPONENTS"
        return 0
    fi
    local items=()
    for pn in "${PLUGIN_NAMES[@]}"; do items+=("$pn"); done
    for skill_dir in "$SKILLS_SRC"/*/; do
        [ -d "$skill_dir" ] && items+=("$(basename "$skill_dir")")
    done
    [ -f "$TEMPLATE_SRC" ] && items+=("claude-md")
    # agent-teams: include if currently enabled in settings.json.
    # rtk/statusline are NOT tracked here — managed by install_helper.sh.
    local sf="$CLAUDE_DIR/settings.json"
    if [ -f "$sf" ] && command -v python3 &>/dev/null; then
        local t_enabled
        t_enabled=$(python3 -c "
import json,sys
with open(sys.argv[1]) as f: s=json.load(f)
print('true' if s.get('env',{}).get('CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS') else 'false')
" "$sf")
        [ "$t_enabled" = "true" ] && items+=("agent-teams")
    fi
    local IFS=','; echo "${items[*]}"
}

if ! $DRY_RUN; then
    manifest_write "${VERSION:-unknown}" "$NEW_LIST" "$(compute_components_csv)"
fi

echo ""
if $DRY_RUN; then
    echo "Dry run complete. No files were modified."
else
    # Count stale removals
    removed=0
    if [ -s "$STALE_LIST" ]; then
        removed=$(wc -l < "$STALE_LIST" | tr -d ' ')
    fi
    detail=""
    [ "$added" -gt 0 ] && detail="$added added"
    [ "$updated" -gt 0 ] && detail="${detail:+$detail, }$updated updated"
    [ "$removed" -gt 0 ] && detail="${detail:+$detail, }$removed removed"
    if [ -n "$detail" ]; then
        echo "Deploy complete. v${VERSION:-unknown} ($detail)"
    else
        echo "Deploy complete. v${VERSION:-unknown} (no changes)"
    fi
fi
