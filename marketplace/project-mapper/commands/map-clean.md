---
name: map-clean
description: "Remove scattered CLAUDE.md files"
---

# /project-mapper:map-clean

Remove all scattered CLAUDE.md files from subdirectories via bundled clean script. No agents.

## Steps

Invoke the bundled script via Bash from the project root (cwd):

```
bash ${CLAUDE_PLUGIN_ROOT}/skills/map-setup/scripts/clean.sh
```

The script removes scattered `CLAUDE.md` files. Root `./CLAUDE.md` is always preserved.

Display the script's stdout verbatim as the completion report.

## Rules

- Do NOT spawn any agents via Agent tool
- Do NOT use Glob/Read/Bash directly to find or delete CLAUDE.md — invoke only the bundled clean script
- NEVER delete root `./CLAUDE.md` (the script enforces this)
