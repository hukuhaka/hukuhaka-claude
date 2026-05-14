---
name: ltm-recall
description: >
  Recall accumulated project knowledge from .claude/ltm/. Use when the
  user references past work or when modifying a skill/plugin/hook needs
  prior context. Returns cited synthesis. Do NOT use for current-state
  code (use Read/Grep) or to record new knowledge (use ltm-append).
allowed-tools: Read, Glob, Grep, Bash
---

# ltm-recall

Look up accumulated knowledge in `.claude/ltm/` and answer the user with citations.

> **Default language: English.** Plugin defaults assume English entries
> and triggers. Projects may declare additional language-specific
> triggers in `.claude/ltm/CLAUDE.md` — load and honour them.

## When this skill activates

Default trigger phrases (project RULES may add more):

- "did we decide", "we already decided", "what was decided about"
- "remember when", "earlier we", "past attempt", "previous version"
- "what was the reason for", "why did we choose"
- "what's the design intent", "original design"
- "why does <skill / plugin> do X"
- editing skill / plugin / hook code (e.g. "let's edit the audit skill", "tweak this hook"): pull prior design context before editing
- Any reference to a *prior session* or *prior phase* of this project

If the user is asking about *current state of code* (e.g. "what does this function do") — that's not LTM territory. Use Read/Grep instead.

## Pre-flight

1. Check `.claude/ltm/CLAUDE.md` exists. If not, tell the user "this project hasn't bootstrapped LTM yet — run `/ltm:init` first" and stop.
2. **Reload RULES**: read `.claude/ltm/CLAUDE.md` fully. This is the on-demand reload — the SessionStart ping only announced existence; full rules load now.
3. Identify what the user is asking about. Extract topic keywords + any kind hints they used.

## Retrieval — L2-first, drill into L3 on demand

The storage is tiered (see `.claude/ltm/CLAUDE.md` for the contract):

- **L2** — `.claude/ltm/index/<topic>.md` — curated knowledge cards. One card per topic. Each card's frontmatter has `summary` (the rule), `context` (the why), and `evidence: [<log-id>, ...]` pointing to L3 sources. *Surface L2 first.*
- **L3** — `.claude/ltm/log/*.md` — raw timeline. Read selectively as evidence drill-down (when the user asks "what's the source", "what was the original framing", "history of X") or when no L2 card exists for the asked topic.
- **L1** — `.claude/ltm/pinned.md` — already in context via the SessionStart hook inject. Do NOT re-read it during recall; reference it inline if relevant.

### Step 1 — L2 scan

Glob `.claude/ltm/index/*.md`. Read titles + frontmatter `summary` / `context` for each card. Match against the user's topic keywords.

If matching cards exist:

- Synthesize an answer from card summaries, citing the card path (e.g. `.claude/ltm/index/skill-project-mapper.md`).
- If the user asks "what's the source" / "why" / "show me the evidence", read the cited L3 entries from the card's `evidence` list and quote them.
- Filter out superseded cards (cards whose id appears in another card's `supersedes:` field) unless the user explicitly asked for history.

### Step 2 — L3 fallback

If no L2 card matches *or* the user asked about a recent decision that may not be distilled yet:

Run `!${CLAUDE_PLUGIN_ROOT}/skills/ltm-recall/scripts/scan_recent.sh 30` for the 30 newest entries (optionally with kind filter as the second arg, e.g. `scan_recent.sh 50 philosophy`). Read returned files in batch.

Skip entries whose frontmatter has `distilled: true` *unless* their L2 card was already surfaced or insufficient — those entries' L2 card is the canonical surface.

If `.claude/ltm/CLAUDE.md` declares a project-specific "Read pattern" override, follow that instead.

(Project RULES may also declare additional language-specific trigger phrases — load them when the skill activates.)

## Synthesis

- Answer the user's question directly, in 1–3 paragraphs.
- **Prefer citing L2 cards** (`.claude/ltm/index/<topic>.md`) for the canonical summary, falling back to raw L3 entries (`.claude/ltm/log/<date>-<slug>.md`) only as evidence drill-down or when no card exists.
- If multiple cards say *different things* on the same topic, note the contradiction explicitly and identify which is most recent / which supersedes which (check the `supersedes:` field).
- If the answer is *not* in LTM, say so plainly — don't invent. Suggest the user *append* the answer (via natural conversation that triggers `ltm-append`, or `/ltm:declare-rule` if it's a rule, or `<ltm-record>` block if you're closing a decision yourself).

## Style

- Quote entries directly when the wording matters (decisions, philosophy statements).
- Paraphrase when the entry was long and only one part is relevant.
- Never blend entries silently — if your synthesis pulls from 3 entries, name all 3.

## Anti-patterns

- Reading all `log/` entries when 30 most recent suffice — token waste, prefer recency.
- Answering from memory of this conversation alone when LTM has the canonical record — always check LTM.
- Auto-appending what you found — recall is read-only. If the user wants to record something, that's `ltm-append` territory.
