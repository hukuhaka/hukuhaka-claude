---
name: improve
description: >
  Use when auditing code health or identifying improvement opportunities before refactoring.
---

# Improve

Analyze codebase and add improvement findings to `.claude/implementation.md`.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `--model <m>` | sonnet | Override agent model |
| `--threshold <n>` | 500 | Line count threshold for large files |
| `--single` | false | Use single agent instead of 3-group parallel |

## Focus Areas

| Area | Description |
|------|-------------|
| `large-files` | Files exceeding line threshold |
| `dead-code` | Exported symbols with no references |
| `duplicates` | Semantically similar code blocks |
| `refactoring` | Long functions, large classes |
| `health` | Anti-patterns from design.md context |

## Usage

```
/project-mapper:improve
/project-mapper:improve large-files
/project-mapper:improve dead-code --threshold 300
/project-mapper:improve --model opus
/project-mapper:improve --single
```

---

## Iron Law

**YOU MUST DELEGATE.** You are an orchestrator, NOT a worker.

You MUST spawn analyzer agent(s) via Task calls. You MUST NOT:
- Analyze code yourself
- Generate findings yourself
- Skip agent spawning for any reason
- Perform the agent's work "because it seems simple"

No exceptions. No shortcuts. No rationalizations.

**Agent for this skill:**

| Agent | Qualified Name | Role |
|-------|---------------|------|
| analyzer | `project-mapper:analyzer` | Code analysis → improvement findings |

---

## Pre-flight

**BEFORE any other action:**

1. Read `.claude/map.md` and `.claude/design.md`
2. If either is missing → inform user: "Run `/project-mapper:map init` first" and STOP
3. Do NOT proceed to agent spawning without project context

---

## The Process

### Step 1: Parse Input

Extract focus area and options from input:
- Focus area: one of `large-files`, `dead-code`, `duplicates`, `refactoring`, `health`, or omit for all
- `--model`: Override model (default: sonnet)
- `--threshold`: Line count threshold (default: 500)
- `--single`: Force single-agent mode

If focus area is provided but invalid, show available areas and ask user to pick one.

**Mode selection:**
- If `--single` is set → single agent mode (Step 2A)
- If a specific focus area is given → single agent mode (Step 2A)
- Otherwise (all categories) → 3-group parallel mode (Step 2B)

### Step 2A: Single Agent Analysis

Used when `--single` or a specific focus area is given.

Launch **exactly ONE** Task call.

**CRITICAL:** subagent_type MUST use fully qualified name `"project-mapper:analyzer"`.

```
Task(
  subagent_type: "project-mapper:analyzer",
  model: {model},
  prompt: "improve: Focus: {area or 'all'}, Threshold: {threshold}
    Context: {map.md} {design.md}
    Analyze and return JSON findings."
)
```

Wait for the agent to return before proceeding to Step 3.

### Step 2B: 3-Group Parallel Analysis (Default)

| Call | Name | subagent_type | Prompt focus |
|------|------|---------------|-------------|
| 1 | Redundancy | `project-mapper:analyzer` | `dead-code AND duplicates` |
| 2 | Structure | `project-mapper:analyzer` | `large-files AND refactoring` |
| 3 | Quality | `project-mapper:analyzer` | `health` |

**CRITICAL:** subagent_type MUST be `"project-mapper:analyzer"` for all three.

```
Task(
  subagent_type: "project-mapper:analyzer",
  model: {model},
  prompt: "
    improve:
    Focus: dead-code, duplicates
    Threshold: {threshold}

    Context from map.md: {map.md contents}
    Context from design.md: {design.md contents}

    ANALYSIS STRATEGY for dead-code + duplicates:

    **Dead Code:**
    1. Use Grep to find all class/function definitions
    2. For each exported symbol, Grep for references across the project
    3. Check: imported elsewhere? Called? Used as base class?
    4. Module-level: entire files/directories nothing imports from?
    5. Look for: unused parameters, unreachable branches, commented-out code

    **Duplicates:**
    1. Compare directories that look like copies
    2. Look for repeated code patterns, copy-pasted logic
    3. Check config/constant definitions repeated across files
    4. Find similar utility functions that could be consolidated

    **Cross-category:** Duplicated code where original became dead. Dead code superseded by duplicate elsewhere.

    Return JSON with findings.
  "
)
```

**Group 2: Structure** (large-files + refactoring)
```
Task(
  subagent_type: "project-mapper:analyzer",
  model: {model},
  prompt: "
    improve:
    Focus: large-files, refactoring
    Threshold: {threshold}

    Context from map.md: {map.md contents}
    Context from design.md: {design.md contents}

    ANALYSIS STRATEGY for large-files + refactoring:

    **Large Files:**
    1. Check line counts of ALL source files
    2. Report files with {threshold}+ lines with exact line count
    3. CRITICAL: Do NOT report files under {threshold} lines

    **Refactoring:**
    1. Functions/methods longer than 50 lines
    2. Classes with >10 methods or >10 params in __init__
    3. Deeply nested code (3+ levels)
    4. Long functions inside large files are especially important

    Return JSON with findings.
  "
)
```

**Group 3: Quality** (health)
```
Task(
  subagent_type: "project-mapper:analyzer",
  model: {model},
  prompt: "
    improve:
    Focus: health
    Threshold: {threshold}

    Context from map.md: {map.md contents}
    Context from design.md: {design.md contents}

    ANALYSIS STRATEGY for health:

    **Bugs:** Variable mismatches, uninitialized vars, FIXME/TODO, zero-division
    **Security:** torch.load, eval/exec, os.system, yaml.full_load, pickle, input validation
    **Anti-patterns:** Bare except, mutable defaults, magic numbers, print vs logging, sys.path hacks

    Read actual source files to verify each finding. Don't guess.

    Return JSON with findings.
  "
)
```

Wait for **all three** agents to return. Merge findings into a single list with sequential IDs.

### Step 3: Display Findings

```markdown
## Improvement Findings

**Scanned:** {files_scanned} files | **Categories:** {categories_checked} | **Findings:** {total_findings}

### Category Name

| # | Priority | Title | Evidence |
|---|----------|-------|----------|
| 1 | high | Split src/handlers/api.py | 580 lines |

### Dead Code

| # | Priority | Title | Evidence |
|---|----------|-------|----------|
| 2 | medium | Remove unused parse_legacy() | 0 references |

...
```

If no findings, inform user and STOP.

### Step 4: Select Findings

```
AskUserQuestion: "Which findings to add to implementation.md?"
Options: All / None / (numbers like "1,3,5")
```

If 'none', STOP.

### Step 5: Merge to implementation.md

Add selected findings to `## Planned` (skip duplicates):
```
- **{prefix}: {title}**: {suggestion}
  - Files: {files}
  - Evidence: {evidence}
```
Prefixes: `Large file`, `Dead code`, `Duplicate code`, `Refactoring`, `Code health`

### Step 6: STOP

**This skill ends here.** Do NOT start implementing any findings.
Wait for user's next instruction.

---

## Common Mistakes

| Mistake | Correction |
|---------|------------|
| Bare agent name `"analyzer"` | Fully qualified `"project-mapper:analyzer"` |
| Analyzing code yourself | ALWAYS spawn agent, even for "simple" checks |
| Skipping .claude/ pre-loading | ALWAYS Read map.md and design.md FIRST |
| Using single agent when no focus area | Default is 3-group parallel (Step 2B) |
| Starting implementation after findings | STOP after displaying results and merging |
| Retrying denied permissions 5+ times | After 2 failures, inform user and ask |
| Output without agent result | Output MUST be based on agent's returned data |

---

## Red Flags

If you find yourself doing any of these, STOP and re-read the Iron Law:

- Using Read/Grep/Glob to analyze code instead of spawning a Task
- Using bare agent names without `project-mapper:` prefix
- Skipping pre-flight .claude/ doc loading
- Continuing after pre-flight failure
- Writing code or fixing issues after displaying results
- Running a single agent when 3-group parallel should be used

---

## Related Skills

- `project-mapper:elaborate` - Break down specific requirements
- `project-mapper:map` - Generate project documentation

## MCP Tools

- `mcp__code-search__search_code`: Used by agent for finding code
- `mcp__code-search__find_similar_code`: Used by agent for duplicates
