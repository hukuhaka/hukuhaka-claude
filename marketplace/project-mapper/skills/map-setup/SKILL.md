---
name: map-setup
description: >
  Setup and teardown for .claude/ project docs.
  Use when user asks to init or clean .claude/ docs.
  Do NOT use for sync (map-sync) or validate/compact/summary (map-maintain).
---

# Map Setup

Setup and teardown for `.claude/` project documentation.

## Rules

- Do NOT spawn any Task agents. All subcommands are handled directly.
- If you find yourself spawning an agent for any command below, STOP — you are doing it wrong.

## init

Create empty `.claude/` template. Handle directly — no agents.

1. Create `.claude/` directory if it does not exist
2. Write these 4 files using the Write tool:
   - `.claude/map.md` — empty template with sections: Entry Points, Data Flow, Components, Structure
   - `.claude/design.md` — empty template with sections: Stack, Patterns, Decisions
   - `.claude/implementation.md` — MUST include `## Planned`, `## In Progress`, `## Discovered TODOs`
   - `.claude/changelog.md` — empty template with sections: Recent, Archive
3. Report: "Init complete — created .claude/ with 4 template files"

If files already exist, overwrite with fresh templates. Zero Task calls.

## clean

Remove scattered CLAUDE.md files from subdirectories. No agents.

1. `Glob: **/CLAUDE.md` to find all CLAUDE.md files
2. Exclude root `./CLAUDE.md` from results — NEVER delete it
3. Delete each remaining CLAUDE.md file
4. Report: count deleted, list paths
