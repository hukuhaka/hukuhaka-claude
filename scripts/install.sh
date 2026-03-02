#!/usr/bin/env bash
#
# hukuhaka-claude installer
#
# curl -fsSL https://raw.githubusercontent.com/hukuhaka/hukuhaka-claude/main/scripts/install.sh | bash
#
# Flags:
#   --version VERSION  Install specific version (default: latest release or main)
#   --uninstall        Remove installed files using manifest
#   --agent-teams      Enable agent teams without prompting
#   --help             Show usage

set -euo pipefail

REPO="hukuhaka/hukuhaka-claude"
CLAUDE_DIR="$HOME/.claude"
MANIFEST="$CLAUDE_DIR/.hukuhaka-manifest.json"

VERSION=""
UNINSTALL=false
AGENT_TEAMS=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version) VERSION="$2"; shift 2 ;;
        --uninstall) UNINSTALL=true; shift ;;
        --agent-teams) AGENT_TEAMS=true; shift ;;
        -h|--help)
            sed -n '3,12p' "$0"
            exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# ── Prerequisites ─────────────────────────────────────────────────────

has_json_tool() {
    command -v python3 &>/dev/null || command -v jq &>/dev/null
}

if ! has_json_tool; then
    echo "Error: python3 or jq is required." >&2
    exit 1
fi

if ! $UNINSTALL; then
    for cmd in curl tar; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "Error: $cmd is required but not found." >&2
            exit 1
        fi
    done
fi

# ── Uninstall ─────────────────────────────────────────────────────────

if $UNINSTALL; then
    if [ ! -f "$MANIFEST" ]; then
        echo "No manifest found — nothing to uninstall."
        exit 0
    fi

    echo "Uninstalling hukuhaka-claude..."

    if command -v python3 &>/dev/null; then
        files=$(python3 -c "
import json,sys
m=json.load(open(sys.argv[1]))
for f in m.get('files',[]):
    print(f)
" "$MANIFEST")
    else
        files=$(jq -r '.files[]' "$MANIFEST")
    fi

    count=0
    while IFS= read -r rel; do
        [ -z "$rel" ] && continue
        target="$CLAUDE_DIR/$rel"
        if [ -f "$target" ]; then
            rm "$target"
            count=$((count + 1))
        fi
    done <<< "$files"

    # Clean up old marketplace registration (settings.json, installed_plugins, known_marketplaces, dirs)
    if command -v python3 &>/dev/null; then
        python3 -c "
import json,sys,os
claude=sys.argv[1]
for name,path,keys in [
    ('settings.json', claude+'/settings.json', ['enabledPlugins','extraKnownMarketplaces']),
    ('installed_plugins.json', claude+'/plugins/installed_plugins.json', ['plugins']),
    ('known_marketplaces.json', claude+'/plugins/known_marketplaces.json', None),
]:
    if not os.path.isfile(path): continue
    with open(path) as f: d=json.load(f)
    changed=False
    if keys is None:
        if 'hukuhaka-plugin' in d:
            del d['hukuhaka-plugin']; changed=True
    else:
        for k in keys:
            obj=d.get(k,{})
            for ek in [ek for ek in obj if 'hukuhaka-plugin' in ek]:
                del obj[ek]; changed=True
            if not obj and k in d:
                del d[k]; changed=True
    if changed:
        with open(path,'w') as f: json.dump(d,f,indent=2); f.write('\n')
# Remove agent teams env var from settings.json
sf=os.path.join(claude,'settings.json')
if os.path.isfile(sf):
    with open(sf) as f: s=json.load(f)
    env=s.get('env',{})
    if 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS' in env:
        del env['CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS']
        if not env: s.pop('env',None)
        with open(sf,'w') as f: json.dump(s,f,indent=2); f.write('\n')
" "$CLAUDE_DIR" 2>/dev/null || true
    fi

    for d in "$CLAUDE_DIR/plugins/cache/hukuhaka-plugin" "$CLAUDE_DIR/plugins/hukuhaka-plugin" "$CLAUDE_DIR/plugins/project-mapper"; do
        [ -d "$d" ] && rm -rf "$d"
    done

    find "$CLAUDE_DIR/plugins" "$CLAUDE_DIR/skills" -type d -empty -delete 2>/dev/null || true
    rm -f "$MANIFEST"

    echo "Removed $count files."
    exit 0
fi

# ── Version resolution ────────────────────────────────────────────────

if [ -z "$VERSION" ]; then
    VERSION=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
        | grep -o '"tag_name":[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"v\{0,1\}\([^"]*\)"/\1/' || true)
fi

if [ -n "$VERSION" ]; then
    VERSION="${VERSION#v}"
    ARCHIVE_URL="https://github.com/$REPO/archive/refs/tags/v${VERSION}.tar.gz"
else
    ARCHIVE_URL="https://github.com/$REPO/archive/refs/heads/main.tar.gz"
fi

# Check for existing install
PREV_VERSION=""
if [ -f "$MANIFEST" ]; then
    if command -v python3 &>/dev/null; then
        PREV_VERSION=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('version',''))" "$MANIFEST" 2>/dev/null || true)
    elif command -v jq &>/dev/null; then
        PREV_VERSION=$(jq -r '.version // empty' "$MANIFEST" 2>/dev/null || true)
    fi
fi

TARGET="${VERSION:-main}"
if [ -n "$PREV_VERSION" ] && [ "$PREV_VERSION" != "$TARGET" ]; then
    echo "Upgrading hukuhaka-claude v${PREV_VERSION} → v${TARGET}..."
elif [ -n "$PREV_VERSION" ]; then
    echo "Reinstalling hukuhaka-claude v${TARGET}..."
else
    echo "Installing hukuhaka-claude v${TARGET} (fresh)..."
fi

# ── Download & extract ────────────────────────────────────────────────

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "Downloading..."
curl -fsSL "$ARCHIVE_URL" | tar xz -C "$TMPDIR"

# Find extracted directory (hukuhaka-claude-VERSION or hukuhaka-claude-main)
SRC_DIR=$(find "$TMPDIR" -maxdepth 1 -type d ! -path "$TMPDIR" | head -1)

if [ -z "$SRC_DIR" ] || [ ! -f "$SRC_DIR/scripts/deploy.sh" ]; then
    echo "Error: deploy.sh not found in archive." >&2
    exit 1
fi

# ── Deploy ────────────────────────────────────────────────────────────

bash "$SRC_DIR/scripts/deploy.sh"

# ── Optional: Agent Teams ────────────────────────────────────────────

SETTINGS="$CLAUDE_DIR/settings.json"

enable_agent_teams() {
    if command -v python3 &>/dev/null; then
        python3 -c "
import json,sys,os
sf=sys.argv[1]
if os.path.isfile(sf):
    with open(sf) as f: s=json.load(f)
else:
    s={}
env=s.setdefault('env',{})
env['CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS']='1'
with open(sf,'w') as f: json.dump(s,f,indent=2); f.write('\n')
" "$SETTINGS"
    elif command -v jq &>/dev/null; then
        local tmp="$SETTINGS.tmp"
        if [ -f "$SETTINGS" ]; then
            jq '.env["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"] = "1"' "$SETTINGS" > "$tmp"
        else
            jq -n '{env:{"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS":"1"}}' > "$tmp"
        fi
        mv "$tmp" "$SETTINGS"
    fi
}

if $AGENT_TEAMS; then
    enable_agent_teams
    echo "Agent teams enabled."
elif [ -e /dev/tty ]; then
    echo ""
    printf "Enable agent teams? (experimental, higher token usage) [y/N] "
    read -r answer < /dev/tty 2>/dev/null || answer=""
    if [[ "$answer" =~ ^[Yy] ]]; then
        enable_agent_teams
        echo "Agent teams enabled."
    fi
fi

echo ""
echo "Done! Restart Claude Code to load the plugins."
