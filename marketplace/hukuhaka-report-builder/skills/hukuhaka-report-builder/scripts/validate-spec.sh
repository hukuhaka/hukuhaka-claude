#!/usr/bin/env bash
# validate-spec.sh — completeness gate for a report spec.md
# usage: validate-spec.sh [--require=intake,preflight] [<spec.md>]
#   no path arg → read spec content from stdin (hook Case A: content not yet on disk)
#   path arg    → read the on-disk file (hook Case B / manual / CI)
# contract source: references/spec-schema.md (Intake + Preflight blocks)
#   (keep INTAKE_FIELDS / PREFLIGHT_AXES below in sync with spec-schema.md)
#
# Validates only the blocks PRESENT in the spec (it grows stage-by-stage), unless
# --require names a block that MUST be present (the artifact-build backstop).
set -uo pipefail

REQUIRE=""
case "${1:-}" in
  --require=*) REQUIRE="${1#--require=}"; shift ;;
esac

FILE="${1:-}"
if [ -n "$FILE" ]; then
  if [ ! -f "$FILE" ]; then echo "FAIL: spec not found: $FILE"; exit 1; fi
  SPEC="$(cat "$FILE")"
else
  SPEC="$(cat)"
fi

ERRORS=0
fail(){ echo "FAIL: $1"; ERRORS=$((ERRORS+1)); }

# Contract arrays — hardcoded by name (counting provenance lines is circular: a
# dropped axis leaves no line to count, so absence would be undetectable).
INTAKE_FIELDS=( "subject material" "audience" "publication" )
PREFLIGHT_AXES=(
  "page format" "orientation" "page unit" "color mode" "print mode" "register"
  "count" "language" "brand layer" "disclaimer policy" "versioning surface" "TOC"
)

# Block presence by prefix — headers carry parentheticals (## Preflight (Stage 1 lock)).
has_block(){ printf '%s\n' "$SPEC" | grep -Eq "^## $1"; }

field_line(){ printf '%s\n' "$SPEC" | grep -E "^- $1:" | head -1; }

# A FILLED line never contains '<' — the template stub is "<A4 ... | freeform>".
# Real axis values use ×, -, +, |, never angle brackets (A4 794×1123, 5-7, author+date).
check_framing(){
  local line val
  line="$(field_line "$1")"
  [ -n "$line" ] || { fail "Intake framing missing: $1"; return; }
  case "$line" in *'<'*) fail "Intake framing unfilled (<...> placeholder): $1"; return ;; esac
  val="${line#*:}"
  printf '%s' "$val" | grep -Eq '[^[:space:]]' || fail "Intake framing empty: $1"
}

check_axis(){
  local line
  line="$(field_line "$1")"
  [ -n "$line" ] || { fail "Preflight axis missing: $1"; return; }
  case "$line" in *'<'*) fail "Preflight axis unfilled (<...> placeholder): $1"; return ;; esac
  # provenance must be exactly ONE token + closing ] — rejects the stub
  # "[provenance: register-default | user]" (has ' | ' before ']').
  if ! printf '%s' "$line" | grep -Eq '\[provenance: (kit-default|register-default|user)\]'; then
    fail "Preflight axis bad/missing provenance (need single kit-default|register-default|user): $1"
  fi
}

# Intake block
if printf '%s' "$REQUIRE" | grep -qw intake && ! has_block "Intake"; then
  fail "required block absent: ## Intake (Stage 0)"
fi
if has_block "Intake"; then
  for f in "${INTAKE_FIELDS[@]}"; do check_framing "$f"; done
fi

# Preflight block
if printf '%s' "$REQUIRE" | grep -qw preflight && ! has_block "Preflight"; then
  fail "required block absent: ## Preflight (Stage 1)"
fi
if has_block "Preflight"; then
  for a in "${PREFLIGHT_AXES[@]}"; do check_axis "$a"; done
fi

if [ "$ERRORS" -eq 0 ]; then
  i=absent; p=absent
  has_block "Intake" && i=present
  has_block "Preflight" && p=present
  echo "OK: spec valid (intake=$i, preflight=$p)"
  exit 0
else
  echo "$ERRORS error(s) in spec"
  exit 1
fi
