#!/usr/bin/env bash
# SessionStart context-inject for hukuhaka-ltm.
#
# Replaces the older session-start-ping.sh. Goal: every new session
# starts with three things in context:
#   1. Auto-recorded digest from the *previous* session (if any)
#   2. The project's L1 pinned principles (always-on rules)
#   3. The using-hukuhaka-ltm SKILL.md — the "how the system works" map
#
# Output: a single hookSpecificOutput.additionalContext JSON blob (or
# additional_context for Cursor). Per plugin-guide:agents-and-hooks.md
# the SessionStart hook payload is added to Claude's context.
#
# Size guard: total injected payload is capped at ~3000 chars. If the
# combined content exceeds the cap, SKILL.md is dropped first (it can be
# re-loaded on demand by activating the skill via its description),
# then pinned.md, then digest. Digest has highest priority because it
# surfaces work the user has not seen yet.
#
# Reads stdin (hook input JSON) but does not parse it — cwd is taken from
# $CLAUDE_PROJECT_DIR per Claude Code's hook contract.

set -u

PAYLOAD_BUDGET=8500

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
LTM_DIR="${PROJECT_DIR}/.claude/ltm"
RULES_FILE="${LTM_DIR}/CLAUDE.md"
PINNED_FILE="${LTM_DIR}/pinned.md"
DIGEST_RAW="${LTM_DIR}/.session-digest"
DIGEST_PENDING="${LTM_DIR}/.session-digest.pending"
DIGEST_ARCHIVE_DIR="${LTM_DIR}/.session-digest-archive"

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
SKILL_FILE="${PLUGIN_ROOT}/skills/using-hukuhaka-ltm/SKILL.md"

# Silent exit if LTM not bootstrapped in this project.
if [ ! -f "$RULES_FILE" ]; then
    exit 0
fi

# Recovery: if SessionEnd never fired (crash, force-close), .session-digest
# was left orphaned. Absorb it into .pending so the previous session's
# auto-records still surface here.
if [ -f "$DIGEST_RAW" ]; then
    if [ -f "$DIGEST_PENDING" ]; then
        cat "$DIGEST_RAW" >> "$DIGEST_PENDING"
        rm -f "$DIGEST_RAW"
    else
        mv "$DIGEST_RAW" "$DIGEST_PENDING"
    fi
fi

# --- Build section 1: digest from previous session ---
digest_section=""
if [ -f "$DIGEST_PENDING" ]; then
    digest_body=$(cat "$DIGEST_PENDING" 2>/dev/null || echo "")
    if [ -n "$digest_body" ]; then
        line_count=$(printf "%s" "$digest_body" | grep -c . || echo 0)
        digest_section=$(printf "## Auto-recorded since last session (%s entries)\n\nReview via \`/ltm:distill\`.\n\n%s\n" "$line_count" "$digest_body")
    fi
    mkdir -p "$DIGEST_ARCHIVE_DIR" 2>/dev/null
    ts=$(date -u +"%Y%m%dT%H%M%SZ")
    mv "$DIGEST_PENDING" "${DIGEST_ARCHIVE_DIR}/${ts}.md" 2>/dev/null || rm -f "$DIGEST_PENDING"
fi

# --- Build section 2: pinned (L1) ---
pinned_section=""
if [ -f "$PINNED_FILE" ]; then
    pinned_section=$(cat "$PINNED_FILE")
fi

# --- Build section 3: skill map ---
skill_section=""
if [ -n "$PLUGIN_ROOT" ] && [ -f "$SKILL_FILE" ]; then
    # Strip YAML frontmatter (everything between the first two --- lines)
    skill_section=$(awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' "$SKILL_FILE")
fi

# --- Assemble with size guard ---
sep=$'\n\n---\n\n'
combined=""
[ -n "$digest_section" ] && combined+="$digest_section"
[ -n "$pinned_section" ] && combined+="${combined:+$sep}$pinned_section"
[ -n "$skill_section" ] && combined+="${combined:+$sep}$skill_section"

if [ ${#combined} -gt $PAYLOAD_BUDGET ]; then
    # Drop SKILL.md first
    combined=""
    [ -n "$digest_section" ] && combined+="$digest_section"
    [ -n "$pinned_section" ] && combined+="${combined:+$sep}$pinned_section"
fi
if [ ${#combined} -gt $PAYLOAD_BUDGET ]; then
    # Drop pinned next; keep digest only
    combined="$digest_section"
fi
if [ ${#combined} -gt $PAYLOAD_BUDGET ]; then
    # Final truncation
    combined="${combined:0:$PAYLOAD_BUDGET}"
fi

if [ -z "$combined" ]; then
    exit 0
fi

# Wrap in an LTM banner for clarity in the context window.
wrapped="<hukuhaka-ltm-context>
${combined}
</hukuhaka-ltm-context>"

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

escaped=$(escape_for_json "$wrapped")

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
