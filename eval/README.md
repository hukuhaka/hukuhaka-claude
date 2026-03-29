# Eval Framework

Transcript-based LLM-as-judge evaluation for Claude Code skills.

## Eval Types

| Type | Input | Judge | Output |
|------|-------|-------|--------|
| `logic` | Raw transcript | `eval_logic.py` | Per-rule pass/fail (0.0-1.0) |
| `quality` | Extracted `.claude/` docs | `eval_quality.py` | 5-dim rubric (1-5) |
| `audit-quality` | Extracted audit artifacts | `eval_audit_quality.py` | 5-dim rubric (1-5) |
| `skill-quality` | Extracted skill/agent files | `eval_skill_quality.py` | 5-dim rubric (1-5) |
| `orchestration-quality` | Raw transcript | `eval_orchestration_quality.py` | 5-dim rubric (1-5) |

## Running Evals

```bash
# Single scenario
eval/run_eval.sh --type logic --scenario SYNC-LOGIC-S01

# All scenarios in a spec
eval/run_eval.sh --type logic --spec sync-logic

# Reuse transcript, re-run judge only
eval/run_eval.sh --type logic --scenario SYNC-LOGIC-S01 --cache

# Use specific model for judge
eval/run_eval.sh --type quality --scenario SYNC-QUAL-MCP-ON --model opus
```

## Pipeline

```
capture transcript (claude --print) → extract artifacts → LLM judge → score JSON
```

1. **Capture**: Runs Claude CLI in testbed, outputs stream-json transcript
2. **Extract**: Type-specific extraction (docs, findings, skill files)
3. **Judge**: LLM scores against rubric or spec rules
4. **Result**: JSON saved to `eval/results/{ID}.json`

## Adding Scenarios

### 1. Create scenario JSON

```json
{
  "scenario_id": "MY-SCENARIO-S01",
  "scenario_name": "descriptive name",
  "skill": "skill-being-tested",
  "eval_type": "logic|quality|audit-quality|skill-quality|orchestration-quality",
  "spec": "spec-id (logic only)",
  "prompt": "what the user says",
  "cwd": "eval/testbed",
  "model": "sonnet",
  "capture_flags": "--verbose --dangerously-skip-permissions",
  "seed": {}
}
```

Save to `eval/scenarios/{ID}.json`.

### 2. Seed field

Controls testbed initial state:
- `{}` — empty `.claude/` directory
- `{"key": "empty"}` — touch file
- `{"key": "template:name"}` — copy `eval/fixtures/{name}.md`
- `{"key": "literal content"}` — write content directly

### 3. Create spec (logic eval only)

```json
{
  "spec_id": "my-spec",
  "skill": "skill-name",
  "description": "what rules check",
  "rules": [
    {"rule_id": "R-01", "severity": "critical", "type": "must", "description": "..."}
  ],
  "scenarios": ["MY-SCENARIO-S01"]
}
```

Save to `eval/specs/{id}.json`.

## Interpreting Results

### Logic eval
- `score`: 0.0-1.0 (fraction of rules passed)
- `results[]`: per-rule status (pass/fail/skip/unclear) with evidence

### Quality/audit/skill/orchestration-quality eval
- `weighted_total`: 1.0-5.0 (weighted dimension scores)
- `scores`: per-dimension score (1-5) with reasoning

### Common envelope (all types)
- `eval_type`: type identifier
- `score`: normalized 0.0-1.0 (logic as-is, quality types = weighted_total / 5.0)
- `model` / `model_id`: judge model shortname and full ID
- `timestamp`: UTC ISO-8601

## Directory Structure

```
eval/
├── run_eval.sh              # Orchestrator
├── judge_utils.py           # Shared: JSON extraction, Claude CLI invocation
├── eval_logic.py            # Logic judge
├── eval_quality.py          # Documentation quality judge
├── eval_audit_quality.py    # Audit findings quality judge
├── eval_skill_quality.py    # Skill authoring quality judge
├── eval_orchestration_quality.py  # Multi-agent orchestration quality judge
├── extract_docs.py          # Extract .claude/ files from transcript
├── extract_findings.py      # Extract audit artifacts from transcript
├── extract_skill_files.py   # Extract skill/agent files from transcript
├── compare_mcp.sh           # MCP on/off comparison wrapper
├── cleanup.sh               # Archive stale transcripts/results
├── quality-rubric.md        # Documentation quality rubric
├── audit-quality-rubric.md  # Audit findings quality rubric
├── skill-quality-rubric.md  # Skill authoring quality rubric
├── orchestration-quality-rubric.md  # Orchestration quality rubric
├── specs/                   # Logic spec definitions
├── scenarios/               # Test scenario definitions
├── fixtures/                # Seed templates for testbed
├── transcripts/             # Captured JSONL (gitignored)
├── results/                 # Judge output JSON (gitignored)
├── outputs/                 # Extracted artifacts (gitignored)
└── archive/                 # Archived stale artifacts (gitignored)
```

## Maintenance

```bash
# Archive stale files (no matching scenario)
eval/cleanup.sh --stale

# Preview what would be archived
eval/cleanup.sh --stale --dry-run

# Archive stale + reset testbed
eval/cleanup.sh --all
```
