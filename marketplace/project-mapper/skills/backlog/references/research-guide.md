# Research Guide

Codebase investigation methodology for backlog item capture. The backlog skill references this before Step 4.

## Process

1. **Extract keywords** — From user description, identify: function/class names, file paths, module names, domain terms
2. **Targeted search** (max 3 rounds) — Use Grep or Glob to locate relevant code
3. **Select anchor** — Pick the most relevant `file:symbol` as primary anchor
4. **Context lines** — Read the anchor location, summarize current behavior in 1-2 lines

## Search Strategy by Task Type

### bug / fix

1. `Grep(pattern: "<error_keyword>")` — find error source
2. `Read(file_path: "<matched_file>")` — understand surrounding logic
3. Anchor: `file:function_or_line` where bug manifests

### feature / add

1. `Grep(pattern: "<related_module>")` or `Glob(pattern: "**/<likely_path>")` — find extension point
2. `Read(file_path: "<candidate>")` — confirm integration surface
3. Anchor: `file:symbol` where new code would attach

### refactor

1. `Grep(pattern: "<target_pattern>")` — find all occurrences
2. `Glob(pattern: "<file_pattern>")` — scope affected files
3. Anchor: `file:symbol` of primary target, Related: list of affected files

### idea (no specific code target)

1. `Grep(pattern: "<closest_keyword>")` — attempt to find related code
2. If nothing relevant found, skip anchor — entry will be idea-only format
3. No anchor required

## Rules

- Maximum 3 search rounds total (Grep or Glob calls)
- Each anchor gets at most 2 lines of context
- Do NOT deep-dive into implementation details — this is capture, not analysis
- If search yields nothing relevant, proceed without anchors
