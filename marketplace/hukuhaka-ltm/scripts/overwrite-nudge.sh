#!/usr/bin/env bash
# PreToolUse Edit/Write nudge for .claude/ltm/{index,pinned}.
#
# Philosophy: L1 (pinned.md) and L2 (index/<topic>.md) are curated
# knowledge — edits there are intentional acts that change what Claude
# sees on every session (L1) or what surfaces during recall (L2). Nudge
# the writer to be deliberate.
#
# Layer policy:
#   - .claude/ltm/log/  (L3, raw timeline) — SILENT. Stop hook can append
#     autonomously here; manual edits via Write/Edit are also fine.
#   - .claude/ltm/index/  (L2, knowledge cards) — NUDGE. Cards have
#     supersede semantics; deletions should be intentional.
#   - .claude/ltm/pinned.md  (L1, always-loaded principles) — NUDGE.
#     Each line here lands in every session's context budget.
#   - .claude/ltm/CLAUDE.md (RULES) — silent here; /ltm:declare-rule is
#     the canonical evolution path and records its own entry.
#
# Behavior: emit a one-line reminder to stderr (visible to Claude as
# additionalContext). Never blocks — exit 0 always. Claude decides
# whether to comply.

set -u

# Read full stdin (hook input JSON)
INPUT=$(cat)

# Extract file_path with grep+sed (no jq dependency).
# JSON shape: {"tool_input": {"file_path": "...", ...}, ...}
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# Nudge L2 (index/) and L1 (pinned.md). Silent on L3 (log/) and RULES.
case "$FILE_PATH" in
    */.claude/ltm/index/*|.claude/ltm/index/*)
        cat >&2 <<'NUDGE'
[hukuhaka-ltm] You are about to write to .claude/ltm/index/ (L2 knowledge card).
Cards are the surface ltm-recall returns first. Before overwriting:
  - If this replaces an existing card's claim, set `supersedes: [<old-id>]`
    in the new frontmatter rather than silently rewriting the old body.
  - If you are only adding to evidence:[], leave summary/context alone
    unless the user has actively reframed the rule.
This is a reminder, not a block.
NUDGE
        ;;
    */.claude/ltm/pinned.md|.claude/ltm/pinned.md)
        cat >&2 <<'NUDGE'
[hukuhaka-ltm] You are about to write to .claude/ltm/pinned.md (L1).
Every line here lands in every future session's SessionStart context.
L1 requires explicit user assent — confirm in the same turn before this
write. If you are promoting from L2, prefer `/ltm:distill`, whose
L1-update step routes the change through the same user gate.
This is a reminder, not a block.
NUDGE
        ;;
    *)
        :
        ;;
esac

exit 0
