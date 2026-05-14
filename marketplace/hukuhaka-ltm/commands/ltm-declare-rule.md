---
description: Propose and commit a change to .claude/ltm/CLAUDE.md as a recorded rule-evolution event
---

# /ltm:declare-rule — evolve LTM rules

Rules are content. A change to `.claude/ltm/CLAUDE.md` is itself an LTM entry (`kind: rule-evolution`). This command enforces that round-trip — never silently edit RULES.

## Pre-flight

1. Verify `.claude/ltm/CLAUDE.md` exists. If not → tell user to run `/ltm:init` first; abort.
2. Read current RULES file fully into context. (This is the on-demand RULES reload moment for this session.)

## Phase 1 — capture intent

Ask the user, in plain conversation:

> "What change to RULES are you proposing? Either describe it in words, or paste the new text. I'll diff against current and record both."

If the user only describes in words, draft the proposed new text yourself, then *show it for approval*. Don't commit without explicit user OK.

## Phase 2 — diff + rationale

1. Show a clear diff: what's being removed, what's being added, what's being kept.
2. Ask: "Why this change? One or two lines is enough." This rationale becomes the body of the rule-evolution entry — it's what future-you reads to understand the evolution.
3. If the change supersedes a prior rule-evolution entry (e.g., reverting or refining a recent rule), ask: "Does this supersede a recent rule-evolution entry? If so, paste the id." Optional.

## Phase 3 — commit

1. Apply the change to `.claude/ltm/CLAUDE.md` (Edit tool — the overwrite-nudge hook will fire; that's expected and appropriate here, the rationale just collected satisfies it).
2. Append a rule-evolution entry via `${CLAUDE_PLUGIN_ROOT}/scripts/append-entry.py`:
   - `--kind rule-evolution`
   - `--title "<short description of what changed>"`
   - `--supersedes <id>` if user named one
   - Body via stdin: the diff (as a fenced ```diff block) + the user's rationale + any context from this session that motivated the change
3. Tell user: path to the new entry, path to updated RULES, current version of LTM (entry count under `log/`).

## Style notes

- Do not let the user *only* edit RULES without recording — the round-trip is the whole point.
- Do not invent rationale on the user's behalf. If they decline to give one, record "rationale: not given" and move on; honesty over completeness.
- Do not strip sections from the template-managed *guardrails* part of RULES (the universal section). If the user proposes that, push back — those are plugin-managed; if they really want to disable a guardrail, the path is upstream (file an issue / fork the plugin), not RULES edit.
