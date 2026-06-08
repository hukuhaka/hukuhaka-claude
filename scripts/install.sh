#!/usr/bin/env bash
#
# hukuhaka-claude installer
#
# curl -fsSL https://raw.githubusercontent.com/hukuhaka/hukuhaka-claude/main/scripts/install.sh | bash
#
# Default flow with no args: enter interactive component selector.
# Currently-installed items are pre-checked; toggles drive add/remove.
#
# Flags:
#   --version VERSION       Install specific version (default: latest release or main)
#   --all                   Skip selector, install/keep everything
#   --components a,b,c      Skip selector, set selection to exactly these
#   --add a,b               Union with current manifest selection
#   --remove a,b            Subtract from current manifest selection
#   --uninstall             Remove all installed files using manifest
#   --skip-preflight        Skip dependency check
#   --auto-install-deps     Auto-install missing required deps (no prompt)
#   --print-deps            Print missing-deps install commands and exit
#   --skip-extras           Don't run install_helper.sh (rtk, ccstatusline)
#   --extras a,b            Pass exact extras selection to install_helper.sh
#                           (skips its interactive prompt). Valid: rtk, statusline
#   --help                  Show usage
#
# Component names: plugin / skill / feature names from marketplace/* / skills/*
# plus 'agent-teams', 'claude-md'.
#
# Third-party extras (rtk, ccstatusline-usage) are managed separately via
# scripts/install_helper.sh — auto-invoked at end unless --skip-extras.

set -euo pipefail

# Flush any keypresses queued before the selector takes the tty. Mitigates
# the `curl ... | bash` window where the script is being downloaded/parsed
# and the user's pre-emptive arrow keys are echoed by the terminal driver.
# Wrapped in a subshell so the inner `</dev/tty` redirect failures (which
# bypass `2>/dev/null` on individual commands) get swallowed cleanly.
( [ -e /dev/tty ] && {
    stty -F /dev/tty sane
    read -t 0.01 -n 10000 _ </dev/tty
} ) >/dev/null 2>&1 || true

REPO="hukuhaka/hukuhaka-claude"
CLAUDE_DIR="$HOME/.claude"
MANIFEST="$CLAUDE_DIR/.hukuhaka-manifest.json"

# Skills whose default-on state should be false even if SKILL.md doesn't
# self-mark as deprecated. Maintained here when retiring a skill without
# editing its content. (Currently empty — codex-coworker and gemini-coworker
# were removed from the repo entirely, 2026-06-02.)
DEPRECATED_SKILLS=""

VERSION=""
UNINSTALL=false
MODE_ALL=false
EXPLICIT_COMPONENTS=""
ADD_COMPONENTS=""
REMOVE_COMPONENTS=""
SOURCE_DIR_OVERRIDE=""
DRY_RUN=false
SKIP_PREFLIGHT=false
AUTO_INSTALL_DEPS=false
PRINT_DEPS=false
SKIP_EXTRAS=false
EXTRAS_COMPONENTS=""
EXTRAS_PROVIDED=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version) VERSION="$2"; shift 2 ;;
        --uninstall) UNINSTALL=true; shift ;;
        --all) MODE_ALL=true; shift ;;
        --components) EXPLICIT_COMPONENTS="$2"; shift 2 ;;
        --add) ADD_COMPONENTS="$2"; shift 2 ;;
        --remove) REMOVE_COMPONENTS="$2"; shift 2 ;;
        --source-dir) SOURCE_DIR_OVERRIDE="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --skip-preflight) SKIP_PREFLIGHT=true; shift ;;
        --auto-install-deps) AUTO_INSTALL_DEPS=true; shift ;;
        --print-deps) PRINT_DEPS=true; shift ;;
        --skip-extras) SKIP_EXTRAS=true; shift ;;
        --extras) EXTRAS_COMPONENTS="$2"; EXTRAS_PROVIDED=true; shift 2 ;;
        -h|--help)
            sed -n '3,24p' "$0"
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

# ── Uninstall (unchanged from prior behavior) ────────────────────────

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

    for d in "$CLAUDE_DIR/plugins/cache/hukuhaka-plugin" "$CLAUDE_DIR/plugins/hukuhaka-plugin" "$CLAUDE_DIR/plugins/hukuhaka-project-mapper"; do
        [ -d "$d" ] && rm -rf "$d"
    done

    find "$CLAUDE_DIR/plugins" "$CLAUDE_DIR/skills" -type d -empty -delete 2>/dev/null || true
    rm -f "$MANIFEST"

    echo "Removed $count files."
    exit 0
fi

# ── Version resolution ────────────────────────────────────────────────

if [ -z "$VERSION" ]; then
    if ! release_json=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null); then
        echo "Error: failed to query GitHub for latest release (network/rate-limit/5xx)." >&2
        echo "Hint: pass an explicit version, e.g. install.sh v1.0.0" >&2
        exit 1
    fi
    VERSION=$(printf '%s' "$release_json" \
        | grep -o '"tag_name":[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"v\{0,1\}\([^"]*\)"/\1/')
    if [ -z "$VERSION" ]; then
        echo "Error: could not parse tag_name from GitHub API response." >&2
        exit 1
    fi
fi

if [ -n "$VERSION" ]; then
    VERSION="${VERSION#v}"
    ARCHIVE_URL="https://github.com/$REPO/archive/refs/tags/v${VERSION}.tar.gz"
else
    ARCHIVE_URL="https://github.com/$REPO/archive/refs/heads/main.tar.gz"
fi

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
    echo "hukuhaka-claude v${PREV_VERSION} → v${TARGET}"
elif [ -n "$PREV_VERSION" ]; then
    echo "hukuhaka-claude v${TARGET} (reinstall/reconfigure)"
else
    echo "hukuhaka-claude v${TARGET} (fresh install)"
fi

# ── Download & extract (or use local source for testing) ──────────────

if [ -n "$SOURCE_DIR_OVERRIDE" ]; then
    SRC_DIR="$SOURCE_DIR_OVERRIDE"
    TMPDIR=""
    trap '' EXIT
    echo "Using local source: $SRC_DIR"
else
    TMPDIR=$(mktemp -d)
    trap 'rm -rf "$TMPDIR"' EXIT
    echo "Downloading..."
    curl -fsSL "$ARCHIVE_URL" -o "$TMPDIR/archive.tar.gz"
    tar xzf "$TMPDIR/archive.tar.gz" -C "$TMPDIR"
    SRC_DIR=$(find "$TMPDIR" -maxdepth 1 -type d ! -path "$TMPDIR" | head -1)
fi

if [ -z "$SRC_DIR" ] || [ ! -f "$SRC_DIR/scripts/deploy.sh" ]; then
    echo "Error: deploy.sh not found in source." >&2
    exit 1
fi

# ── Component discovery ──────────────────────────────────────────────

# Output: NAME<TAB>TYPE<TAB>DESCRIPTION<TAB>DEFAULT_ON
discover_components() {
    local src="$1"

    # Plugins
    for plugin_dir in "$src"/marketplace/*/; do
        [ -f "$plugin_dir/.claude-plugin/plugin.json" ] || continue
        local name desc
        name=$(basename "${plugin_dir%/}")
        desc=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('description',''))" \
                "$plugin_dir/.claude-plugin/plugin.json" 2>/dev/null || echo "")
        printf '%s\t%s\t%s\t%s\n' "$name" "plugin" "$desc" "true"
    done

    # Standalone skills
    for skill_dir in "$src"/skills/*/; do
        [ -f "$skill_dir/SKILL.md" ] || continue
        local name desc default_on
        name=$(basename "${skill_dir%/}")
        desc=$(python3 -c "
import sys,re
content=open(sys.argv[1]).read()
fm_m=re.match(r'^---\n(.*?)\n---', content, re.S)
if not fm_m:
    print(''); sys.exit()
fm=fm_m.group(1)
d_m=re.search(r'^description:\s*(.+?)(?=^[a-zA-Z_-]+:|\Z)', fm, re.M | re.S)
if not d_m:
    print(''); sys.exit()
raw=d_m.group(1).strip()
if raw.startswith('>') or raw.startswith('|'):
    body=raw[1:].strip()
    desc=' '.join(line.strip() for line in body.split('\n') if line.strip())
else:
    desc=raw.split('\n')[0].strip()
print(desc[:80])
" "$skill_dir/SKILL.md" 2>/dev/null || echo "")
        # Default OFF if frontmatter description mentions deprecation
        # or if name is in the deprecation denylist (DEPRECATED_SKILLS).
        if echo "$desc" | grep -qiE 'deprecat' || \
           [[ ",${DEPRECATED_SKILLS:-}," == *",${name},"* ]]; then
            default_on="false"
        else
            default_on="true"
        fi
        printf '%s\t%s\t%s\t%s\n' "$name" "skill" "$desc" "$default_on"
    done

    # Features (hardcoded). Note: rtk + ccstatusline are third-party extras
    # and live in install_helper.sh — not listed here.
    printf 'agent-teams\tfeature\tEnable CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS\tfalse\n'

    # Template
    if [ -f "$src/templates/CLAUDE.md" ]; then
        printf 'claude-md\ttemplate\tSpec-first router (~/.claude/CLAUDE.md)\ttrue\n'
    fi
}

# ── Manifest helpers ─────────────────────────────────────────────────

read_manifest_components() {
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

manifest_has_components_field() {
    [ -f "$MANIFEST" ] || return 1
    if command -v python3 &>/dev/null; then
        python3 -c "
import json,sys
m=json.load(open(sys.argv[1]))
sys.exit(0 if 'components' in m else 1)
" "$MANIFEST" 2>/dev/null
    else
        jq -e '.components' "$MANIFEST" >/dev/null 2>&1
    fi
}

# ── Selectors ────────────────────────────────────────────────────────

# Each selector reads the discovery table on stdin (NAME\tTYPE\tDESC\tDEFAULT)
# plus a list of pre-checked names. Outputs selected names, one per line.

select_components_whiptail() {
    local discovery_file="$1"
    local prechecked_csv="$2"
    local args=()
    while IFS=$'\t' read -r name type desc default_on; do
        [ -z "$name" ] && continue
        local on="OFF"
        if [[ ",${prechecked_csv}," == *",${name},"* ]]; then
            on="ON"
        fi
        args+=("$name" "$desc" "$on")
    done < "$discovery_file"

    local result
    result=$(whiptail --title "hukuhaka-claude" \
        --checklist "Select components to install (Space toggles, Enter applies):" \
        20 76 12 "${args[@]}" 3>&1 1>&2 2>&3 < /dev/tty) || return 1

    # whiptail returns space-separated quoted names: "a" "b" "c"
    echo "$result" | tr ' ' '\n' | tr -d '"' | grep -v '^$'
}

select_components_dialog() {
    local discovery_file="$1"
    local prechecked_csv="$2"
    local args=()
    while IFS=$'\t' read -r name type desc default_on; do
        [ -z "$name" ] && continue
        local on="off"
        if [[ ",${prechecked_csv}," == *",${name},"* ]]; then
            on="on"
        fi
        args+=("$name" "$desc" "$on")
    done < "$discovery_file"

    local result
    result=$(dialog --title "hukuhaka-claude" \
        --checklist "Select components to install:" \
        20 76 12 "${args[@]}" 3>&1 1>&2 2>&3 < /dev/tty) || return 1
    echo "$result" | tr ' ' '\n' | tr -d '"' | grep -v '^$'
}

select_components_numbered() {
    local discovery_file="$1"
    local prechecked_csv="$2"
    local names=() descs=() states=()
    local i=0
    while IFS=$'\t' read -r name type desc default_on; do
        [ -z "$name" ] && continue
        names[$i]="$name"
        descs[$i]="$desc"
        if [[ ",${prechecked_csv}," == *",${name},"* ]]; then
            states[$i]="x"
        else
            states[$i]=" "
        fi
        i=$((i+1))
    done < "$discovery_file"

    while true; do
        echo "" >&2
        echo "Select components (toggle numbers separated by space, 'd' to apply, 'q' to cancel):" >&2
        local n=0
        while [ $n -lt ${#names[@]} ]; do
            printf "  %2d) [%s] %-20s %s\n" $((n+1)) "${states[$n]}" "${names[$n]}" "${descs[$n]}" >&2
            n=$((n+1))
        done
        printf "> " >&2
        local input
        read -r input < /dev/tty || return 1
        case "$input" in
            d|D|"") break ;;
            q|Q) return 1 ;;
            *)
                for tok in $input; do
                    if [[ "$tok" =~ ^[0-9]+$ ]] && [ "$tok" -ge 1 ] && [ "$tok" -le "${#names[@]}" ]; then
                        local idx=$((tok-1))
                        if [ "${states[$idx]}" = "x" ]; then
                            states[$idx]=" "
                        else
                            states[$idx]="x"
                        fi
                    fi
                done
                ;;
        esac
    done

    local n=0
    while [ $n -lt ${#names[@]} ]; do
        if [ "${states[$n]}" = "x" ]; then
            echo "${names[$n]}"
        fi
        n=$((n+1))
    done
}

select_components_python() {
    local discovery_file="$1"
    local prechecked_csv="$2"
    local preflight_json="${3:-}"
    python3 "$SRC_DIR/scripts/select_components.py" "$discovery_file" "$prechecked_csv" "$preflight_json"
}

run_selector() {
    local discovery_file="$1"
    local prechecked_csv="$2"
    local preflight_json="${3:-}"

    if ! [ -e /dev/tty ]; then
        echo "Error: interactive selection requires a TTY." >&2
        echo "       Use --components <list> for non-interactive install." >&2
        return 1
    fi

    # Tier order:
    # 1. Python TUI (default — universal, no external deps, arrow-key UX,
    #    consumes preflight JSON for inline req tags)
    # 2. whiptail
    # 3. dialog
    # 4. numbered prompt (last resort)
    if command -v python3 &>/dev/null && [ -f "$SRC_DIR/scripts/select_components.py" ]; then
        select_components_python "$discovery_file" "$prechecked_csv" "$preflight_json"
    elif command -v whiptail &>/dev/null; then
        select_components_whiptail "$discovery_file" "$prechecked_csv"
    elif command -v dialog &>/dev/null; then
        select_components_dialog "$discovery_file" "$prechecked_csv"
    else
        select_components_numbered "$discovery_file" "$prechecked_csv"
    fi
}

# ── CSV utilities ────────────────────────────────────────────────────

csv_to_lines() { tr ',' '\n' | grep -v '^$'; }
lines_to_csv() { tr '\n' ',' | sed 's/,$//'; }

set_union() {
    { echo "$1" | csv_to_lines; echo "$2" | csv_to_lines; } | sort -u | lines_to_csv
}

set_subtract() {
    local a="$1" b="$2"
    local b_lines
    b_lines=$(echo "$b" | csv_to_lines | sort -u)
    echo "$a" | csv_to_lines | sort -u | comm -23 - <(echo "$b_lines") | lines_to_csv
}

# Validate a CSV against the discovery names. Errors out on unknown.
validate_components() {
    local components_csv="$1" discovery_file="$2"
    local known
    known=$(awk -F'\t' '{print $1}' "$discovery_file" | sort -u)
    while IFS= read -r c; do
        [ -z "$c" ] && continue
        if ! echo "$known" | grep -qx "$c"; then
            echo "Error: unknown component '$c'." >&2
            echo "       Available: $(echo "$known" | tr '\n' ' ')" >&2
            return 1
        fi
    done < <(echo "$components_csv" | csv_to_lines)
}

# ── Decide final selection ───────────────────────────────────────────

DISCOVERY_FILE=$(mktemp)
cleanup_install() {
    # Capture the real exit status first: on success this is 0, and a
    # short-circuited cleanup &&-chain below must not leak its falsy status
    # as the script's exit code (this runs as the EXIT trap on success too).
    local rc=$?
    [ -n "${TMPDIR:-}" ] && [ -d "$TMPDIR" ] && rm -rf "$TMPDIR"
    [ -n "${DISCOVERY_FILE:-}" ] && [ -f "$DISCOVERY_FILE" ] && rm -f "$DISCOVERY_FILE"
    [ -n "${PREFLIGHT_ALL_JSON:-}" ] && [ -f "$PREFLIGHT_ALL_JSON" ] && rm -f "$PREFLIGHT_ALL_JSON"
    [ -n "${PREFLIGHT_JSON:-}" ] && [ -f "$PREFLIGHT_JSON" ] && rm -f "$PREFLIGHT_JSON"
    return $rc
}
trap cleanup_install EXIT
discover_components "$SRC_DIR" > "$DISCOVERY_FILE"

ALL_CSV=$(awk -F'\t' '{print $1}' "$DISCOVERY_FILE" | lines_to_csv)
DEFAULT_ON_CSV=$(awk -F'\t' '$4=="true"{print $1}' "$DISCOVERY_FILE" | lines_to_csv)

# Prefill (current state for re-runs)
PREFILL_CSV=""
if [ -f "$MANIFEST" ]; then
    if manifest_has_components_field; then
        PREFILL_CSV=$(read_manifest_components | lines_to_csv)
    else
        # Pre-extension manifest — assume "all installed"
        PREFILL_CSV="$ALL_CSV"
    fi
else
    PREFILL_CSV="$DEFAULT_ON_CSV"
fi

FINAL_CSV=""
WENT_INTERACTIVE=false

# ── Pre-selection preflight (against ALL components) ────────────────
# Run before the selector so the TUI can show per-component req tags
# inline. Result is also reused for the post-Apply 3-way prompt logic.
PREFLIGHT_ALL_JSON=""
if ! $SKIP_PREFLIGHT; then
    PREFLIGHT_ALL_JSON=$(mktemp)
    bash "$SRC_DIR/scripts/preflight.sh" --components "$ALL_CSV" --src-dir "$SRC_DIR" > "$PREFLIGHT_ALL_JSON" 2>/dev/null || true
fi

if $MODE_ALL; then
    FINAL_CSV="$ALL_CSV"
elif [ -n "$EXPLICIT_COMPONENTS" ]; then
    validate_components "$EXPLICIT_COMPONENTS" "$DISCOVERY_FILE" || exit 1
    FINAL_CSV="$EXPLICIT_COMPONENTS"
elif [ -n "$ADD_COMPONENTS" ] || [ -n "$REMOVE_COMPONENTS" ]; then
    [ -n "$ADD_COMPONENTS" ] && validate_components "$ADD_COMPONENTS" "$DISCOVERY_FILE"
    [ -n "$REMOVE_COMPONENTS" ] && validate_components "$REMOVE_COMPONENTS" "$DISCOVERY_FILE"
    FINAL_CSV="$PREFILL_CSV"
    [ -n "$ADD_COMPONENTS" ] && FINAL_CSV=$(set_union "$FINAL_CSV" "$ADD_COMPONENTS")
    [ -n "$REMOVE_COMPONENTS" ] && FINAL_CSV=$(set_subtract "$FINAL_CSV" "$REMOVE_COMPONENTS")
else
    # Interactive — pass preflight JSON so TUI shows per-item req tags
    WENT_INTERACTIVE=true
    SELECTED=$(run_selector "$DISCOVERY_FILE" "$PREFILL_CSV" "$PREFLIGHT_ALL_JSON") || {
        echo "Cancelled. No changes made." >&2
        exit 1
    }
    FINAL_CSV=$(echo "$SELECTED" | lines_to_csv)
fi

if [ -z "$FINAL_CSV" ]; then
    if [ -e /dev/tty ]; then
        printf "Empty selection — this will remove all hukuhaka-claude. Proceed? [y/N] " >&2
        read -r ans < /dev/tty || ans=""
        [[ "$ans" =~ ^[Yy] ]] || { echo "Aborted."; exit 1; }
    else
        echo "Empty selection rejected (use --uninstall to remove everything)." >&2
        exit 1
    fi
fi

echo ""
echo "Components: $FINAL_CSV"
echo ""

# ── Preflight (dependency check) ─────────────────────────────────────

run_preflight() {
    local components="$1"
    local quiet="${2:-false}"
    local out
    out=$(mktemp)
    local exit_code=0
    bash "$SRC_DIR/scripts/preflight.sh" --components "$components" --src-dir "$SRC_DIR" > "$out" || exit_code=$?

    if [ "$quiet" != "true" ]; then
        echo "Requirements:"
        python3 - "$out" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
for r in data["requirements"]:
    sym = "✓" if r["found"] else ("✗" if r["required"] else "⚠")
    name = r["name"]
    detail = ""
    if r["found"]:
        detail = r.get("path", "")
        if r.get("version"):
            v = r["version"]
            if len(v) > 60: v = v[:57] + "..."
            detail += f"  ({v})"
        else:
            pass
    else:
        if r["required"]:
            detail = "MISSING — required"
        else:
            detail = "not found (optional — " + ", ".join(r["needed_by"]) + ")"
    print(f"  {sym} {name:<12} {detail}")
PY
    fi

    PREFLIGHT_JSON="$out"
    return $exit_code
}

# ── Auto-install command builders ────────────────────────────────────

# Detect platform package manager. Echo "brew", "apt", "dnf", "pacman",
# "zypper", or "" if none recognized.
detect_pm() {
    case "$(uname -s)" in
        Darwin) command -v brew &>/dev/null && echo "brew" || echo "" ;;
        Linux)
            if command -v apt-get &>/dev/null; then echo "apt"
            elif command -v dnf &>/dev/null; then echo "dnf"
            elif command -v pacman &>/dev/null; then echo "pacman"
            elif command -v zypper &>/dev/null; then echo "zypper"
            else echo ""; fi
            ;;
        *) echo "" ;;
    esac
}

# Map a system tool → package name for the given pm. Echo the package name.
pm_pkg_name() {
    local pm="$1" tool="$2"
    case "$pm:$tool" in
        brew:whiptail|*:whiptail) echo "newt" ;;
        *:python3|*:python) echo "python3" ;;
        *) echo "$tool" ;;
    esac
}

# Build install command for one tool given pm.
pm_install_cmd() {
    local pm="$1" tool="$2"
    local pkg
    pkg=$(pm_pkg_name "$pm" "$tool")
    case "$pm" in
        brew)   echo "brew install $pkg" ;;
        apt)    echo "sudo apt-get install -y $pkg" ;;
        dnf)    echo "sudo dnf install -y $pkg" ;;
        pacman) echo "sudo pacman -S --noconfirm $pkg" ;;
        zypper) echo "sudo zypper install -y $pkg" ;;
        *)      echo "" ;;
    esac
}

# Print all install commands for the missing-required system tools in
# the preflight JSON. Returns 0 if at least one command produced.
build_install_commands() {
    local pm="$1" preflight_file="$2"
    python3 - "$preflight_file" <<'PY'
import json, sys, os
data = json.load(open(sys.argv[1]))
missing = [r for r in data["requirements"]
           if r["required"] and not r["found"] and r["kind"] == "system"]
for r in missing:
    print(r["name"])
PY
}

handle_preflight_failure() {
    local preflight_file="$1"
    local pm
    pm=$(detect_pm)

    local missing_tools
    missing_tools=$(build_install_commands "$pm" "$preflight_file")

    echo ""
    echo "Some required tools are missing: $(echo $missing_tools | tr '\n' ' ')"

    if [ -z "$pm" ]; then
        echo "No supported package manager detected ($(uname -s))."
        echo "Please install the missing tools manually, then re-run the installer."
        return 1
    fi

    echo "Detected package manager: $pm"
    echo ""
    echo "Install commands:"
    while IFS= read -r tool; do
        [ -z "$tool" ] && continue
        echo "  $(pm_install_cmd "$pm" "$tool")"
    done <<< "$missing_tools"

    local choice
    if $AUTO_INSTALL_DEPS; then
        choice=1
    elif $PRINT_DEPS; then
        choice=2
    elif [ -e /dev/tty ]; then
        echo ""
        echo "How to proceed?"
        echo "  (1) Install missing tools now"
        echo "  (2) Print commands and exit — install yourself, then re-run installer"
        echo "  (3) Cancel"
        printf "[1/2/3] "
        read -r choice < /dev/tty || choice="3"
    else
        # No tty, no flag → safe default = print and exit
        choice=2
    fi

    case "$choice" in
        1)
            echo ""
            echo "Running install commands..."
            while IFS= read -r tool; do
                [ -z "$tool" ] && continue
                local cmd
                cmd=$(pm_install_cmd "$pm" "$tool")
                echo "  > $cmd"
                eval "$cmd" || { echo "Install failed for $tool"; return 1; }
            done <<< "$missing_tools"
            echo ""
            echo "Re-checking..."
            run_preflight "$FINAL_CSV"
            local rc=$?
            if [ $rc -ne 0 ]; then
                echo "Some required tools still missing after install. Aborting."
                return 1
            fi
            return 0
            ;;
        2)
            echo ""
            echo "Run the commands above, then re-run the installer."
            exit 0
            ;;
        *)
            echo "Aborted."
            exit 1
            ;;
    esac
}

if ! $SKIP_PREFLIGHT; then
    # When interactive: TUI already showed inline reqs, skip the
    # full table render. Always run the check itself so the 3-way
    # prompt can fire if missing required.
    run_preflight "$FINAL_CSV" "$WENT_INTERACTIVE"
    PREFLIGHT_RC=$?
    if [ $PREFLIGHT_RC -ne 0 ]; then
        handle_preflight_failure "$PREFLIGHT_JSON" || exit 1
    fi
    rm -f "$PREFLIGHT_JSON"
    echo ""
fi

# ── Deploy ────────────────────────────────────────────────────────────

DEPLOY_ARGS=(--components "$FINAL_CSV")
$DRY_RUN && DEPLOY_ARGS+=(--dry-run)

bash "$SRC_DIR/scripts/deploy.sh" "${DEPLOY_ARGS[@]}"

# ── Extras (orthogonal third-party tooling) ──────────────────────────

if ! $SKIP_EXTRAS && [ -f "$SRC_DIR/scripts/install_helper.sh" ]; then
    HELPER_ARGS=()
    $DRY_RUN && HELPER_ARGS+=(--dry-run)
    if $EXTRAS_PROVIDED; then
        HELPER_ARGS+=(--components "$EXTRAS_COMPONENTS")
    fi
    bash "$SRC_DIR/scripts/install_helper.sh" "${HELPER_ARGS[@]}"
fi

echo ""
if $DRY_RUN; then
    echo "Dry run complete. No files were modified."
else
    echo "Done! Restart Claude Code to load the plugins."
fi
