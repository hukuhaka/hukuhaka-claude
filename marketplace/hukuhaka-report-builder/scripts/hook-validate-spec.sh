#!/usr/bin/env bash
# hook-validate-spec.sh — PreToolUse wrapper enforcing the report spec-lock.
# Wired by hooks/hooks.json (matcher: Write|Edit). Thin: routing + deny-JSON;
# the spec logic lives in skills/.../scripts/validate-spec.sh (also runnable solo).
#
# Reads the PreToolUse event JSON on stdin (tool_name, tool_input.{file_path,content}).
# ALWAYS exits 0 — a deny is signalled by the stdout JSON, never by the exit code.
#   - allow  = no stdout, exit 0
#   - deny   = permissionDecision JSON on stdout, exit 0
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$HERE/.." && pwd)}"
VALIDATOR="$ROOT/skills/hukuhaka-report-builder/scripts/validate-spec.sh"

IN="$(cat)"

allow(){ exit 0; }
deny(){  # $1 = reason
  python3 -c 'import json,sys
print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":sys.argv[1]}}))' "$1"
  exit 0
}

# Fail-open on any infra problem — a missing validator must not brick the user's writes.
[ -f "$VALIDATOR" ] || allow

# Extract tool_name + file_path (file_path never contains a newline → 2-line parse is safe).
META="$(printf '%s' "$IN" | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: d={}
ti=d.get("tool_input") or {}
sys.stdout.write((d.get("tool_name") or "")+"\n"+(ti.get("file_path") or ""))' 2>/dev/null)"
TOOL="$(printf '%s\n' "$META" | sed -n '1p')"
FP="$(printf '%s\n' "$META" | sed -n '2p')"

# Pass-through: not a write tool, or not in the report tree (scope to .claude/reports).
case "$TOOL" in Write|Edit) ;; *) allow ;; esac
case "$FP" in */.claude/reports/*) ;; *) allow ;; esac

# CASE A — Write to */.claude/reports/*/spec.md: validate the full content being written.
if [ "$TOOL" = "Write" ] && [[ "$FP" == */spec.md ]]; then
  OUT="$(printf '%s' "$IN" | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: d={}
sys.stdout.write((d.get("tool_input") or {}).get("content") or "")' 2>/dev/null | bash "$VALIDATOR" 2>&1)"
  [ $? -eq 0 ] && allow
  deny "report spec-lock — incomplete spec.md write blocked: $OUT"
fi

# CASE B — Write/Edit to a built artifact: the sibling spec.md must be fully locked.
case "$FP" in
  */cover.html|*/report.html)
    SPEC="$(dirname "$FP")/spec.md"
    OUT="$(bash "$VALIDATOR" --require=intake,preflight "$SPEC" 2>&1)"
    [ $? -eq 0 ] && allow
    deny "report spec-lock — artifact build blocked, Stage 1 not locked: $OUT"
    ;;
esac

# CASE C — Edit to spec.md (Stage 2+ append, fragment only) or any other reports/ write:
# pass-through. Appends never touch the locked Intake/Preflight blocks, and Case B is the
# downstream hard gate (no artifact builds on an unlocked spec).
allow
