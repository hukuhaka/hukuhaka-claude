---
name: map-sync
description: "Full sync pipeline: analyze, write, scatter, validate"
---

# /project-mapper:map-sync [path] [options]

Full documentation sync pipeline. Generates `.claude/` docs from codebase analysis.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `--model <m>` | (per agent) | Override model for all agents: `haiku`, `sonnet`, `opus` |
| `--depth <n>` | 3 | Max scatter depth for subdirectory CLAUDE.md generation |

## Why Separate Agents?

Analyzer uses read-only tools to analyze code. Writer uses edit tools to write documentation. Separating them ensures each agent operates with minimum permissions, and the structured JSON interface between them makes the pipeline inspectable and debuggable.

## Pre-flight

Before starting the pipeline, read `.claude/map.md` and `.claude/design.md` (if they exist). Pass their contents to analyzer for context. If both are missing and `.claude/` does not exist, tell user to run `/project-mapper:map init` first and STOP.

## Pipeline

Execute these 4 steps **sequentially**. Each step MUST complete before the next begins. Do NOT run steps in parallel.

### Step 1: Analyze

Spawn analyzer agent and wait for JSON result:

```
Task(subagent_type: "project-mapper:analyzer", model: {model}, prompt: "Analyze {path}. Context: {map.md + design.md contents}")
```

### Step 2: Write

After analyzer completes, spawn writer agent with analyzer output:

```
Task(subagent_type: "project-mapper:writer", model: {model}, prompt: "Generate .claude/ docs from: {analyzer JSON result}")
```

### Step 3: Scatter

After writer completes, generate `CLAUDE.md` in each subdirectory.

For each subdirectory (up to `--depth` levels):

```
Task(subagent_type: "project-mapper:analyzer", model: {model}, prompt: "scatter: {folder}")
  → wait for result →
Task(subagent_type: "project-mapper:writer", model: {model} or "haiku", prompt: "scatter: {scatter JSON}")
```

Rules:
- Never touch root `./CLAUDE.md`
- Respect `.gitignore` patterns
- Max depth: `--depth` option (default 3)

### Step 4: Validate

After scatter completes, spawn validator agent:

```
Task(subagent_type: "project-mapper:validator", model: {model}, prompt: "Validate .claude/ links")
```

## Final Report

After all steps complete, display:

```
Sync complete
  Step 1 (analyze)
    Files scanned: {n}

  Step 2 (write)
    Docs generated: 4

  Step 3 (scatter)
    CLAUDE.md created: {n}

  Step 4 (validate)
    Links checked: {n}
    Broken: {n}
```

## On Failure

If any step fails, STOP and explain the failure. Do NOT attempt workarounds. Do NOT write `.claude/` files directly — only agents write files.

## Critical Rules

- All `subagent_type` values MUST use `project-mapper:` prefix (e.g., `project-mapper:analyzer`)
- When `--model` is specified, pass that model to ALL Task calls
- Analyzer and writer MUST NOT run in parallel — writer depends on analyzer output
- Scatter analyzer+writer pairs are also sequential per subdirectory
