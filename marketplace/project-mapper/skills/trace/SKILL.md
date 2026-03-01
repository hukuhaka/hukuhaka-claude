---
name: trace
description: >
  Trace code flow to diagnose bugs, understand data paths, or find error origins.
  Use when user asks to debug, trace, investigate errors, or understand how code
  flows between components. Do NOT use for audit (audit skill) or documentation (map-sync).
---

# Trace

Trace code flow to find where actual behavior diverges from expected.

## Rules

- Do NOT spawn any Task agents. Handle everything directly
- If you find yourself spawning an agent, STOP — you are doing it wrong
- Maximum search rounds: depth option (default 5, max 8)
- NEVER use the Write tool. Trace is read-only analysis (Edit only for optional backlog integration)
- If trace target is too vague, ask for clarification via AskUserQuestion before starting
- Convergence checkpoint: After round 3, present findings and ask user before continuing
- One hypothesis at a time. Do NOT pursue multiple paths in parallel

## Options

- `--type <error|data-flow|dependency|regression>`: Explicit type. Auto-detected if omitted
- `--depth <n>`: Max trace rounds (default 5, max 8)
- `--from <file:symbol>`: Explicit start point (skips Step 4)

## Flow

Execute these 7 steps sequentially.

### 1. Parse

Extract trace target and options from `$ARGUMENTS`.
- Target: the symptom, error message, or question
- Options: `--type`, `--depth`, `--from`

### 2. Pre-flight

MUST Read these files BEFORE any codebase search (Grep/Glob/Read on source code). This step comes first:
- `.claude/map.md` — expected code structure and data flow
- `.claude/design.md` — intended architecture and patterns
- `.claude/spec.md` — interface contracts and invariants

Skip files that do not exist, but do NOT skip this step or reorder it after Step 4.

### 3. Classify

Determine trace type. See [trace-guide.md](references/trace-guide.md) for detection heuristics.

| Type | Signal |
|------|--------|
| error | crash, exception, stack trace, TypeError, null reference |
| data-flow | wrong value, missing field, stale data, transform issue |
| dependency | impact analysis, "what uses X", fan-out question |
| regression | "was working", "broke after", "since update" |

If ambiguous, present options via AskUserQuestion.

### 4. Anchor

Find the starting point using type-specific strategy. See [trace-guide.md](references/trace-guide.md).
- error: Grep error keyword or exception message
- data-flow: Grep/Read symbol definition
- dependency: Grep all references to target
- regression: `git log --oneline -20` + `git diff` on suspect range

Skip if `--from` was provided.

### 5. Trace

Iterative tracing. Each round (max depth):

1. Read current anchor (~50 lines around target)
2. Identify next link: caller, callee, data path, or reference
3. Follow via Grep or Read
4. Record: `{round, file:line, observation, next_hypothesis}`
5. Check convergence: if actual != expected divergence found, stop

### 6. Narrow

Triggered at round 3 OR when convergence detected:

1. Present findings so far to user via AskUserQuestion
2. Show current chain and top hypothesis
3. Ask: continue tracing, change direction, or stop
4. Adjust remaining rounds based on user input

### 7. Report

Output trace result using EXACTLY this structure. Every labeled field is required:

```
## Trace Report

Type: <one of error|data-flow|dependency|regression>
Target: <description of what was traced>
Rounds: <completed>/<max>

### Chain
1. `file:line` — description [START]
2. `file:line` — description
3. `file:line` — description [DIVERGENCE]

### Divergence Point
`file:line` — what happens vs. what should happen

### Next Steps
- Suggested fix or further investigation
- Related: affected files
```

If no divergence found, set Divergence Point to "Not found" and list explored chain with suggested next investigation direction under Next Steps.
