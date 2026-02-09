---
name: improve
description: >
  Analyze codebase for improvement opportunities.
  Finds large files, dead code, duplicates, refactoring targets, and code health issues.
---

# Improve

Analyze codebase and add improvement findings to `.claude/implementation.md`.

## Usage

```
/project-mapper:improve
/project-mapper:improve large-files
/project-mapper:improve --model opus --single
```

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `--model <m>` | sonnet | Override agent model |
| `--threshold <n>` | 500 | Line count threshold for large files |
| `--single` | false | Force single agent mode |

<workflow>

### Step 1: Parse Input

- If a specific focus area is given (`large-files`, `dead-code`, `duplicates`, `refactoring`, `health`) or `--single` → **single agent mode** (Step 3A)
- Otherwise → **3-agent parallel mode** (Step 3B)

### Step 2: Context Loading

Read `.claude/map.md` and `.claude/design.md`. If missing, tell user to run `/project-mapper:map init`.

### Step 3A: Single Agent Mode

One Task call:

```
Task(
  subagent_type: "project-mapper:analyzer",
  model: {model},
  prompt: "improve: Focus: {area or 'all'}, Threshold: {threshold}
    Context: {map.md} {design.md}
    Analyze and return JSON findings."
)
```

### Step 3B: 3-Agent Parallel Mode (Default)

Make exactly 3 Task calls in one message. No more, no less. Do not regroup or reorganize these calls.

| Call | Name | subagent_type | Prompt focus |
|------|------|---------------|-------------|
| 1 | Redundancy | `project-mapper:analyzer` | `dead-code AND duplicates` |
| 2 | Structure | `project-mapper:analyzer` | `large-files AND refactoring` |
| 3 | Quality | `project-mapper:analyzer` | `health` |

Each Task prompt follows this template (substitute the row values):

```
Task(
  subagent_type: "project-mapper:analyzer",
  model: {model},
  prompt: "improve: Focus: {prompt_focus}. Threshold: {threshold}.
    Context: {map.md} {design.md}
    Analyze the codebase for the specified focus areas and return JSON findings."
)
```

Merge all 3 results into one list with sequential IDs.

### Step 4: Display Findings

```markdown
## Improvement Findings

**Scanned:** {files_scanned} files | **Findings:** {total_findings}

### Category Name

| # | Priority | Title | Evidence |
|---|----------|-------|----------|
| 1 | high | ... | ... |
```

If no findings, inform user and STOP.

### Step 5: Select Findings

```
AskUserQuestion: "Which findings to add to implementation.md?"
Options: All / None / (numbers like "1,3,5")
```

If 'none', STOP.

### Step 6: Merge to implementation.md

Add selected findings to `## Planned` (skip duplicates):
```
- **{prefix}: {title}**: {suggestion}
  - Files: {files}
  - Evidence: {evidence}
```
Prefixes: `Large file`, `Dead code`, `Duplicate code`, `Refactoring`, `Code health`

### Step 7: STOP

Do NOT implement findings. Wait for user.

</workflow>
