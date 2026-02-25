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

Create `.claude/` with 5 files including spec.md. Handle directly — no agents.

### Phase 1: Pre-flight

1. Check `.claude/` existence, check which files exist
2. Detect project state: `Glob("**/*.{py,ts,js,go,rs,java,rb,sh,c,cpp}", head_limit: 20)`
   - 0 source files → Case 1 (new project)
   - 1+ source files → Case 2 (existing project)
3. If `.claude/spec.md` exists: AskUserQuestion "Overwrite existing spec.md or keep it?"
   - If keep → skip spec generation, still create other 4 if missing

### Phase 2: Generate spec.md

Follow [spec-guide.md](references/spec-guide.md).

- Case 1: Interview Protocol (3 AskUserQuestion rounds)
- Case 2: Analysis Protocol (code analysis + 1 confirmation round)

### Phase 3: Write

1. Create `.claude/` if needed
2. Write 5 files using the Write tool:
   - `.claude/map.md` — empty template with sections: Entry Points, Data Flow, Components, Structure
   - `.claude/design.md` — empty template with sections: Stack, Patterns, Decisions
   - `.claude/backlog.md` — MUST include `## Planned`, `## In Progress`, `## Discovered TODOs`
   - `.claude/changelog.md` — empty template with sections: Recent, Archive
   - `.claude/spec.md` — generated from Phase 2
3. Report: "Init complete — created .claude/ with 5 files"

If 4 files exist but spec.md is missing, only create spec.md. Zero Task calls.

## clean

Remove scattered CLAUDE.md files from subdirectories. No agents.

1. `Glob: **/CLAUDE.md` to find all CLAUDE.md files
2. Exclude root `./CLAUDE.md` from results — NEVER delete it
3. Delete each remaining CLAUDE.md file
4. Report: count deleted, list paths
