---
name: backlog
description: >
  Capture pre-plan ideas, deferred tasks, and investigation notes to backlog.md
  with codebase research. Use when user wants to quickly add items to backlog
  before formal planning. Do NOT use for full audit (use audit skill) or
  plan-mode work.
---

# Backlog

Capture items to `.claude/backlog.md` with codebase research.

## Rules

- Do NOT spawn any Task agents. Handle everything directly
- If you find yourself spawning an agent, STOP — you are doing it wrong
- NEVER use the Write tool. Only use Edit to modify backlog.md
- backlog.md must exist. If not found, STOP and tell user to run `/project-mapper:map-init`
- Read backlog.md BEFORE any Edit

## Options

- `--priority <high|medium|low>`: Set priority explicitly. If omitted, auto-judge then confirm via AskUserQuestion

## Flow

Execute these 7 steps sequentially.

### 1. Parse

Extract description text and `--priority` option from `$ARGUMENTS`.

### 2. Pre-flight

Read these files (STOP if backlog.md missing):
- `.claude/backlog.md` (required)
- `.claude/map.md` (if exists)
- `.claude/design.md` (if exists)

### 3. Duplicate Check

Compare description against existing backlog items. Check keyword and `file:symbol` overlap. If a similar item exists, inform user and ask whether to proceed or merge.

### 4. Research

Investigate the codebase to find relevant code. See [research-guide.md](references/research-guide.md) for methodology.

- Maximum 3 search rounds (Grep or Glob)
- Result: `file:symbol` anchors + context (2 lines max per anchor)
- If no code target found (pure idea), skip anchors

### 5. Priority

If `--priority` was provided, use it. Otherwise:
1. Auto-judge priority based on research findings and description
2. Present recommendation via AskUserQuestion with options: High, Medium, Low
3. Use confirmed priority

### 6. Edit backlog.md

Use Edit tool to append entry under `## Planned > ### <Priority> Priority`.

Entry format:
- With code target: `- [ ] \`file:symbol\`: description`
- With research context (sub-bullets, max 2 lines):
  ```
  - [ ] `file:symbol`: description
    - Related: file1, file2
    - Current: one-line behavior summary
  ```
- Idea without code target: `- [ ] description`

### 7. Report

Output: "Added to backlog [### Priority]: `file:symbol` — description"
