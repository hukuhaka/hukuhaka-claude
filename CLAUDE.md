# Spec-First Development

> Source of truth: `.claude/`, not code

**BEFORE ANY CODING**: Read these files if they exist:
- `.claude/map.md` - codebase structure
- `.claude/design.md` - architecture decisions
- `.claude/backlog.md` - current tasks

If `.claude/` docs don't exist, run `/project-mapper:map init`

## Docs

- [map.md](.claude/map.md): codebase structure, entry points
- [design.md](.claude/design.md): tech spec, architecture decisions
- [backlog.md](.claude/backlog.md): Planned, In Progress, TODOs
- [changelog.md](.claude/changelog.md): Recent (load) + Archive (on demand)

## Doc Format

Style: `[name](path): description` (llms.txt)

| File | Content |
|------|---------|
| map.md | entries, flow only |
| design.md | tech stack, `file:symbol` pointers |
| backlog.md | Planned, In Progress, TODOs |
| changelog.md | Recent only (Archive on demand) |

Guidelines:
- Target: map <100, design <100 lines (flexible for large projects)
- **NEVER** use: ASCII art, code blocks, long tables
- Prefer: `file:symbol` over code snippets

## Workflow

1. Read → `.claude/map.md`, `design.md`, `backlog.md`
2. Locate → find relevant files via `map.md`
3. Context → understand architecture via `design.md`
4. Implement → follow `design.md` patterns
5. Verify → tests (`make test` or project-specific)
6. Sync → if reality ≠ design, update `design.md`
7. Archive → completed tasks → `changelog.md`

## Task (Subagent) Rules

- Pass objective context, not just query
- Evaluate returns with follow-up questions (max 3 cycles)
- Model selection: Haiku(simple) / Sonnet(default) / Opus(5+ files, architecture)

## Rules

**IMPORTANT**: Read `.claude/` docs before coding

- No features outside `design.md`
- No "done" without tests
- No file deletion without confirmation
- Clean `backlog.md` after task completion
- Style/format changes? Check full scope first
- Ambiguous? Ask

## Git

Do not include 'Co-authored-by' or any co-worker attributions in commit messages.
