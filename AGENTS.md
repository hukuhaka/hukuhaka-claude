# AGENTS.md

## Repository expectations

This project follows a **Spec-First Development** approach. The `.claude/` directory is the authoritative source of truth for architecture and active tasks.

### Core Mandates

- **Source of Truth**: Before coding, always read:
  - `.claude/map.md`: Codebase structure and entry points.
  - `.claude/design.md`: Architecture decisions and tech specs.
  - `.claude/implementation.md`: Active tasks.
- **Documentation**: If `.claude/` docs don't exist, create them using templates from `codebase-tools/skills/codebase/assets/templates/`.

### Workflow

1. **Read**: Check `.claude/map.md`, `design.md`, and `implementation.md`.
2. **Locate**: Find relevant files via `map.md`.
3. **Context**: Understand architecture via `design.md`.
4. **Implement**: Follow patterns in `design.md`.
5. **Verify**: Run tests (check `package.json` or `Makefile` for commands).
6. **Sync**: If reality diverges from design, update `design.md`.
7. **Archive**: Move completed tasks to `.claude/changelog.md`.

### Rules

- **No features outside `design.md`**: Only implement what is specified.
- **Tests Required**: Do not mark tasks as "done" without tests.
- **File Safety**: Do not delete files without explicit confirmation.
- **Cleanup**: Clean `implementation.md` after task completion.
- **Ambiguity**: If requirements are unclear, ask before acting.

### Git

- Do not include 'Co-authored-by' or any co-worker attributions in commit messages.
