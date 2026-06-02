---
name: map-compact
description: "Clean up changelog and backlog docs"
---

# /hukuhaka-project-mapper:map-compact

Clean up changelog.md and backlog.md via two bundled scripts run in sequence.

## Steps

```
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/maintain/compact-changelog.py
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/maintain/clean-backlog.py
```

- `compact-changelog.py`: keeps top 10 entries in `## Recent`, moves older to `## Archive`
- `clean-backlog.py`: moves `- [x]` (completed) items from backlog.md to changelog.md `## Recent`

Display both scripts' stdout verbatim.

## Rules

- Do NOT spawn any agents via Agent tool
- Do NOT use Edit/Write to modify changelog.md or backlog.md — invoke only the bundled scripts
- Both scripts must be run; do not skip either
