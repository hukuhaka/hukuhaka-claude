---
name: map-sync
description: >
  Generate .claude/ project documentation via sync pipeline.
  Use when user asks to map or sync .claude/ docs.
  Do NOT use for init/clean/status (map-setup) or validate/compact/summary (map-maintain).
hooks:
  PreToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: "printf 'map-sync orchestrates agents. Only the writer agent modifies .claude/ files. Delegate via Agent tool.' >&2; exit 2"
---

# Map Sync

Generate `.claude/` project documentation via agent pipeline.

## Rules

- All `subagent_type` values MUST use `project-mapper:` prefix (e.g., `project-mapper:analyzer`)
- Pre-flight MUST run the bundled `scripts/preflight.sh` to load existing `.claude/` docs into context — do NOT use `ls` or freeform Read calls
- On failure: STOP. Do NOT attempt workarounds

Full 5-step pipeline: preflight (script), analyze, write, scatter, validate.
Agents: `project-mapper:analyzer` → `project-mapper:writer` → `project-mapper:validator`
Options: `--path <p>` (target directory, default `.`), `--depth <n>` (scatter depth, default 3)
For detailed steps, see [sync-pipeline.md](references/sync-pipeline.md) and [format-rules.md](references/format-rules.md).
