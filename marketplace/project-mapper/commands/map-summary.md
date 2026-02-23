---
name: map-summary
description: "Compress .claude/ docs for LLM context"
---

# /project-mapper:map-summary

Compress `.claude/` documentation into a single LLM-friendly summary.

## Pre-flight

Read `.claude/map.md` and `.claude/design.md` to confirm docs exist. If both missing, tell user to run `/project-mapper:map init` first and STOP.

## Steps

1. Spawn summarizer agent:

```
Task(subagent_type: "project-mapper:summarizer", prompt: "Compress .claude/ documentation into a single summary")
```

2. Display summarizer results.

## Rules

- `subagent_type` MUST use `project-mapper:summarizer` (fully qualified)
