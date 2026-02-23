---
name: map-maintain
description: >
  Maintain existing .claude/ documentation quality.
  Use when user asks to validate, compact, or summarize .claude/ docs.
  Do NOT use for sync (map-sync) or init/clean/status (map-setup).
---

# Map Maintain

Maintain existing `.claude/` documentation quality.

## Rules

- All `subagent_type` values MUST use `project-mapper:` prefix (e.g., `project-mapper:validator`)
- Before spawning any agent, Read `.claude/map.md` and `.claude/design.md` (if they exist) and include their contents in the agent prompt as context
- On failure: STOP. Do NOT attempt workarounds

## validate

Check all `.claude/` documentation links.
Spawn exactly 1 validator agent. Nothing else.

```
Task(subagent_type: "project-mapper:validator", prompt: "Validate all links in .claude/ documentation")
```

Display the validator's result. Do NOT validate links yourself.

## compact

Clean up changelog.md and implementation.md.
Spawn exactly 1 writer agent. The writer MUST process both files.

```
Task(subagent_type: "project-mapper:writer", prompt: "Compact .claude/ docs: consolidate changelog.md (keep recent 10, archive older by month) and clean implementation.md (move completed items to changelog, remove empty sections). Process both files.")
```

Do NOT read the files and decide they are "already clean" yourself. The writer agent makes that decision.
For format rules, see [format-rules.md](references/format-rules.md).

## summary

Compress `.claude/` docs into LLM-friendly summary.
Spawn exactly 1 summarizer agent. Nothing else.

```
Task(subagent_type: "project-mapper:summarizer", prompt: "Compress .claude/ documentation into a single summary")
```

Display the summarizer's result. Do NOT summarize docs yourself.
