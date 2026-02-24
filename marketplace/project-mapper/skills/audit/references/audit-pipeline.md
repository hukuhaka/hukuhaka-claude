# Audit Pipeline

You MUST execute these 2 steps sequentially. Each step MUST complete before the next begins. Do NOT run steps in parallel. Do NOT skip any step.

## Step 1: Gather Context

Spawn exactly 1 auditor agent:

```
Task(subagent_type: "project-mapper:auditor", prompt: "Gather project context. focus: <focus>, threshold: <threshold>")
```

Wait for the auditor to return a context JSON result. Do NOT proceed until you have the JSON.

Expected output: `{project_context, tech_stack, file_count, source_dirs}`

## Step 2: Analyze

After auditor returns context JSON, spawn exactly 1 analyzer agent in improve mode with that context:

```
Task(subagent_type: "project-mapper:analyzer", prompt: "improve: Analyze codebase for improvement opportunities. focus: <focus>, threshold: <threshold>. Project context: <auditor context JSON>. IMPORTANT: Every finding must include confidence (high/medium/low) and effort (small/medium/large). Verify each finding with at least 1 Grep or Read call — do not report based on file names or sizes alone. For dead-code, confirm 0 references. For duplicates, compare actual code blocks. For large-files, read and identify responsibility boundaries. Max 15 findings.")
```

Wait for the analyzer to return a findings JSON result. Do NOT proceed until you have the JSON.

Expected output: `{stats, findings}` — see analyzer.md Improve Mode for full schema.

## Why Separate Agents?

Auditor gathers lightweight context (design.md, directory structure). Analyzer does deep code analysis (Grep, Read, pattern matching). Separating them ensures the analyzer receives structured project context without duplicating effort, and each agent has minimum required permissions.

## Rules

- You MUST complete Step 1 before starting Step 2
- Do NOT analyze code directly — only agents produce findings
- Do NOT spawn any other agents beyond 1 auditor + 1 analyzer
- On failure at any step: STOP immediately. Do NOT attempt workarounds
