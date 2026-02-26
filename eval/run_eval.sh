#!/usr/bin/env bash
# run_eval.sh — Eval orchestrator: capture transcript + run judge
#
# Usage:
#   run_eval.sh --type logic --scenario SYNC-LOGIC-S01
#   run_eval.sh --type logic --spec sync-logic        # all scenarios in spec
#   run_eval.sh --type quality --scenario SYNC-QUAL-MCP-ON
#   run_eval.sh --cache                                # reuse transcript
set -euo pipefail

EVAL_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$EVAL_DIR/.." && pwd)"

# Prevent nested Claude Code session errors
unset CLAUDECODE

# Defaults
EVAL_TYPE=""
SCENARIO_ID=""
SPEC_ID=""
CACHE=false
MODEL="sonnet"

usage() {
  echo "Usage: $0 --type <logic|quality|audit-quality> --scenario <ID> [--cache] [--model <model>]"
  echo "       $0 --type logic --spec <spec-id> [--cache]"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --type) EVAL_TYPE="$2"; shift 2 ;;
    --scenario) SCENARIO_ID="$2"; shift 2 ;;
    --spec) SPEC_ID="$2"; shift 2 ;;
    --cache) CACHE=true; shift ;;
    --model) MODEL="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# Resolve scenarios
SCENARIOS=()
if [[ -n "$SCENARIO_ID" ]]; then
  SCENARIOS+=("$SCENARIO_ID")
elif [[ -n "$SPEC_ID" ]]; then
  SPEC_FILE="$EVAL_DIR/specs/${SPEC_ID}.json"
  [[ -f "$SPEC_FILE" ]] || { echo "Spec not found: $SPEC_FILE"; exit 1; }
  while IFS= read -r sid; do
    SCENARIOS+=("$sid")
  done < <(python3 -c "import json; [print(s) for s in json.load(open('$SPEC_FILE')).get('scenarios',[])]")
fi

[[ ${#SCENARIOS[@]} -gt 0 ]] || { echo "No scenarios specified"; usage; }

run_scenario() {
  local sid="$1"
  local scenario_file="$EVAL_DIR/scenarios/${sid}.json"
  [[ -f "$scenario_file" ]] || { echo "Scenario not found: $scenario_file"; return 1; }

  # Load scenario
  local scenario
  scenario=$(cat "$scenario_file")
  local eval_type_s
  eval_type_s=$(echo "$scenario" | python3 -c "import json,sys; print(json.load(sys.stdin).get('eval_type',''))")
  local prompt
  prompt=$(echo "$scenario" | python3 -c "import json,sys; print(json.load(sys.stdin).get('prompt',''))")
  local cwd_rel
  cwd_rel=$(echo "$scenario" | python3 -c "import json,sys; print(json.load(sys.stdin).get('cwd',''))")
  local mcp_mode
  mcp_mode=$(echo "$scenario" | python3 -c "import json,sys; print(json.load(sys.stdin).get('mcp_mode','on'))")
  local capture_flags
  capture_flags=$(echo "$scenario" | python3 -c "import json,sys; print(json.load(sys.stdin).get('capture_flags',''))")
  local spec_id_s
  spec_id_s=$(echo "$scenario" | python3 -c "import json,sys; print(json.load(sys.stdin).get('spec',''))")

  # Override eval_type if provided via CLI
  [[ -n "$EVAL_TYPE" ]] && eval_type_s="$EVAL_TYPE"

  local transcript_file="$EVAL_DIR/transcripts/${sid}.json"
  local result_file="$EVAL_DIR/results/${sid}.json"
  local testbed_dir="$REPO_ROOT/$cwd_rel"

  echo "=== Scenario: $sid (type=$eval_type_s, mcp=$mcp_mode) ==="

  # Step 1: Capture transcript (unless --cache)
  if [[ "$CACHE" == false ]]; then
    echo "  Resetting testbed..."
    (cd "$testbed_dir" && git checkout -- . && git clean -fd) 2>/dev/null || true
    mkdir -p "$testbed_dir/.claude"

    # Seed .claude/ from scenario JSON seed field
    local seed_json
    seed_json=$(echo "$scenario" | python3 -c "import json,sys; print(json.dumps(json.load(sys.stdin).get('seed',{})))")
    local seed_keys
    seed_keys=$(echo "$seed_json" | python3 -c "import json,sys; [print(k) for k in json.loads(sys.stdin.read())]")
    while IFS= read -r key; do
      [[ -z "$key" ]] && continue
      local val
      val=$(echo "$seed_json" | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['$key'])")
      local target="$testbed_dir/$key"
      mkdir -p "$(dirname "$target")"
      if [[ "$val" == "empty" ]]; then
        touch "$target"
      elif [[ "$val" == template:* ]]; then
        local tpl_name="${val#template:}"
        cp "$EVAL_DIR/fixtures/${tpl_name}.md" "$target"
      else
        printf '%s' "$val" > "$target"
      fi
    done <<< "$seed_keys"

    echo "  Capturing transcript..."
    mkdir -p "$EVAL_DIR/transcripts" "$EVAL_DIR/results"

    # Run claude from testbed directory
    if (cd "$testbed_dir" && eval claude -p \"$prompt\" $capture_flags \
      --output-format stream-json \
      > "$transcript_file" \
      2>"$EVAL_DIR/transcripts/${sid}.stderr"); then
      echo "  Transcript captured: $transcript_file"
    else
      echo "  WARNING: Claude CLI returned non-zero exit code (see ${sid}.stderr)"
    fi
  else
    echo "  Using cached transcript: $transcript_file"
    [[ -f "$transcript_file" ]] || { echo "  ERROR: No cached transcript found"; return 1; }
  fi

  # Step 2: Extract artifacts (for quality / audit-quality eval)
  if [[ "$eval_type_s" == "quality" ]]; then
    echo "  Extracting docs..."
    python3 "$EVAL_DIR/extract_docs.py" "$transcript_file" --id "$sid"
  elif [[ "$eval_type_s" == "audit-quality" ]]; then
    echo "  Extracting findings..."
    python3 "$EVAL_DIR/extract_findings.py" "$transcript_file" --id "$sid"
  fi

  # Step 3: Run judge
  echo "  Running judge..."
  case "$eval_type_s" in
    logic)
      local spec_file="$EVAL_DIR/specs/${spec_id_s}.json"
      [[ -f "$spec_file" ]] || { echo "  ERROR: Spec not found: $spec_file"; return 1; }
      python3 "$EVAL_DIR/eval_logic.py" "$transcript_file" \
        --spec "$spec_file" \
        --scenario "$scenario_file" \
        --model "$MODEL" \
        -o "$result_file"
      ;;
    quality)
      python3 "$EVAL_DIR/eval_quality.py" "$EVAL_DIR/outputs/$sid" \
        --model "$MODEL" \
        -o "$result_file"
      ;;
    audit-quality)
      python3 "$EVAL_DIR/eval_audit_quality.py" "$EVAL_DIR/outputs/$sid" \
        --model "$MODEL" \
        -o "$result_file"
      ;;
    *)
      echo "  ERROR: Unknown eval type: $eval_type_s"
      return 1
      ;;
  esac

  echo "  Result: $result_file"
  echo ""
}

# Run scenarios (sequential for now; parallel with & for independent scenarios)
for sid in "${SCENARIOS[@]}"; do
  run_scenario "$sid"
done

echo "=== All scenarios complete ==="
