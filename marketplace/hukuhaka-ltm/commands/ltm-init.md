---
description: Bootstrap or rebootstrap LTM for this project via open Q&A
allowed-tools: Read, Write, Edit, Bash
---

# /ltm:init — bootstrap LTM

This is a guided ritual, not a one-shot command. The user owns the answers; you (Claude) draft RULES from those answers.

## Pre-flight

1. Detect existing state:
   - If `.claude/ltm/CLAUDE.md` already exists → tell the user, ask whether to *re-bootstrap* (preserves existing `log/` entries; only RULES file is rewritten) or *abort*. Never silently overwrite a populated LTM.
   - If `.claude/ltm/` does not exist → first-time init, proceed.
2. If the project root has a `CLAUDE.md`, note that you will be appending a short pointer paragraph at the end. If `<!-- hukuhaka-ltm:begin -->` already present, skip the append.

## Phase 1 — open questions (required)

Ask these *one at a time* in plain conversation. Wait for the user's answer before the next. Do not list them all at once.

1. "What kind of knowledge in this project tends to *evaporate* between sessions? Things you re-derive, lookups you repeat, conclusions you re-reach."
2. "Has there been a moment recently where you thought 'I know I figured this out before but I can't remember where'? What was it?"
3. "If you stopped working on this project for 6 months and only the code remained — *not* the docs, *not* this conversation — what would be lost?"
4. "What kinds of decisions in this project deserve a paper trail? (architecture, philosophy, discarded approaches, anti-patterns, ...)"

## Phase 2 — scaffolding (optional, skippable)

Offer this *briefly*. The user can skip with one word.

> "Starting points other people use: decision log / anti-pattern log / finding accumulator / discarded-hypothesis log / philosophy notes. Want me to lean toward any of these in the draft, or skip and just use your own framing?"

If user picks any → use them as light bias when drafting `## Project conventions`. If user skips → draft purely from Phase 1 answers.

## Phase 3 — draft RULES

1. Read the template: `${CLAUDE_PLUGIN_ROOT}/templates/ltm-claude.md`.
2. Replace the `## Purpose` section with a 1-paragraph synthesis of Phase 1 answers (in the user's own words where possible — quote them).
3. Adjust `## Project conventions` to reflect Phase 2 bias (or trim if user skipped).
4. Show the draft to the user. Ask: "Edit anything? Or commit as-is?"
5. Iterate until user approves.

## Phase 4 — write to disk

1. Create `.claude/ltm/log/` directory.
2. Write the approved draft to `.claude/ltm/CLAUDE.md`.
3. Append the **first LTM entry** via `${CLAUDE_PLUGIN_ROOT}/scripts/append-entry.py`:
   - `--kind genesis`
   - `--title "LTM bootstrapped for <project name>"`
   - Body via stdin: include the verbatim Q&A transcript from Phase 1 + 2, plus the rationale for any conventions chosen. This entry is the *origin* — preserve everything.
4. Inject the pointer paragraph from `${CLAUDE_PLUGIN_ROOT}/templates/project-pointer.md` into the project root `CLAUDE.md` (append at end). Skip if `<!-- hukuhaka-ltm:begin -->` already present.
5. Initialize the meta-state baseline by running `${CLAUDE_PLUGIN_ROOT}/scripts/record-meta-event.sh` (it writes `.meta-state` without firing an event on first run).

## Phase 5 — confirm

Tell the user, plainly:

- Path to RULES file
- Path to the genesis entry
- That `ltm-recall` / `ltm-append` skills will activate naturally on relevant prompts
- That `/ltm:declare-rule` is how RULES evolve from here

## Style notes

- Do not be efficient with the questions. Answers shape everything downstream — slow is correct.
- Do not invent on behalf of the user. If they say "I don't know", record that and move on. The genesis entry can simply note "purpose to be discovered through use".
- Do not lock the schema. The conventions section is *suggested only*; user can rewrite freely now or via `/ltm:declare-rule` later.
- Do not pre-categorize entries. If the user describes their domain in their own taxonomy, use *their* words in the conventions section, not the template's defaults.
