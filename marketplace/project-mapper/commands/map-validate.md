---
name: map-validate
description: "Check all .claude/ documentation links"
---

# /project-mapper:map-validate

Validate all file references in `.claude/` documentation.

## Pre-flight

Read `.claude/map.md` and `.claude/design.md` to confirm docs exist. If both missing, tell user to run `/project-mapper:map init` first and STOP.

## Steps

1. Spawn validator agent:

```
Task(subagent_type: "project-mapper:validator", prompt: "Validate all links in .claude/ documentation")
```

2. Display validator results.

## Rules

- `subagent_type` MUST use `project-mapper:validator` (fully qualified)
