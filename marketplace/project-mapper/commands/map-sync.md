---
name: map-sync
description: "Full sync pipeline: analyze, write, scatter, validate"
---

# /project-mapper:map-sync [path] [options]

Full documentation sync pipeline. Generates `.claude/` docs from codebase analysis.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `--depth <n>` | 3 | Max scatter depth for subdirectory CLAUDE.md generation |

## Why Separate Agents?

Analyzer uses read-only tools to analyze code. Writer uses edit tools to write documentation. Separating them ensures each agent operates with minimum permissions, and the structured JSON interface between them makes the pipeline inspectable and debuggable.

## Pre-flight

Before starting the pipeline, run the bundled preflight script via Bash from the project root (cwd):

```
bash ${CLAUDE_PLUGIN_ROOT}/skills/map-sync/scripts/preflight.sh
```

The script cats `.claude/map.md`, `.claude/design.md`, `.claude/spec.md` (if they exist) into stdout. Capture this output and pass it to the analyzer agent as context.

Do NOT use Bash `ls` to enumerate `.claude/` and do NOT skip preflight. If the script reports `.claude/` does not exist, tell user to run `/project-mapper:map-init` first and STOP.

## Pipeline

Execute these 4 steps **sequentially**. Each step MUST complete before the next begins. Do NOT run steps in parallel.

### Step 1: Analyze

Spawn analyzer agent and wait for JSON result:

```
Agent(subagent_type: "project-mapper:analyzer", prompt: "Analyze {path}. Context: {map.md + design.md contents}")
```

### Step 2: Write

After analyzer completes, spawn writer agent with analyzer output:

```
Agent(subagent_type: "project-mapper:writer", prompt: "Generate .claude/ docs from: {analyzer JSON result}")
```

### Step 3: Scatter

After writer completes, generate `CLAUDE.md` in each subdirectory.

For each subdirectory (up to `--depth` levels):

```
Agent(subagent_type: "project-mapper:analyzer", prompt: "scatter: {folder}")
  → wait for result →
Agent(subagent_type: "project-mapper:writer", prompt: "scatter: {scatter JSON}")
```

Rules:
- Never touch root `./CLAUDE.md`
- Respect `.gitignore` patterns
- Max depth: `--depth` option (default 3)

### Step 4: Validate

After scatter completes, spawn validator agent:

```
Agent(subagent_type: "project-mapper:validator", prompt: "Validate .claude/ links")
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
- Analyzer and writer MUST NOT run in parallel — writer depends on analyzer output
- Scatter analyzer+writer pairs are also sequential per subdirectory
