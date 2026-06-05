# Approach

## Think Before Acting

- State assumptions explicitly — if uncertain, ask
- Present multiple interpretations as choices — do not pick silently
- Name a simpler path if one exists. Push back when warranted
- Stop on confusion. Name what's unclear. Ask

## Reporting

Before acting on a non-trivial change, surface three layers — the user can intervene at any one:

1. **As-is** — quote the actual current state (code, text, steps, or rule), not a paraphrase
2. **Problem** — prove it with evidence: a quote, a count, a reproducer. No evidence = a claim, not a diagnosis
3. **To-be** — the proposed state in the same shape as As-is, so the delta is visible. When a decision is needed, add options with tradeoffs, impact, and a recommendation

End with a one-line compression and a gated next step. Do not auto-execute.
Skip for routine edits (typo, rename, single-line).

## Goal-Driven Execution

Convert each task into a verifiable goal. No "done" without a check that proves it.

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Tests pass before and after"

For multi-step work, state the plan as step → verify pairs before starting. Strong criteria enable independent looping. Weak criteria ("make it work") force constant re-clarification.

## Debug

When behavior is unexpected: reproduce with minimum input → find the actual-vs-expected divergence point → minimum fix at that point → re-run the exact failing case. One hypothesis at a time; read the full error message first. If stuck after 3 attempts, widen scope (`git diff`, or `/hukuhaka-project-mapper:trace` for large codebases).

---

# Rules

- Sync `design.md` and archive to `changelog.md` for major changes only.
- When the user asks a question, answer only. Do not take additional actions (git operations, file edits, command execution, etc.) unless the question explicitly requests them. Answering a question is not authorization to execute on the same topic.
- Minimum code that solves the problem. No speculative features or abstractions
- Surgical changes: touch only what the task requires. Match existing style
- No features outside `design.md`
- No "done" without verifiable success criteria (see Goal-Driven Execution)
- No file deletion without confirmation
- No spec.md contract changes without explicit sign-off
- Clean `backlog.md` after task completion

---

# Reference

## Git

**Never commit directly to main.** Always work on a branch:

1. `git checkout -b <prefix>/name` — prefix: `feat/`, `fix/`, `eval/`
2. Work + commit on branch
3. `git checkout main && git merge --ff-only <branch>`
4. `git branch -d <branch> && git push origin main`

No Co-authored-by or co-worker attributions in commit messages.
