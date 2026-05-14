#!/usr/bin/env bash
#
# hukuhaka-claude install helper — third-party extras (rtk, ccstatusline-usage)
#
# Orthogonal to hukuhaka core. Independently runnable.
#
#   curl -fsSL https://raw.githubusercontent.com/hukuhaka/hukuhaka-claude/main/scripts/install_helper.sh | bash
#   bash scripts/install_helper.sh
#   bash scripts/install_helper.sh --components rtk
#   bash scripts/install_helper.sh --components rtk,statusline
#   bash scripts/install_helper.sh --none          # remove all extras
#   bash scripts/install_helper.sh --skip          # no-op
#
# Idempotent: detect current state → install only what's missing, remove what
# was deselected. State is read from ~/.claude/settings.json. No manifest.

set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"

EXPLICIT_COMPONENTS=""
COMPONENTS_PROVIDED=false
DRY_RUN=false
SKIP=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --components) EXPLICIT_COMPONENTS="$2"; COMPONENTS_PROVIDED=true; shift 2 ;;
        --all)        EXPLICIT_COMPONENTS="rtk,statusline"; COMPONENTS_PROVIDED=true; shift ;;
        --none)       EXPLICIT_COMPONENTS=""; COMPONENTS_PROVIDED=true; shift ;;
        --skip)       SKIP=true; shift ;;
        --dry-run)    DRY_RUN=true; shift ;;
        -h|--help)    sed -n '3,16p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if $SKIP; then
    echo "extras: skipped"
    exit 0
fi

# Flush any keypresses queued before the script took control of the tty.
# Mitigates the `curl ... | bash` pre-selector window where arrow keys were
# echoed by the terminal driver instead of consumed by an app. Subshell wrap
# swallows `</dev/tty` redirect failures that bypass per-command 2>/dev/null.
( [ -e /dev/tty ] && {
    stty -F /dev/tty sane
    read -t 0.01 -n 10000 _ </dev/tty
} ) >/dev/null 2>&1 || true

# ── Detection ────────────────────────────────────────────────────────

has_component() {
    [[ ",${EXPLICIT_COMPONENTS}," == *",$1,"* ]]
}

ccstatusline_installed() {
    [ -f "$SETTINGS" ] || { echo false; return; }
    command -v python3 &>/dev/null || { echo false; return; }
    python3 -c "
import json,sys
try:
    s=json.load(open(sys.argv[1]))
except Exception:
    print('false'); sys.exit()
sl=s.get('statusLine') or {}
print('true' if 'ccstatusline' in sl.get('command','') else 'false')
" "$SETTINGS"
}

statusline_entry_present() {
    [ -f "$SETTINGS" ] || { echo false; return; }
    command -v python3 &>/dev/null || { echo false; return; }
    python3 -c "
import json,sys
try:
    s=json.load(open(sys.argv[1]))
except Exception:
    print('false'); sys.exit()
print('true' if 'statusLine' in s else 'false')
" "$SETTINGS"
}

statusline_entry_remove() {
    [ -f "$SETTINGS" ] || return 0
    command -v python3 &>/dev/null || return 0
    python3 -c "
import json,sys
sf=sys.argv[1]
with open(sf) as f: s=json.load(f)
if 'statusLine' in s:
    del s['statusLine']
    with open(sf,'w') as f: json.dump(s,f,indent=2); f.write('\n')
" "$SETTINGS"
}

# Legacy migration: drop bundled ~/.claude/statusline.sh + stale entry that
# pointed at it. Pre-helper installs shipped a bash statusline.sh.
statusline_migrate_legacy() {
    local legacy="$CLAUDE_DIR/statusline.sh"
    local migrated=false
    if [ -f "$legacy" ]; then
        rm -f "$legacy"
        migrated=true
    fi
    if [ -f "$SETTINGS" ] && command -v python3 &>/dev/null; then
        local stale
        stale=$(python3 -c "
import json,sys
try: s=json.load(open(sys.argv[1]))
except Exception: print('false'); sys.exit()
sl=s.get('statusLine') or {}
cmd=sl.get('command','')
print('true' if cmd.endswith('statusline.sh') and 'ccstatusline' not in cmd else 'false')
" "$SETTINGS")
        if [ "$stale" = "true" ]; then
            statusline_entry_remove
            migrated=true
        fi
    fi
    $migrated && echo "  [migrate] removed legacy bundled statusline"
    return 0
}

rtk_hook_present() {
    [ -f "$SETTINGS" ] || { echo false; return; }
    command -v python3 &>/dev/null || { echo false; return; }
    python3 -c "
import json,sys
try:
    s=json.load(open(sys.argv[1]))
except Exception:
    print('false'); sys.exit()
hooks=(s.get('hooks') or {}).get('PreToolUse') or []
for h in hooks:
    if h.get('matcher')=='Bash':
        for sub in (h.get('hooks') or []):
            if 'rtk hook' in (sub.get('command') or ''):
                print('true'); sys.exit()
print('false')
" "$SETTINGS"
}

rtk_hook_remove() {
    [ -f "$SETTINGS" ] || return 0
    command -v python3 &>/dev/null || return 0
    python3 -c "
import json,sys
sf=sys.argv[1]
with open(sf) as f: s=json.load(f)
hooks=s.get('hooks') or {}
pre=hooks.get('PreToolUse') or []
new_pre=[]
for h in pre:
    if h.get('matcher')=='Bash':
        kept=[sub for sub in (h.get('hooks') or []) if 'rtk hook' not in (sub.get('command') or '')]
        if kept:
            h['hooks']=kept
            new_pre.append(h)
    else:
        new_pre.append(h)
if new_pre:
    hooks['PreToolUse']=new_pre
else:
    hooks.pop('PreToolUse',None)
if hooks:
    s['hooks']=hooks
else:
    s.pop('hooks',None)
with open(sf,'w') as f: json.dump(s,f,indent=2); f.write('\n')
" "$SETTINGS"
}

rtk_install_binary() {
    command -v rtk &>/dev/null && return 0
    case "$(uname -s)" in
        Darwin)
            if command -v brew &>/dev/null; then
                brew install rtk >&2
            else
                echo "  [skip] rtk — brew not found on macOS (install Homebrew, then re-run)" >&2
                return 1
            fi ;;
        Linux)
            if command -v curl &>/dev/null; then
                curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh >&2
            else
                echo "  [skip] rtk — curl not found (install curl, then re-run)" >&2
                return 1
            fi ;;
        *) echo "  [skip] rtk — unsupported OS $(uname -s)" >&2; return 1 ;;
    esac
    command -v rtk &>/dev/null
}

# ── Configure handlers ───────────────────────────────────────────────

configure_rtk() {
    local present
    present=$(rtk_hook_present)
    if has_component "rtk"; then
        if command -v rtk &>/dev/null && [ "$present" = "true" ]; then
            echo "  [ok] rtk (already enabled)"
            return 0
        fi
        $DRY_RUN && { echo "  [dry-run] would install rtk + register hook"; return 0; }
        rtk_install_binary || return 0
        # rtk init is idempotent
        rtk init -g --hook-only --auto-patch >/dev/null 2>&1 || {
            echo "  [warn] rtk init failed — try manually: rtk init -g --hook-only --auto-patch"
            return 0
        }
        echo "  [ok] rtk enabled (hook installed)"
    else
        if [ "$present" = "true" ]; then
            $DRY_RUN && { echo "  [dry-run] would remove rtk hook"; return 0; }
            rtk_hook_remove
            echo "  [ok] rtk hook removed (binary preserved)"
        fi
    fi
}

configure_statusline() {
    local installed
    installed=$(ccstatusline_installed)
    if has_component "statusline"; then
        if [ "$installed" = "true" ]; then
            echo "  [ok] statusline (ccstatusline already installed)"
            return 0
        fi
        $DRY_RUN && { echo "  [dry-run] would launch ccstatusline-usage TUI"; return 0; }
        if ! command -v npx &>/dev/null; then
            echo "  [skip] statusline — npx not found (install Node.js, then re-run)"
            return 0
        fi
        # NOTE: only require /dev/tty existence. npx command itself redirects
        # all three streams to /dev/tty, so script stdin being a pipe (curl|bash)
        # is fine.
        if [ -e /dev/tty ]; then
            echo "  Launching ccstatusline-usage TUI..."
            npx -y ccstatusline-usage@latest </dev/tty >/dev/tty 2>/dev/tty || {
                echo "  [warn] ccstatusline-usage exited non-zero — re-run manually if needed"
            }
        else
            echo "  [skip] statusline — no /dev/tty (run manually: npx -y ccstatusline-usage@latest)"
        fi
    else
        if [ "$(statusline_entry_present)" = "true" ]; then
            $DRY_RUN && { echo "  [dry-run] would clear statusLine entry"; return 0; }
            statusline_entry_remove
            echo "  [ok] statusline removed (settings.json statusLine cleared)"
        fi
    fi
}

# ── Mini interactive selector ────────────────────────────────────────

select_extras_interactive() {
    [ -e /dev/tty ] || return 1
    local rtk_on stat_on
    rtk_on=$(rtk_hook_present)
    stat_on=$(ccstatusline_installed)

    local mark_rtk="N" mark_stat="N"
    [ "$rtk_on" = "true" ] && mark_rtk="Y"
    [ "$stat_on" = "true" ] && mark_stat="Y"

    echo "" >&2
    echo "Third-party extras (orthogonal to hukuhaka — skip if unsure)" >&2
    echo "" >&2

    local ans
    local sel=()

    printf "  Enable rtk (token-saving Bash hook)? [%s/%s] " \
        "$([ "$mark_rtk" = "Y" ] && echo Y || echo y)" \
        "$([ "$mark_rtk" = "Y" ] && echo n || echo N)" >&2
    read -r ans </dev/tty || ans=""
    if [ -z "$ans" ]; then ans="$mark_rtk"; fi
    [[ "$ans" =~ ^[Yy] ]] && sel+=("rtk")

    printf "  Enable ccstatusline (statusline)? [%s/%s] " \
        "$([ "$mark_stat" = "Y" ] && echo Y || echo y)" \
        "$([ "$mark_stat" = "Y" ] && echo n || echo N)" >&2
    read -r ans </dev/tty || ans=""
    if [ -z "$ans" ]; then ans="$mark_stat"; fi
    [[ "$ans" =~ ^[Yy] ]] && sel+=("statusline")

    local IFS=','; echo "${sel[*]:-}"
}

# ── Main ─────────────────────────────────────────────────────────────

echo ""
echo "Optional extras:"

statusline_migrate_legacy

if ! $COMPONENTS_PROVIDED; then
    if [ -e /dev/tty ]; then
        EXPLICIT_COMPONENTS=$(select_extras_interactive) || EXPLICIT_COMPONENTS=""
    else
        echo "  [skip] no tty and no --components — extras unchanged"
        exit 0
    fi
fi

configure_rtk
configure_statusline

echo ""
echo "Extras done."
