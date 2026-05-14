---
name: audit
description: >
  Analyze codebase for improvement opportunities (large files, dead code,
  duplicates, refactoring, anti-patterns) and add findings to backlog.
  Use when user asks to find issues, code health problems, or improvement items.
hooks:
  PreToolUse:
    - matcher: "Write"
      hooks:
        - type: command
          command: "printf 'audit only modifies backlog.md via Edit. Do not Write - use Edit on backlog.md instead.' >&2; exit 2"
---

# Audit

Analyze codebase for improvement opportunities via 2-agent pipeline. Format the findings via the bundled script (deterministic priority grouping). Then add confirmed items to backlog.

## Rules

- All `subagent_type` values MUST use `project-mapper:` prefix (e.g., `project-mapper:auditor`)
- Do NOT scan code yourself (no Glob, Read, Grep for analysis). Delegate to agents
- On failure: STOP. Do NOT attempt workarounds
- NEVER use the Write tool. Only use Edit to modify backlog.md
- Do NOT format findings yourself — pipe analyzer JSON through the bundled formatter

## Options

- `--focus <category>`: large-files, dead-code, duplicates, refactoring, health, or all (default: all)
- `--threshold <n>`: Line count threshold for large-files category (default: 300)

## Flow

Sequential 2-agent pipeline + script-based formatting + backlog edit. See [audit-pipeline.md](references/audit-pipeline.md) for agent steps.

1. Parse options from user input (defaults: focus=all, threshold=300)
2. **Step 1** — Spawn exactly 1 `project-mapper:auditor` Agent → returns context JSON
3. **Step 2** — Spawn exactly 1 `project-mapper:analyzer` Agent (improve mode + context from Step 1) → returns findings JSON
4. **Step 3** — Pipe the analyzer's findings JSON through the formatter script via Bash:

   ```
   cat <<'EOF' | python3 ${CLAUDE_PLUGIN_ROOT}/skills/audit/scripts/format-findings.py
   <paste analyzer JSON here verbatim>
   EOF
   ```

   Display the script's stdout verbatim. The script produces the standardized `## Audit Results` block with `### High Priority`, `### Medium Priority`, `### Low Priority` groups and a `Stats:` line — do not paraphrase or reformat.

5. **Step 4** — Use AskUserQuestion to ask which findings to add to backlog (all, by priority, or specific items)
6. **Step 5** — For confirmed findings, Edit `.claude/backlog.md` to append under `## Planned` in the matching priority section

## Backlog Format

- High → `### High Priority`
- Medium → `### Medium Priority`
- Low → `### Low Priority`
- Format: `- [ ] \`file\`: title [confidence] effort:size — suggestion` (size = small | medium | large)
