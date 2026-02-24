---
name: audit
description: >
  Analyze codebase for improvement opportunities (large files, dead code,
  duplicates, refactoring, anti-patterns) and add findings to backlog.
  Use when user asks to find issues, code health problems, or improvement items.
---

# Audit

Analyze codebase for improvement opportunities via 2-agent pipeline, then add findings to backlog.

## Rules

- All `subagent_type` values MUST use `project-mapper:` prefix (e.g., `project-mapper:auditor`)
- Do NOT scan code yourself (no Glob, Read, Grep for analysis). Delegate to agents
- On failure: STOP. Do NOT attempt workarounds
- NEVER use the Write tool. Only use Edit to modify backlog.md

## Options

- `--focus <category>`: large-files, dead-code, duplicates, refactoring, health, or all (default: all)
- `--threshold <n>`: Line count threshold for large-files category (default: 300)

## Flow

Sequential 2-agent pipeline. See [audit-pipeline.md](references/audit-pipeline.md) for detailed steps.

1. Parse options from user input (defaults: focus=all, threshold=300)
2. **Step 1** — Spawn exactly 1 `project-mapper:auditor` Task → returns context JSON
3. **Step 2** — Spawn exactly 1 `project-mapper:analyzer` Task (improve mode + context from Step 1) → returns findings JSON
4. Format findings grouped by priority (see Output Template)
5. Ask user which findings to add to backlog (all, by priority, or specific items)
6. For confirmed findings, Edit `.claude/backlog.md` to append under `## Planned` in the matching priority section

## Output Template

```
## Audit Results

### High Priority (N items)
- `file:line` title [confidence] effort:small — suggestion

### Medium Priority (N items)
- `file:line` title [confidence] effort:medium — suggestion

### Low Priority (N items)
- `file:line` title [confidence] effort:large — suggestion

Stats: N files scanned, N categories checked, N total findings (N high-confidence, N medium, N low)
```

Each finding includes confidence (`[high]`/`[medium]`/`[low]`) and effort (`effort:small`/`effort:medium`/`effort:large`). Omit empty priority sections. Always include Stats line.

## Backlog Format

- High → `### High Priority`
- Medium → `### Medium Priority`
- Low → `### Low Priority`
- Format: `- [ ] \`file\`: title [confidence] — suggestion`
