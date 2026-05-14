---
name: map-init
description: "Create .claude/ documentation scaffolding with 4 template files"
---

# /project-mapper:map-init

Create `.claude/` documentation scaffolding with 4 template files via bundled init script. No agents, no inline file writes. spec.md is managed separately by `/project-mapper:map-spec generate`.

## Steps

### Step 1 — Run init script

Invoke the bundled script via Bash from the project root (cwd):

```
bash ${CLAUDE_PLUGIN_ROOT}/skills/map-setup/scripts/init.sh
```

The script copies 4 templates into `.claude/`:
- `.claude/map.md` — Entry Points, Data Flow, Components, Structure
- `.claude/design.md` — Stack, Patterns, Decisions
- `.claude/backlog.md` — `## Planned`, `## In Progress`, `## Discovered TODOs`
- `.claude/changelog.md` — Recent, Archive

### Step 2 — Report

Display the script's stdout verbatim as the completion report. The script already includes the standard "4 template files" message and the spec.md follow-up suggestion — do not paraphrase.

## Rules

- Do NOT spawn any agents via Agent tool
- Do NOT use the Write or Edit tools — invoke only the bundled init script
- Do NOT use AskUserQuestion — init is fully non-interactive
- Do NOT create spec.md — that is managed by the map-spec skill
