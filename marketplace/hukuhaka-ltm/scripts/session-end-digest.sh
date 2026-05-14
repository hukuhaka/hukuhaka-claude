#!/usr/bin/env bash
# SessionEnd hook for hukuhaka-ltm.
#
# Rotates `.session-digest` (accumulated by stop-autonomous-append.py during
# the session) into `.session-digest.pending` so the NEXT SessionStart
# inject can surface it. If a previous .pending was never surfaced (rare,
# but possible if the prior session terminated abnormally before another
# SessionStart fired), concatenate rather than overwrite — we never drop
# auto-recorded entries silently.
#
# No stdin parsing; the hook input JSON is irrelevant for this rotation.

set -u

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
LTM_DIR="${PROJECT_DIR}/.claude/ltm"
DIGEST="${LTM_DIR}/.session-digest"
PENDING="${LTM_DIR}/.session-digest.pending"

if [ ! -f "$DIGEST" ]; then
    exit 0
fi

if [ -f "$PENDING" ]; then
    cat "$DIGEST" >> "$PENDING"
    rm -f "$DIGEST"
else
    mv "$DIGEST" "$PENDING"
fi

exit 0
