#!/usr/bin/env bash
# cleanup.sh — Archive stale eval artifacts (transcripts, results, outputs)
#
# Stale = no matching scenario file in eval/scenarios/
#
# Usage:
#   eval/cleanup.sh --stale [--dry-run]    # archive stale files
#   eval/cleanup.sh --all [--dry-run]      # stale + reset testbed
set -euo pipefail

EVAL_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$EVAL_DIR")"
ARCHIVE_DIR="$EVAL_DIR/archive"

DRY_RUN=false
MODE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stale) MODE="stale"; shift ;;
    --all) MODE="all"; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) echo "Usage: $0 [--stale|--all] [--dry-run]"; exit 0 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

[[ -n "$MODE" ]] || { echo "Specify --stale or --all"; exit 1; }

# Collect valid scenario IDs
VALID_IDS=()
for f in "$EVAL_DIR"/scenarios/*.json; do
  [[ -f "$f" ]] || continue
  base="$(basename "$f" .json)"
  VALID_IDS+=("$base")
done

is_valid() {
  local id="$1"
  for v in "${VALID_IDS[@]}"; do
    [[ "$id" == "$v" ]] && return 0
  done
  return 1
}

MOVED=0

archive_file() {
  local src="$1"
  local rel="${src#$EVAL_DIR/}"
  local dest="$ARCHIVE_DIR/$rel"

  if [[ "$DRY_RUN" == true ]]; then
    echo "  [dry-run] $rel"
  else
    mkdir -p "$(dirname "$dest")"
    mv "$src" "$dest"
    echo "  archived: $rel"
  fi
  MOVED=$((MOVED + 1))
}

# Archive stale transcripts
echo "Stale transcripts:"
for f in "$EVAL_DIR"/transcripts/*; do
  [[ -f "$f" ]] || continue
  base="$(basename "$f")"
  # Strip extension (.json, .stderr)
  id="${base%.*}"
  if ! is_valid "$id"; then
    archive_file "$f"
  fi
done

# Archive stale results
echo ""
echo "Stale results:"
for f in "$EVAL_DIR"/results/*.json; do
  [[ -f "$f" ]] || continue
  id="$(basename "$f" .json)"
  if ! is_valid "$id"; then
    archive_file "$f"
  fi
done

# Archive stale outputs
echo ""
echo "Stale outputs:"
for d in "$EVAL_DIR"/outputs/*/; do
  [[ -d "$d" ]] || continue
  id="$(basename "$d")"
  if ! is_valid "$id"; then
    # Archive the whole directory
    for f in "$d"*; do
      [[ -e "$f" ]] && archive_file "$f"
    done
    if [[ "$DRY_RUN" == false ]] && [[ -d "$d" ]]; then
      rmdir "$d" 2>/dev/null || true
    fi
  fi
done

# Reset testbed (--all only)
if [[ "$MODE" == "all" ]]; then
  echo ""
  echo "Testbed reset:"
  if [[ -d "$EVAL_DIR/testbed" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      echo "  [dry-run] git checkout + clean in testbed/"
    else
      (cd "$EVAL_DIR/testbed" && git checkout -- . && git clean -fd) 2>/dev/null || true
      echo "  testbed reset"
    fi
  fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ "$DRY_RUN" == true ]]; then
  echo "$MOVED files would be archived."
else
  echo "$MOVED files archived to eval/archive/."
fi
