#!/usr/bin/env bash
# SessionStart context-inject for hukuhaka-project-mapper.
#
# Replaces the legacy mechanism where templates/CLAUDE.md was deployed
# globally to ~/.claude/CLAUDE.md and exposed HPM-specific reminders to
# every Claude session — even users who did not want HPM.
#
# Behavior:
#   - .claude/ exists in the project   → inject the doc-index block as
#     hookSpecificOutput.additionalContext (Claude Code) or
#     additional_context (Cursor).
#   - .claude/ absent                  → silent exit (no output).
#
# Per docs/plugin-guide/agents-and-hooks.md the SessionStart hook payload
# is added to Claude's context. The matcher in hooks/hooks.json covers
# the four trigger forms: startup|resume|clear|compact.
#
# Reads stdin (hook input JSON) but does not parse it — cwd is taken from
# $CLAUDE_PROJECT_DIR per Claude Code's hook contract.

set -u

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Silent exit if no .claude/ in this project.
if [ ! -d "$PROJECT_DIR/.claude" ]; then
    exit 0
fi

read -r -d '' BODY <<'EOF' || true
<hukuhaka-project-mapper-context>
**BEFORE ANY ACTION**: Read `.claude/` docs if present.

- [map.md](.claude/map.md): codebase structure, entry points
- [design.md](.claude/design.md): tech spec, architecture decisions
- [backlog.md](.claude/backlog.md): Planned, In Progress, TODOs
- [changelog.md](.claude/changelog.md): Recent (load) + Archive (on demand)
- [spec.md](.claude/spec.md): interface contracts, naming rules, definition of done

Doc format rules (file:symbol style, llms.txt, line limits, NEVER ASCII): see `hukuhaka-project-mapper:map-sync` skill.
</hukuhaka-project-mapper-context>
EOF

# --- JSON-escape the payload (bash parameter expansion only — fast) ---
escape_for_json() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

escaped=$(escape_for_json "$BODY")

# Cursor uses additional_context, Claude Code uses hookSpecificOutput.additionalContext.
# Emit only one to avoid double injection.
if [ -n "${CURSOR_PLUGIN_ROOT:-}" ]; then
    printf '{\n  "additional_context": "%s"\n}\n' "$escaped"
elif [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
    printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "SessionStart",\n    "additionalContext": "%s"\n  }\n}\n' "$escaped"
else
    printf '{\n  "additional_context": "%s"\n}\n' "$escaped"
fi

exit 0
