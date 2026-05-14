---
name: map-validate
description: "Check all .claude/ documentation links"
---

# /project-mapper:map-validate

Validate all file references in `.claude/` documentation via bundled script.

## Steps

Run the link validator from the project root (cwd):

```
python3 ${CLAUDE_PLUGIN_ROOT}/skills/map-maintain/scripts/validate-links.py
```

Display the script's stdout verbatim. Exit code 1 → at least one broken link.

## Rules

- Do NOT spawn any agents via Agent tool
- Do NOT use Read/Glob/Grep to validate manually — invoke only the bundled script
