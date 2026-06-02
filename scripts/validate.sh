#!/usr/bin/env bash
#
# Validation Script — run locally or from CI
#
# Checks:
#   1. JSON syntax (plugin.json, specs, scenarios)
#   2. SKILL.md frontmatter (name, description required)
#   3. deploy.sh --dry-run
#
# Usage:
#   scripts/validate.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

ERRORS=0
CHECKS=0

pass() { CHECKS=$((CHECKS+1)); echo "  [ok] $1"; }
fail() { CHECKS=$((CHECKS+1)); ERRORS=$((ERRORS+1)); echo "  [FAIL] $1"; }

# ── 1. JSON Syntax ──────────────────────────────────────────────────

echo "JSON syntax:"

validate_json() {
    local file="$1"
    local label="${file#$REPO_DIR/}"
    if python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$file" 2>/dev/null; then
        pass "$label"
    else
        fail "$label — invalid JSON"
    fi
}

# plugin.json — every plugin under marketplace/
found_any_plugin=0
for plugin_json in "$REPO_DIR"/marketplace/*/.claude-plugin/plugin.json; do
    [ -f "$plugin_json" ] || continue
    validate_json "$plugin_json"
    found_any_plugin=1
done
if [ "$found_any_plugin" -eq 0 ]; then
    fail "no marketplace/*/.claude-plugin/plugin.json found"
fi

# eval specs
for f in "$REPO_DIR"/eval/specs/*.json; do
    [ -f "$f" ] && validate_json "$f"
done

# eval scenarios
for f in "$REPO_DIR"/eval/scenarios/*.json; do
    [ -f "$f" ] && validate_json "$f"
done

# ── 2. SKILL.md Frontmatter ─────────────────────────────────────────

echo ""
echo "SKILL.md frontmatter:"

validate_frontmatter() {
    local file="$1"
    local label="${file#$REPO_DIR/}"

    # Extract YAML frontmatter between --- delimiters
    local frontmatter
    frontmatter=$(awk '/^---$/{if(n++)exit;next}n' "$file")

    if [ -z "$frontmatter" ]; then
        fail "$label — no YAML frontmatter (missing --- delimiters)"
        return
    fi

    local has_name has_desc
    has_name=$(echo "$frontmatter" | grep -c '^name:' || true)
    has_desc=$(echo "$frontmatter" | grep -c '^description:' || true)

    if [ "$has_name" -ge 1 ] && [ "$has_desc" -ge 1 ]; then
        pass "$label"
    else
        local missing=""
        [ "$has_name" -eq 0 ] && missing="name"
        [ "$has_desc" -eq 0 ] && missing="${missing:+$missing, }description"
        fail "$label — missing: $missing"
    fi
}

# Plugin skills — every plugin under marketplace/
for f in "$REPO_DIR"/marketplace/*/skills/*/SKILL.md; do
    [ -f "$f" ] && validate_frontmatter "$f"
done

# Standalone skills
for f in "$REPO_DIR"/skills/*/SKILL.md; do
    [ -f "$f" ] && validate_frontmatter "$f"
done

# ── 3. Deploy Dry Run ───────────────────────────────────────────────

echo ""
echo "Deploy dry run:"

if "$SCRIPT_DIR/deploy.sh" --dry-run > /dev/null 2>&1; then
    pass "deploy.sh --dry-run"
else
    fail "deploy.sh --dry-run failed"
fi

# ── Summary ──────────────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$ERRORS" -eq 0 ]; then
    echo "All $CHECKS checks passed."
    exit 0
else
    echo "$ERRORS/$CHECKS checks failed."
    exit 1
fi
