# Spec-First Development

> Source of truth: `.claude/`, not code

**BEFORE ANY CODING**: Read these files if they exist:
- `.claude/map.md` - codebase structure
- `.claude/design.md` - architecture decisions
- `.claude/backlog.md` - current tasks
- `.claude/spec.md` - interface/naming contracts

If `.claude/` docs don't exist, run `/project-mapper:map-setup init`

## Docs

- [map.md](.claude/map.md): codebase structure, entry points
- [design.md](.claude/design.md): tech spec, architecture decisions
- [backlog.md](.claude/backlog.md): Planned, In Progress, TODOs
- [changelog.md](.claude/changelog.md): Recent (load) + Archive (on demand)
- [spec.md](.claude/spec.md): interface contracts, naming rules, definition of done

## Doc Format

Style: `[name](path): description` (llms.txt)

| File | Content |
|------|---------|
| map.md | entries, flow only |
| design.md | tech stack, `file:symbol` pointers |
| backlog.md | Planned, In Progress, TODOs |
| changelog.md | Recent only (Archive on demand) |
| spec.md | contracts, naming, done criteria |

Guidelines:
- Target: map <100, design <100 lines (flexible for large projects)
- **NEVER** use: ASCII art, code blocks, long tables
- Prefer: `file:symbol` over code snippets

## Workflow

1. Read → `.claude/map.md`, `design.md`, `backlog.md`, `spec.md`
2. Locate → find relevant files via `map.md`
3. Context → understand architecture via `design.md`
4. Check → verify spec.md contracts (changes require explicit approval)
5. Implement → follow `design.md` patterns + `spec.md` contracts
6. Verify → tests + contract compliance
7. Sync → if reality ≠ design, update `design.md`
8. Archive → completed tasks → `changelog.md`

## Debug

When Verify fails or behavior is unexpected:

1. Categorize — error (crash/exception), wrong-result (runs but incorrect), regression (was working)
2. Isolate — reproduce with minimum input. Single test > full suite
3. Trace — find the actual vs expected divergence point. Use `/project-mapper:trace` for large codebases
4. Fix — minimum change at the divergence point. Do not fix symptoms upstream
5. Confirm — re-run the exact failing case. Then run full suite

Principles:
- Read the error message completely before acting
- One hypothesis at a time. Verify before moving to next
- Log intermediate values at suspected divergence points, not everywhere
- If stuck after 3 attempts: widen scope (check recent changes via `git diff`)

## Task (Subagent) Rules

- Pass objective context, not just query
- Evaluate returns with follow-up questions (max 3 cycles)

## Rules

**IMPORTANT**: Read `.claude/` docs before coding

- Surface assumptions. Ambiguous? Ask before acting
- Minimum code that solves the problem. No speculative features or abstractions
- Surgical changes: touch only what the task requires. Match existing style
- No features outside `design.md`
- No "done" without verifiable success criteria (tests, manual check)
- No file deletion without confirmation
- No spec.md contract changes without explicit sign-off
- Clean `backlog.md` after task completion

## Git

**Never commit directly to main.** Always work on a branch:

1. `git checkout -b <prefix>/name` — prefix: `feat/`, `fix/`, `eval/`
2. Work + commit on branch
3. `git checkout main && git merge --ff-only <branch>`
4. `git branch -d <branch> && git push origin main`

No Co-authored-by or co-worker attributions in commit messages.
