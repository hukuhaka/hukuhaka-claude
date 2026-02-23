# Sync Pipeline

You MUST execute these 4 steps sequentially. Each step MUST complete before the next begins. Do NOT run steps in parallel. Do NOT skip any step.

## Step 1: Analyze

Spawn exactly 1 analyzer agent:

```
Task(subagent_type: "project-mapper:analyzer", prompt: "Analyze {path}. Context: {map.md + design.md contents}")
```

Wait for the analyzer to return a JSON result. Do NOT proceed until you have the JSON.

## Step 2: Write

After analyzer returns JSON, spawn exactly 1 writer agent with that JSON:

```
Task(subagent_type: "project-mapper:writer", prompt: "Generate .claude/ docs from: {analyzer JSON result}")
```

Do NOT write .claude/ files yourself. Only the writer agent writes files.

## Step 3: Scatter

After writer completes, generate CLAUDE.md in each subdirectory (up to `--depth` levels, default 3).

For each subdirectory, run analyzer then writer sequentially:

```
Task(subagent_type: "project-mapper:analyzer", prompt: "scatter: {folder}")
  → wait for result →
Task(subagent_type: "project-mapper:writer", prompt: "scatter: {scatter JSON}")
```

NEVER touch root `./CLAUDE.md`. Respect `.gitignore` patterns.

## Step 4: Validate

After all scatter pairs complete, spawn exactly 1 validator agent:

```
Task(subagent_type: "project-mapper:validator", prompt: "Validate .claude/ links")
```

## Why Separate Agents?

Analyzer uses read-only tools (Grep, Glob, Read). Writer uses edit tools (Write, Edit). Separating them enforces minimum permissions per agent. The structured JSON interface between them makes the pipeline inspectable and debuggable.

## Final Report

After all 4 steps complete, display this summary:

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

If any step fails, STOP immediately. Do NOT attempt workarounds. Do NOT write .claude/ files directly — only agents write files.
