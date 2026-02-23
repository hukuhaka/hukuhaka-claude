#!/usr/bin/env bash
# compare_mcp.sh — MCP on/off quality comparison wrapper
#
# Usage:
#   compare_mcp.sh                    # Full run: capture + extract + compare
#   compare_mcp.sh --cache            # Skip capture, reuse transcripts
#   compare_mcp.sh --runs 3           # Multiple runs for statistical significance
#   compare_mcp.sh --logic            # Also run logic eval in parallel
set -euo pipefail

EVAL_DIR="$(cd "$(dirname "$0")" && pwd)"

# Prevent nested Claude Code session errors
unset CLAUDECODE

# Defaults
CACHE=false
RUNS=1
RUN_LOGIC=false
MODEL="sonnet"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cache) CACHE=true; shift ;;
    --runs) RUNS="$2"; shift 2 ;;
    --logic) RUN_LOGIC=true; shift ;;
    --model) MODEL="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--cache] [--runs N] [--logic] [--model MODEL]"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

run_single() {
  local run_idx="$1"
  local suffix=""
  [[ "$RUNS" -gt 1 ]] && suffix="-run${run_idx}"

  local on_id="SYNC-QUAL-MCP-ON${suffix}"
  local off_id="SYNC-QUAL-MCP-OFF${suffix}"

  echo "=============================="
  echo "Run $run_idx / $RUNS"
  echo "=============================="

  # Step 1: MCP ON capture + extract
  if [[ "$CACHE" == false ]]; then
    echo ""
    echo "--- MCP ON: Capturing ---"
    bash "$EVAL_DIR/run_eval.sh" --type quality --scenario SYNC-QUAL-MCP-ON --model "$MODEL"

    # Rename outputs if multi-run
    if [[ -n "$suffix" ]]; then
      cp -r "$EVAL_DIR/outputs/SYNC-QUAL-MCP-ON" "$EVAL_DIR/outputs/$on_id" 2>/dev/null || true
      cp "$EVAL_DIR/transcripts/SYNC-QUAL-MCP-ON.json" "$EVAL_DIR/transcripts/${on_id}.json" 2>/dev/null || true
    fi

    echo ""
    echo "--- MCP OFF: Capturing ---"
    bash "$EVAL_DIR/run_eval.sh" --type quality --scenario SYNC-QUAL-MCP-OFF --model "$MODEL"

    if [[ -n "$suffix" ]]; then
      cp -r "$EVAL_DIR/outputs/SYNC-QUAL-MCP-OFF" "$EVAL_DIR/outputs/$off_id" 2>/dev/null || true
      cp "$EVAL_DIR/transcripts/SYNC-QUAL-MCP-OFF.json" "$EVAL_DIR/transcripts/${off_id}.json" 2>/dev/null || true
    fi
  else
    echo "Using cached transcripts"
    # Still need to extract docs if outputs don't exist
    for scenario in SYNC-QUAL-MCP-ON SYNC-QUAL-MCP-OFF; do
      if [[ ! -d "$EVAL_DIR/outputs/$scenario" ]]; then
        echo "  Extracting docs for $scenario..."
        python3 "$EVAL_DIR/extract_docs.py" \
          "$EVAL_DIR/transcripts/${scenario}.json" \
          --id "$scenario"
      fi
    done
    on_id="SYNC-QUAL-MCP-ON"
    off_id="SYNC-QUAL-MCP-OFF"
  fi

  # Step 2: Quality comparison (single prompt, prevents calibration drift)
  echo ""
  echo "--- Quality Comparison ---"
  local compare_output="$EVAL_DIR/results/COMPARE-QUAL${suffix}.json"
  python3 "$EVAL_DIR/eval_quality.py" \
    "$EVAL_DIR/outputs/$on_id" \
    --docs-dir-b "$EVAL_DIR/outputs/$off_id" \
    --label-a "MCP-ON" \
    --label-b "MCP-OFF" \
    --model "$MODEL" \
    -o "$compare_output"

  # Step 3: Optional logic eval (parallel)
  if [[ "$RUN_LOGIC" == true ]]; then
    echo ""
    echo "--- Logic Eval (parallel) ---"
    local cache_flag=""
    [[ "$CACHE" == true ]] && cache_flag="--cache"

    bash "$EVAL_DIR/run_eval.sh" --type logic --scenario SYNC-LOGIC-S01 $cache_flag --model "$MODEL" &
    local pid1=$!
    bash "$EVAL_DIR/run_eval.sh" --type logic --scenario SYNC-LOGIC-S02 $cache_flag --model "$MODEL" &
    local pid2=$!
    wait $pid1 $pid2
    echo "  Logic eval complete"
  fi

  # Step 4: Print comparison summary
  echo ""
  echo "=============================="
  echo "Comparison Summary (Run $run_idx)"
  echo "=============================="
  python3 -c "
import json
with open('$compare_output') as f:
    r = json.load(f)

print(f\"  MCP ON  weighted: {r.get('weighted_total_a', 'N/A')}\")
print(f\"  MCP OFF weighted: {r.get('weighted_total_b', 'N/A')}\")
print(f\"  Winner: {r.get('overall_winner', 'N/A')} (delta: {r.get('overall_delta', 'N/A')})\")
print()
for c in r.get('comparison', []):
    print(f\"  {c['dimension']:15s} winner={c['winner']:4s} delta={c['delta']:.1f}  {c['reason']}\")
print()
print(f\"  Summary: {r.get('summary', 'N/A')}\")
"
}

# Run N times
for i in $(seq 1 "$RUNS"); do
  run_single "$i"
done

# Multi-run aggregate
if [[ "$RUNS" -gt 1 ]]; then
  echo ""
  echo "=============================="
  echo "Aggregate Summary ($RUNS runs)"
  echo "=============================="
  python3 -c "
import json, glob
files = sorted(glob.glob('$EVAL_DIR/results/COMPARE-QUAL-run*.json'))
if not files:
    files = ['$EVAL_DIR/results/COMPARE-QUAL.json']

a_totals, b_totals = [], []
winners = {'A': 0, 'B': 0, 'tie': 0}
for f in files:
    with open(f) as fh:
        r = json.load(fh)
    a_totals.append(r.get('weighted_total_a', 0))
    b_totals.append(r.get('weighted_total_b', 0))
    w = r.get('overall_winner', 'tie')
    winners[w] = winners.get(w, 0) + 1

n = len(files)
print(f'  Runs: {n}')
print(f'  MCP ON  avg: {sum(a_totals)/n:.2f}')
print(f'  MCP OFF avg: {sum(b_totals)/n:.2f}')
print(f'  Winners: A(MCP-ON)={winners.get(\"A\",0)}, B(MCP-OFF)={winners.get(\"B\",0)}, tie={winners.get(\"tie\",0)}')
"
fi
