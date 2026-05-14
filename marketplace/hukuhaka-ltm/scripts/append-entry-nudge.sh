#!/usr/bin/env bash
# PreToolUse Bash nudge for append-entry.py invocations against
# .claude/ltm/log/.
#
# Why this exists (and why it is *only* a nudge, never a block):
# A previous iteration of this hook used `type: prompt` to ask an LLM
# judge to verify that the user's last message contained explicit
# assent. The judge only sees `$ARGUMENTS` (the bash command) — it
# cannot read the conversation. Without conversation visibility the
# assent check is impossible, and the judge defaulted to false-reject
# even when the user had clearly assented. The hook became a leak that
# blocked legitimate writes.
#
# Conclusion: hard-gating assent at the hook layer is impossible with
# the information available. The IRON-LAW prose + pre-action
# announcement in SKILL.md is the real gate. This script reminds Claude
# of the rule when it is about to call append-entry.py, but never
# blocks.
#
# Behavior:
#   - Reads PreToolUse JSON from stdin (tool_input.command field).
#   - If the command invokes append-entry.py against .claude/ltm/log/:
#     emit a one-line IRON-LAW reminder to stderr (visible to Claude as
#     additionalContext). Otherwise stay silent.
#   - Always exits 0. Never blocks.

set -u

INPUT=$(cat)

# Extract tool_input.command. JSON shape:
#   {"tool_input": {"command": "...", "description": "..."}, ...}
COMMAND=$(echo "$INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

if [ -z "$COMMAND" ]; then
    exit 0
fi

# Match append-entry.py invocations. Two common forms:
#   - bundled: ${CLAUDE_PLUGIN_ROOT}/scripts/append-entry.py
#   - direct path:  .../hukuhaka-ltm/scripts/append-entry.py
case "$COMMAND" in
    *append-entry.py*)
        cat >&2 <<'NUDGE'
[hukuhaka-ltm] About to write to .claude/ltm/log/ via append-entry.py.
IRON-LAW: this is allowed only if the user has explicitly assented in
this same turn with a clear go-word (yes / yeah / go / go ahead / save it /
record it / commit / 응 / 그래 / 기록해 / 등). Soft yeses (ok / okay / sure /
오케이 / ㅇㅋ) are NOT assent. If you cannot quote the user's exact go-word
from their last message, STOP and ask. This hook is a reminder, not a gate.
NUDGE
        ;;
    *)
        :
        ;;
esac

exit 0
