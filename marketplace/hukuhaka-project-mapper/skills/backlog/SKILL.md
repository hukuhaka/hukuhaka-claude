---
name: backlog
description: >
  Capture pre-plan ideas, deferred tasks, and investigation notes to backlog.md
  with codebase research. Use when user wants to quickly add items to backlog
  before formal planning. Do NOT use for full audit (use audit skill) or
  plan-mode work.
hooks:
  PreToolUse:
    - matcher: "Agent|Write"
      hooks:
        - type: command
          command: "printf 'backlog handles capture directly. No Agent spawning, no Write - use Edit on backlog.md only.' >&2; exit 2"
---

# Backlog

Capture items to `.claude/backlog.md` with codebase research. I/O is handled by bundled scripts; research and priority decisions stay in this session.

## Rules

- Do NOT spawn any agents via Agent tool. Handle everything directly
- Do NOT use Read/Glob to load .claude/ docs — invoke `scripts/preflight.sh`
- Do NOT use Edit/Write to add the entry — invoke `scripts/append-entry.py`
- Research (codebase Grep/Read) stays prompt-driven — script can't replace judgment

## Options

- `--priority <high|medium|low>`: Set priority explicitly. If omitted, auto-judge then confirm via AskUserQuestion

## Flow

Execute these 6 steps sequentially.

### 1. Parse

Extract description text and `--priority` option from `$ARGUMENTS`.

### 2. Pre-flight

Load existing context via the bundled script:

```
bash ${CLAUDE_PLUGIN_ROOT}/skills/backlog/scripts/preflight.sh
```

The script cats `.claude/backlog.md` (required), `.claude/map.md`, `.claude/design.md` (if present). If backlog.md is missing, the script exits 1 and you must STOP and tell the user to run `/hukuhaka-project-mapper:map-init` first.

### 3. Duplicate Check

Run the duplicate finder against the candidate description:

```
python3 ${CLAUDE_PLUGIN_ROOT}/skills/backlog/scripts/find-duplicates.py "<description>"
```

The script reports any existing entries with token-overlap ≥ 0.20 (Jaccard). If matches are found, use AskUserQuestion to ask whether to proceed (new entry) or merge into the existing item.

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

### 6. Append + Report

Append the entry via the bundled script:

```
python3 ${CLAUDE_PLUGIN_ROOT}/skills/backlog/scripts/append-entry.py \
  --priority <high|medium|low> \
  --entry '`file:symbol`: description' \
  [--context "Related: file1, file2"] \
  [--behavior "Current: 1-line summary"]
```

Use `--context` and `--behavior` only when research yielded concrete file:symbol anchors. For idea-only entries (no code target), pass `--entry "description"` without backticks.

The script appends under `## Planned > ### {Priority} Priority` and is idempotent. Display its stdout verbatim as the completion report.
