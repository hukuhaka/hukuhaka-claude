---
name: map-verify
description: "Verify spec.md content matches the actual codebase"
---

# /project-mapper:map-verify

Verify that `.claude/spec.md` claims match the actual codebase. Detects drift between documented conventions and code reality.

## Pre-flight

Read `.claude/spec.md` to confirm it exists. If missing, tell user to run `/project-mapper:map-init` first and STOP.

## Steps

1. Spawn verifier agent:

```
Task(subagent_type: "project-mapper:verifier", prompt: "Verify spec.md content against the actual codebase. Read .claude/spec.md, run analysis protocol, compare results, and report drift.")
```

2. Display verifier results.

## Rules

- `subagent_type` MUST use `project-mapper:verifier` (fully qualified)
