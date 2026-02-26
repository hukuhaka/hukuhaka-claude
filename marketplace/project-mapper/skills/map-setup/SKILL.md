---
name: map-setup
description: >
  Setup and teardown for .claude/ project docs.
  Use when user asks to init or clean .claude/ docs.
  Do NOT use for sync (map-sync), validate/compact/summary (map-maintain), or spec.md (map-spec).
---

# Map Setup

Setup and teardown for `.claude/` project documentation.

## Rules

- Do NOT spawn any Task agents. All subcommands are handled directly.
- If you find yourself spawning an agent for any command below, STOP — you are doing it wrong.
- spec.md is NOT managed by this skill. Use `/project-mapper:map-spec generate` instead.

## init

Create `.claude/` with 4 template files. Handle directly — no agents.

### Phase 1: Pre-flight

1. Check `.claude/` existence, check which files exist

### Phase 2: Write

1. Create `.claude/` if needed
2. Write 4 files using the Write tool:
   - `.claude/map.md` — empty template with sections: Entry Points, Data Flow, Components, Structure
   - `.claude/design.md` — empty template with sections: Stack, Patterns, Decisions
   - `.claude/backlog.md` — MUST include `## Planned`, `## In Progress`, `## Discovered TODOs`
   - `.claude/changelog.md` — empty template with sections: Recent, Archive
3. Report: "Init complete — created .claude/ with 4 template files. Run `/project-mapper:map-spec generate` to create spec.md."

## clean

Remove scattered CLAUDE.md files from subdirectories. No agents.

1. `Glob: **/CLAUDE.md` to find all CLAUDE.md files
2. Exclude root `./CLAUDE.md` from results — NEVER delete it
3. Delete each remaining CLAUDE.md file
4. Report: count deleted, list paths
