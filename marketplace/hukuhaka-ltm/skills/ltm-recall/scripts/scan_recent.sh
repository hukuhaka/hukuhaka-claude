#!/usr/bin/env bash
# scan_recent.sh [N] [kind-filter]
# Lists newest N LTM entries (default 30), optionally filtered by `kind:` frontmatter.
#
# Resolves log dir via $CLAUDE_PROJECT_DIR (Claude Code sets this to the
# project root); falls back to current working dir.
#
# Output: one absolute file path per line, oldest → newest within the
# returned set. Empty output is normal when LTM has not been bootstrapped.

set -e

N="${1:-30}"
KIND="${2:-}"

LOG_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/ltm/log"
[ -d "$LOG_DIR" ] || { echo "no LTM log dir at $LOG_DIR" >&2; exit 0; }

if [ -n "$KIND" ]; then
    grep -l "^kind: $KIND$" "$LOG_DIR"/*.md 2>/dev/null | sort | tail -"$N"
else
    ls -1 "$LOG_DIR"/*.md 2>/dev/null | sort | tail -"$N"
fi
