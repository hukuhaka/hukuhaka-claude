# Spec-First Development

> Source of truth: `.claude/`, not code

**BEFORE ANY CODING**: Read these files if they exist:
- `.claude/map.md` - codebase structure
- `.claude/design.md` - architecture decisions
- `.claude/backlog.md` - current tasks

If `.claude/` docs don't exist, run `/project-mapper:map init`

## Docs

- [map.md](.claude/map.md): codebase structure, entry points
- [design.md](.claude/design.md): tech spec, architecture decisions
- [backlog.md](.claude/backlog.md): Planned, In Progress, TODOs
- [changelog.md](.claude/changelog.md): Recent (load) + Archive (on demand)

## Doc Format

Style: `[name](path): description` (llms.txt)

| File | Content |
|------|---------|
| map.md | entries, flow only |
| design.md | tech stack, `file:symbol` pointers |
| backlog.md | Planned, In Progress, TODOs |
| changelog.md | Recent only (Archive on demand) |

Guidelines:
- Target: map <100, design <100 lines (flexible for large projects)
- **NEVER** use: ASCII art, code blocks, long tables
- Prefer: `file:symbol` over code snippets

## Workflow

1. Read → `.claude/map.md`, `design.md`, `backlog.md`
2. Locate → find relevant files via `map.md`
3. Context → understand architecture via `design.md`
4. Implement → follow `design.md` patterns
5. Verify → tests (`make test` or project-specific)
6. Sync → if reality ≠ design, update `design.md`
7. Archive → completed tasks → `changelog.md`

## Task (Subagent) Rules

- Pass objective context, not just query
- Evaluate returns with follow-up questions (max 3 cycles)
- Model selection: Haiku(simple) / Sonnet(default) / Opus(5+ files, architecture)

## Rules

**IMPORTANT**: Read `.claude/` docs before coding

- No features outside `design.md`
- No "done" without tests
- No file deletion without confirmation
- Clean `backlog.md` after task completion
- Style/format changes? Check full scope first
- Ambiguous? Ask

## Eval

Transcript-based LLM-as-judge evaluation. 3 eval types, each with its own pipeline.

### Types

| Type | Extract | Judge | Rubric/Spec |
|------|---------|-------|-------------|
| `logic` | (none — raw transcript) | [eval_logic.py](eval/eval_logic.py): truncate transcript → spec rules pass/fail | `eval/specs/*.json`: per-rule pass/fail |
| `quality` | [extract_docs.py](eval/extract_docs.py): Write tool calls → `.claude/` files | [eval_quality.py](eval/eval_quality.py): 5-dim rubric scoring (1-5) | [quality-rubric.md](eval/quality-rubric.md): completeness, accuracy, depth, format, coherence |
| `audit-quality` | [extract_findings.py](eval/extract_findings.py): 3 artifacts (findings.json, formatted_output.md, backlog_edit.md) | [eval_audit_quality.py](eval/eval_audit_quality.py): 5-dim rubric scoring (1-5) | [audit-quality-rubric.md](eval/audit-quality-rubric.md): evidence, actionability, calibration, coverage, fidelity |

### Run

```
eval/run_eval.sh --type <logic|quality|audit-quality> --scenario <ID> [--cache] [--model <model>]
eval/run_eval.sh --type logic --spec <spec-id>   # all scenarios in spec
```

`--cache`: reuse captured transcript, re-run judge only

### Structure

- `eval/specs/`: rule definitions (logic) or quality rules (cross-check)
- `eval/scenarios/`: scenario JSON (prompt, cwd, eval_type, capture_flags)
- `eval/transcripts/`: captured JSONL (gitignored)
- `eval/outputs/`: extracted artifacts per scenario (gitignored)
- `eval/results/`: judge output JSON (gitignored)

### Workflow: Modify → Validate → Deploy → Eval

1. Modify skill/agent files
2. `scripts/validate.sh` — JSON lint, frontmatter, deploy dry-run
3. `scripts/deploy.sh` — copy to `~/.claude/plugins/`
4. `eval/run_eval.sh --type <type> --scenario <ID>` — capture + judge
5. `eval/run_eval.sh --type <type> --scenario <ID> --cache` — re-judge only

## Git

Do not include 'Co-authored-by' or any co-worker attributions in commit messages.
