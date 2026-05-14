#!/usr/bin/env bash
#
# refresh-officials.sh — Mirror docs/officials/ from https://code.claude.com/docs/llms.txt
#
# Idempotent: only writes when content differs. Logs new/changed/unchanged/failed.
# Hybrid routing: preserves existing 9 subdirs, places agent-sdk/* in new agent-sdk/.
# Unknown URLs route to _unsorted/ (warning, not failure).
#
# Usage:
#   scripts/refresh-officials.sh              # parallel refresh (default 8 jobs)
#   scripts/refresh-officials.sh --dry-run    # show plan, no writes
#   scripts/refresh-officials.sh --jobs 4     # tune concurrency

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
DEST="$REPO_DIR/docs/officials"
LLMS_URL="https://code.claude.com/docs/llms.txt"
LOG="$DEST/.refresh.log"

DRY=false
JOBS=8
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY=true; shift ;;
    --jobs)    JOBS="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,15p' "$0" | sed 's/^# \?//'
      exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

mkdir -p "$DEST"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# ── 1. Fetch index ─────────────────────────────────────────────────────
echo "Fetching $LLMS_URL"
curl -sfL --max-time 30 "$LLMS_URL" -o "$TMP/llms.txt.new"

# ── 2. Routing ─────────────────────────────────────────────────────────
# Find existing file's subdir (portable, no -printf which is GNU-only)
existing_subdir() {
  local b="$1"
  local hit
  hit=$(find "$DEST" -maxdepth 2 -name "$b.md" -not -path "$DEST/llms.txt" 2>/dev/null | head -1)
  [ -n "$hit" ] && dirname "$hit" | sed "s|^$DEST/||"
}

route_subdir() {
  local b="$1" url="$2"
  case "$url" in
    *"/agent-sdk/"*) echo "agent-sdk"; return ;;
    *"/whats-new/"*) echo "whats-new"; return ;;
  esac
  local prev
  prev=$(existing_subdir "$b")
  if [ -n "$prev" ]; then echo "$prev"; return; fi
  case "$b" in
    quickstart|overview|changelog|desktop-quickstart|web-quickstart) echo "getting_started" ;;
    agent-teams|best-practices|common-workflows|features-overview|how-claude-code-works|computer-use) echo "core_concepts" ;;
    cli-reference|hooks|plugins-reference|interactive-mode|checkpointing|scheduled-tasks|fast-mode|tools-reference|env-vars|errors|commands) echo "reference" ;;
    amazon-bedrock|google-vertex-ai|microsoft-foundry|llm-gateway|devcontainer|sandboxing|network-config|third-party-integrations|github-enterprise-server|plugin-dependencies|platforms) echo "deployment" ;;
    keybindings|model-config|permissions|settings|statusline|terminal-config|memory|permission-modes|auto-mode-config|fullscreen|claude-directory|debug-your-config|context-window) echo "configuration" ;;
    chrome|claude-code-on-the-web|desktop|github-actions|gitlab-ci-cd|jetbrains|remote-control|slack|vs-code|voice-dictation|ultraplan|ultrareview|channels|channels-reference|routines|desktop-scheduled-tasks) echo "outside_the_terminal" ;;
    analytics|authentication|costs|data-usage|monitoring-usage|plugin-marketplaces|security|server-managed-settings|setup|admin-setup) echo "administration" ;;
    code-review|discover-plugins|headless|hooks-guide|mcp|output-styles|plugins|skills|sub-agents|troubleshooting) echo "build_with_claude_code" ;;
    legal-and-compliance|zero-data-retention) echo "resources" ;;
    *) echo "_unsorted" ;;
  esac
}

# ── 3. Parse llms.txt for URLs ─────────────────────────────────────────
grep -oE 'https://code\.claude\.com/docs/en/[^)]+\.md' "$TMP/llms.txt.new" \
  | sort -u > "$TMP/urls"

URL_COUNT=$(wc -l < "$TMP/urls" | tr -d ' ')
echo "Parsed $URL_COUNT unique URLs"

# ── 4. Build manifest ──────────────────────────────────────────────────
> "$TMP/manifest"
while IFS= read -r url; do
  base=$(basename "$url" .md)
  sub=$(route_subdir "$base" "$url")
  echo "$url|$sub|$base" >> "$TMP/manifest"
done < "$TMP/urls"

# ── 5. Fetch worker ────────────────────────────────────────────────────
fetch_one() {
  local entry="$1"
  IFS='|' read -r url sub base <<<"$entry"
  local target="$DEST/$sub/$base.md"
  mkdir -p "$DEST/$sub"
  local tmp="$TMP/${sub//\//_}_${base}.tmp"
  if ! curl -sfL --max-time 15 --retry 2 --retry-delay 1 "$url" -o "$tmp" 2>/dev/null; then
    echo "FAIL|$sub/$base.md|$url"
    return
  fi
  if [ ! -f "$target" ]; then
    $DRY || mv "$tmp" "$target"
    echo "NEW|$sub/$base.md"
  elif ! cmp -s "$tmp" "$target"; then
    $DRY || mv "$tmp" "$target"
    echo "CHANGED|$sub/$base.md"
  else
    echo "UNCHANGED|$sub/$base.md"
  fi
}
export -f fetch_one
export DEST TMP DRY

# ── 6. Run in parallel, summarize ──────────────────────────────────────
echo "Fetching $URL_COUNT files (${JOBS} parallel)..."
xargs -P "$JOBS" -I{} bash -c 'fetch_one "$@"' _ {} < "$TMP/manifest" \
  | tee "$LOG" \
  | awk -F'|' '{c[$1]++} END {for (k in c) printf "  %-10s %d\n", k, c[k]}'

# ── 7. Update local llms.txt ───────────────────────────────────────────
$DRY || cp "$TMP/llms.txt.new" "$DEST/llms.txt"

# ── 8. Verify ──────────────────────────────────────────────────────────
LOCAL_COUNT=$(find "$DEST" -name '*.md' -not -name 'llms.txt' | wc -l | tr -d ' ')
FAIL_COUNT=$(grep -c '^FAIL' "$LOG" || true)
UNSORTED_COUNT=0
[ -d "$DEST/_unsorted" ] && UNSORTED_COUNT=$(find "$DEST/_unsorted" -name '*.md' | wc -l | tr -d ' ')

echo ""
echo "Summary:"
echo "  Remote URLs: $URL_COUNT"
echo "  Local files: $LOCAL_COUNT"
echo "  Failed:      $FAIL_COUNT"
echo "  Unsorted:    $UNSORTED_COUNT"
[ "$UNSORTED_COUNT" -gt 0 ] && echo "  → Triage: docs/officials/_unsorted/ (extend route_subdir())"

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "FAIL: $FAIL_COUNT fetches failed; see $LOG"
  exit 1
fi
if [ "$URL_COUNT" -ne "$LOCAL_COUNT" ]; then
  echo "FAIL: count mismatch (remote $URL_COUNT vs local $LOCAL_COUNT)"
  exit 1
fi
echo "OK"
