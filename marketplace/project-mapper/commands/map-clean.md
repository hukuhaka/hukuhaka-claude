---
name: map-clean
description: "Remove scattered CLAUDE.md files"
---

# /project-mapper:map-clean

Remove all scattered CLAUDE.md files from subdirectories. No agents — handle directly.

## Steps

1. Run `Glob: **/CLAUDE.md` to find all CLAUDE.md files
2. Exclude root `./CLAUDE.md` from the results
3. Delete each remaining CLAUDE.md file
4. Report: count deleted, list paths

## Rules

- Do NOT spawn any Task agents
- NEVER delete root `./CLAUDE.md`
