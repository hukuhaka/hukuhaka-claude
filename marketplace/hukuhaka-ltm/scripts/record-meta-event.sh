#!/usr/bin/env bash
# Detect plugin / model version change and record as an LTM meta-event.
#
# Tracking philosophy:
#   - Plugin version: read from this plugin's plugin.json (deterministic).
#   - Model version: best-effort. Claude Code currently does not expose a
#     stable session env var for "active model"; we rely on $CLAUDE_MODEL
#     if set, else mark as "unknown". When the model becomes detectable,
#     this script naturally starts recording transitions.
#
# State file: .claude/ltm/.meta-state (gitignored — local view, the
# canonical record is the appended entry).
#
# Invoked manually or wired into a hook (e.g., SessionStart) — see hooks.json.

set -u

LTM_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/ltm"
STATE="$LTM_DIR/.meta-state"
PLUGIN_JSON="${CLAUDE_PLUGIN_ROOT:-}/.claude-plugin/plugin.json"
APPEND="${CLAUDE_PLUGIN_ROOT:-}/scripts/append-entry.py"

if [ ! -d "$LTM_DIR" ]; then
    # Project hasn't run /ltm:init yet — silent no-op.
    exit 0
fi
if [ ! -f "$PLUGIN_JSON" ] || [ ! -x "$APPEND" ]; then
    # Plugin scaffolding incomplete — silent.
    exit 0
fi

# Read plugin version (no jq dependency)
PLUGIN_VERSION=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$PLUGIN_JSON" | head -1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
PLUGIN_VERSION="${PLUGIN_VERSION:-unknown}"

# Best-effort model. Falls back to env var or "unknown".
MODEL_VERSION="${CLAUDE_MODEL:-unknown}"

# Read previous state
PREV_PLUGIN=""
PREV_MODEL=""
if [ -f "$STATE" ]; then
    PREV_PLUGIN=$(grep -E '^plugin=' "$STATE" | head -1 | cut -d= -f2-)
    PREV_MODEL=$(grep -E '^model=' "$STATE" | head -1 | cut -d= -f2-)
fi

# First-run baseline: write state, no entry. The act of running /ltm:init
# is itself the genesis entry; we don't want to also fire a "version change"
# on the very first session.
if [ -z "$PREV_PLUGIN" ] && [ -z "$PREV_MODEL" ]; then
    {
        echo "plugin=$PLUGIN_VERSION"
        echo "model=$MODEL_VERSION"
    } > "$STATE"
    exit 0
fi

CHANGED=0

if [ "$PLUGIN_VERSION" != "$PREV_PLUGIN" ]; then
    printf 'hukuhaka-ltm plugin version changed.\n\nFrom: %s\nTo:   %s\n\nThis is an informational entry — no migration is forced. Review default RULES drift if needed via /ltm:declare-rule.\n' "$PREV_PLUGIN" "$PLUGIN_VERSION" \
        | python3 "$APPEND" \
            --kind harness-version-changed \
            --title "hukuhaka-ltm: $PREV_PLUGIN -> $PLUGIN_VERSION" \
            --target-dir "$LTM_DIR" >/dev/null || true
    CHANGED=1
fi

if [ "$MODEL_VERSION" != "$PREV_MODEL" ] && [ "$MODEL_VERSION" != "unknown" ]; then
    printf 'Active model changed.\n\nFrom: %s\nTo:   %s\n\nEntries written from this point may differ in style/depth from prior entries. Older RULES may need re-derivation if model behavior on this LTM diverges.\n' "$PREV_MODEL" "$MODEL_VERSION" \
        | python3 "$APPEND" \
            --kind model-version-changed \
            --title "Model: $PREV_MODEL -> $MODEL_VERSION" \
            --target-dir "$LTM_DIR" >/dev/null || true
    CHANGED=1
fi

if [ "$CHANGED" -eq 1 ]; then
    {
        echo "plugin=$PLUGIN_VERSION"
        echo "model=$MODEL_VERSION"
    } > "$STATE"
fi

exit 0
