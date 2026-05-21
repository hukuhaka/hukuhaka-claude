---
name: map-setup
description: >
  Setup and teardown for .claude/ project docs.
  Use when user asks to init or clean .claude/ docs.
  Do NOT use for sync (map-sync), validate/compact/summary (map-maintain), or spec.md (map-spec).
hooks:
  PreToolUse:
    - matcher: "Agent"
      hooks:
        - type: command
          command: "printf 'map-setup runs init/clean directly. Do not spawn Agent - handle the operation in this session.' >&2; exit 2"
---

# Map Setup

Setup and teardown for `.claude/` project documentation. Work is done by bundled scripts — no agents, no inline file writes.

## Rules

- Do NOT spawn any agents (no `Agent` / `Task` calls)
- Do NOT use `Write` or `Edit` to create the docs yourself — invoke the bundled script
- spec.md is NOT managed by this skill. Use `/hukuhaka-project-mapper:map-spec generate` instead

## init

Run the init script via Bash from the project root (cwd):

```
bash ${CLAUDE_PLUGIN_ROOT}/skills/map-setup/scripts/init.sh
```

The script copies 4 templates into `.claude/`:
- `.claude/map.md` — Entry Points, Data Flow, Components, Structure
- `.claude/design.md` — Stack, Patterns, Decisions
- `.claude/backlog.md` — `## Planned`, `## In Progress`, `## Discovered TODOs`
- `.claude/changelog.md` — Recent, Archive

After the Bash call returns, display the script's stdout verbatim as the completion report. The script already includes the standard "4 template files" message and the spec.md follow-up suggestion — do not paraphrase.

## clean

Run the clean script via Bash from the project root:

```
bash ${CLAUDE_PLUGIN_ROOT}/skills/map-setup/scripts/clean.sh
```

The script removes scattered `CLAUDE.md` files from subdirectories. Root `./CLAUDE.md` is always preserved.

After the Bash call returns, display the script's stdout verbatim.
