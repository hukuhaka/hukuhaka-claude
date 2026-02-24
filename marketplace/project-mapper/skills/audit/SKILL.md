---
name: audit
description: >
  Analyze codebase for improvement opportunities (large files, dead code,
  duplicates, refactoring, anti-patterns) and add findings to backlog.
  Use when user asks to find issues, code health problems, or improvement items.
---

# Audit

Analyze codebase for improvement opportunities and add findings to backlog.

## Rules

- All `subagent_type` values MUST use `project-mapper:` prefix (e.g., `project-mapper:auditor`)
- Do NOT scan code yourself (no Glob, Read, Grep for analysis). Delegate to auditor agent
- On failure: STOP. Do NOT attempt workarounds
- NEVER use the Write tool. Only use Edit to modify backlog.md (even if file is empty or missing sections)

## Options

- `--focus <category>`: large-files, dead-code, duplicates, refactoring, health, or all (default: all)
- `--threshold <n>`: Line count threshold for large-files category (default: 300)

## Flow

1. Parse options from user input (defaults: focus=all, threshold=300)
2. Spawn exactly 1 auditor agent with parsed options:

```
Task(subagent_type: "project-mapper:auditor", prompt: "Audit codebase. focus: <focus>, threshold: <threshold>")
```

3. Display the auditor's formatted results (already grouped by priority: High/Medium/Low with counts and Stats)
4. Ask user which findings to add to backlog (all, by priority, or specific items)
5. For confirmed findings, Edit `.claude/backlog.md` to append under `## Planned` in the matching priority section:
   - High → `### High Priority`
   - Medium → `### Medium Priority`
   - Low → `### Low Priority`
   - Format: `- [ ] \`file\`: title — suggestion`
