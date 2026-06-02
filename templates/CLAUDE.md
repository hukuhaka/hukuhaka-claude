# Approach

## Think Before Coding

- State assumptions explicitly — if uncertain, ask
- Present multiple interpretations as choices — do not pick silently
- Name a simpler path if one exists. Push back when warranted
- Stop on confusion. Name what's unclear. Ask

## Reporting

Before acting on a non-trivial change, surface three layers in order:

1. **As-is** — show the actual current state, not a paraphrase. The form depends on what the change touches:
   - code/config → quote the current code, schema, or file structure
   - prose/docs → quote the current text
   - workflow/process → list the current steps
   - decision/behavior → state the current rule and what it produces
2. **Problem** — prove the issue exists with evidence: a quote that shows the gap, a count, a reproducer, a contradiction with another source. "X is broken" without evidence is a claim, not a diagnosis.
3. **To-be** — line up the proposed state against the As-is in the same shape, so the delta is visible. Include how the Problem's evidence would change once To-be lands.

End with a one-line compression and a gated next step. Do not auto-execute.

The point is that the user can intervene at any layer — challenge the cited state, reject the evidence, or steer the proposal. Skipping to To-be hides the first two and forces the user to reverse-engineer them.

Skip for truly routine edits (typo, rename, single-line). For everything else, show your work even briefly.

## Proposing Changes

When proposing a change that requires a decision, include:

- **Why** — the current problem or opportunity motivating the change
- **Options** — possible approaches (only when ≥2 are viable)
- **Tradeoffs** — pros and cons per option
- **Impact** — scope: files affected, migration cost, reversibility
- **Priority** — P1 / P2 / P3 with your recommendation

Skip fields that don't apply. Routine edits don't need this.

## Goal-Driven Execution

Convert each task into a verifiable goal. No "done" without a check that proves it.

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Tests pass before and after"

For multi-step work, state the plan as step → verify pairs before starting. Strong criteria enable independent looping. Weak criteria ("make it work") force constant re-clarification.

## Debug

When Verify fails or behavior is unexpected:

1. Categorize — error (crash/exception), wrong-result (runs but incorrect), regression (was working)
2. Isolate — reproduce with minimum input. Single test > full suite
3. Trace — find the actual vs expected divergence point. Use `/hukuhaka-project-mapper:trace` for large codebases
4. Fix — minimum change at the divergence point. Do not fix symptoms upstream
5. Confirm — re-run the exact failing case. Then run full suite

Principles:
- Read the error message completely before acting
- One hypothesis at a time. Verify before moving to next
- Log intermediate values at suspected divergence points, not everywhere
- If stuck after 3 attempts: widen scope (check recent changes via `git diff`)

## Team vs Subagent

Use the right tool for the job:
- **Subagent** (Agent tool): focused tasks where only the result matters. Reports back to caller. No inter-agent communication. Lower token cost
- **Team** (TeamCreate): parallel work requiring discussion and collaboration. Teammates share a task list, claim work, and message each other directly. Each teammate is an independent session

**When asked to create a "team", always use TeamCreate.** Spawning multiple agents with the Agent tool alone is subagents, not a team.

### Team Rules

- 3-5 teammates, 5-6 tasks per teammate
- Each teammate must own a distinct set of files — never have two teammates edit the same file
- For complex or risky tasks, require plan approval: teammate works in plan mode until lead approves
- Do NOT clean up the team until all teammate tasks are completed
- Lead must NOT implement tasks directly — delegate to teammates and wait for results

### Subagent Rules

- Pass objective context, not just query
- Evaluate returns with follow-up questions (max 3 cycles)

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

## Suggestions

For reusable patterns, gotchas, or project conventions that emerge during work and don't fit in code or current `.claude/` docs: consider capturing as an LTM rule via `/hukuhaka-ltm:ltm-declare-rule` (requires `hukuhaka-ltm` plugin; bootstrap with `/hukuhaka-ltm:ltm-init` if `.claude/ltm/` is empty).

## Git

**Never commit directly to main.** Always work on a branch:

1. `git checkout -b <prefix>/name` — prefix: `feat/`, `fix/`, `eval/`
2. Work + commit on branch
3. `git checkout main && git merge --ff-only <branch>`
4. `git branch -d <branch> && git push origin main`

No Co-authored-by or co-worker attributions in commit messages.
