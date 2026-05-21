---
name: map-maintain
description: >
  Maintain existing .claude/ documentation quality.
  Use when user asks to validate, compact, or summarize .claude/ docs.
  Do NOT use for sync (map-sync) or init/clean/status (map-setup).
hooks:
  PreToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: "printf 'map-maintain orchestrates agents. Delegate file changes to writer/summarizer agents via Agent tool.' >&2; exit 2"
---

# Map Maintain

Maintain existing `.claude/` documentation quality. validate / compact via bundled scripts, summary via summarizer agent (generative task).

## Rules

- All `subagent_type` values MUST use `hukuhaka-project-mapper:` prefix
- validate / compact: invoke bundled scripts only — do NOT spawn agents
- summary: invoke summarizer agent — do NOT use scripts
- On failure: STOP. Do NOT attempt workarounds

## validate

Run the bundled link validator via Bash:

```
python3 ${CLAUDE_PLUGIN_ROOT}/skills/map-maintain/scripts/validate-links.py
```

Reports `[text](path)` link integrity across `.claude/*.md`. Display the script's stdout verbatim. Exit code 1 indicates broken links.

## compact

Clean up changelog.md and backlog.md via two bundled scripts run in sequence:

```
python3 ${CLAUDE_PLUGIN_ROOT}/skills/map-maintain/scripts/compact-changelog.py
python3 ${CLAUDE_PLUGIN_ROOT}/skills/map-maintain/scripts/clean-backlog.py
```

- `compact-changelog.py`: keeps top 10 in `## Recent`, moves older to `## Archive`
- `clean-backlog.py`: moves `- [x]` items from backlog.md to changelog.md `## Recent`

Display both scripts' stdout verbatim. For format details, see [format-rules.md](references/format-rules.md).

## summary

Compress `.claude/` docs into LLM-friendly summary via summarizer agent:

```
Agent(subagent_type: "hukuhaka-project-mapper:summarizer", prompt: "Compress .claude/ documentation into a single summary")
```

Display the agent's result. This is genuine compression — scripts cannot replace.
