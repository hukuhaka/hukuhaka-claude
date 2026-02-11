---
name: elaborate
description: >
  Use when breaking down a requirement into concrete implementation tasks for .claude/implementation.md.
---

# Elaborate

Convert requirements into detailed, actionable tasks for `.claude/implementation.md`.

## Purpose

- Break down high-level requirements into concrete tasks
- Identify affected files and architecture impact
- Generate structured plans ready for implementation

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `--model <m>` | opus | Override agent model |

## Usage

```
/project-mapper:elaborate Add email verification to signup
/project-mapper:elaborate Fix memory leak in event listener
/project-mapper:elaborate Refactor test files to use fixtures
```

---

## Iron Law

**YOU MUST DELEGATE.** You are an orchestrator, NOT a worker.

You MUST spawn the elaborator agent via a Task call. You MUST NOT:
- Analyze the requirement yourself
- Validate feasibility yourself
- Make judgments about applicability
- Skip agent spawning for any reason
- Perform the agent's work "because it seems simple"

Even if the requirement seems inapplicable to the project, the agent handles all analysis.

No exceptions. No shortcuts. No rationalizations.

**Agent for this skill:**

| Agent | Qualified Name | Role |
|-------|---------------|------|
| elaborator | `project-mapper:elaborator` | Requirement → tasks breakdown |

---

## Pre-flight

**BEFORE any other action:**

1. Read `.claude/map.md` and `.claude/design.md`
2. If either is missing → inform user: "Run `/project-mapper:map init` first" and STOP
3. Do NOT proceed without project context

---

## The Process

### Step 1: Parse Input

Extract requirement from input. Parse options:
- `--model`: Override model (default: opus)

If no requirement provided, ask user for requirement.

### Step 2: Delegate to Elaborator

Launch **exactly ONE** Task call.

**CRITICAL:** subagent_type MUST use fully qualified name `"project-mapper:elaborator"`.

```
Task(
  subagent_type: "project-mapper:elaborator",
  model: {model or "opus"},
  prompt: "
    Requirement: {requirement}

    Context from map.md:
    {map.md contents}

    Context from design.md:
    {design.md contents}

    Return JSON with tasks, affected files, and architecture impact.
  "
)
```

Wait for the agent to return before proceeding.

### Step 3: Display Result

Show the JSON result to user in formatted output:

```markdown
## Elaboration Result

**Requirement:** {requirement}
**Type:** {type}

### Tasks

1. **{task.title}**
   - {task.description}
   - Files: {task.files_affected}
   - Criteria: {task.acceptance_criteria}

### Architecture Impact

- Scope: {scope}
- Decisions affected: {decisions_affected}
- New patterns: {new_patterns}

### Prerequisites

- {prerequisites}
```

### Step 4: Confirm

Ask user:

```
AskUserQuestion: "Add these tasks to implementation.md?"
Options:
- Yes: Proceed to Step 5
- No: Exit without changes
- Edit: Allow user to modify, then re-confirm
```

### Step 5: Merge to implementation.md

1. Read existing `.claude/implementation.md`
2. Parse the `## Planned` section
3. For each new task:
   - Check for duplicate titles (skip if exists)
   - Add to Planned section with format:
     ```
     - **{title}**: {description}
       - Files: {files}
       - Criteria: {criteria}
     ```
4. Write updated implementation.md
5. Confirm: "Added {n} tasks to implementation.md"

### Step 6: STOP

**This skill ends here.** Do NOT start implementing.
Wait for user's next instruction.

---

## Common Mistakes

| Mistake | Correction |
|---------|------------|
| Bare agent name `"elaborator"` | Fully qualified `"project-mapper:elaborator"` |
| Analyzing requirement yourself | ALWAYS spawn agent, even for "simple" requirements |
| Judging requirement as inapplicable | Let agent decide — it has full code context |
| Skipping .claude/ pre-loading | ALWAYS Read map.md and design.md FIRST |
| Starting implementation after elaboration | STOP after displaying results and merging |
| Retrying denied permissions 5+ times | After 2 failures, inform user and ask |
| Output without agent result | Output MUST be based on agent's returned data |

---

## Red Flags

If you find yourself doing any of these, STOP and re-read the Iron Law:

- Using Read/Grep/Glob to analyze code instead of spawning a Task
- Using bare agent names without `project-mapper:` prefix
- Skipping pre-flight .claude/ doc loading
- Continuing after pre-flight failure
- Writing code or starting implementation after displaying results
- Deciding a requirement is "not applicable" without agent analysis

---

## Related Skills

- `project-mapper:improve` - Discover improvement opportunities
- `project-mapper:map` - Generate project documentation

## MCP Tools

- `mcp__code-search__search_code`: Used by agent for finding relevant code
