---
name: map-compact
description: "Clean up changelog and implementation docs"
---

# /project-mapper:map-compact

Clean up changelog.md and implementation.md via writer agent.

## Pre-flight

Read `.claude/map.md` and `.claude/design.md` to confirm docs exist. If both missing, tell user to run `/project-mapper:map init` first and STOP.

## Steps

1. Spawn writer agent with compact instructions:

```
Task(subagent_type: "project-mapper:writer", prompt: "Compact .claude/ docs: consolidate changelog.md (keep recent 10, archive older by month) and clean implementation.md (move completed items to changelog, remove empty sections). Process both files.")
```

2. Display writer results.

## Rules

- `subagent_type` MUST use `project-mapper:writer` (fully qualified)
- Both changelog.md and implementation.md must be processed
