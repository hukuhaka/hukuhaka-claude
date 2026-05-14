---
name: using-hukuhaka-ltm
description: >
  Use when a task touches the hukuhaka-ltm plugin's storage, recall, autonomy, or distillation — explains the L1/L2/L3 contract, the per-tier autonomy policy, and which entry point (`/ltm:distill`, ltm-recall, ltm-append) to invoke. Do NOT use for current-state code questions (use Read/Grep) or session scratch (TodoWrite).
---

# using-hukuhaka-ltm

This skill is the entry point for *how* the LTM system works. The SessionStart hook injects this content into every new session so the operator does not need to re-explain. Detailed RULES live in `.claude/ltm/CLAUDE.md`; the L1 pinned principles live in `.claude/ltm/pinned.md` (also injected). This file is the contract that ties them together.

## Architecture — three tiers

| Tier | Location | When loaded | Owns | Write path |
|---|---|---|---|---|
| **L1** | `.claude/ltm/pinned.md` | SessionStart inject (always-on) | Project-wide rock-solid principles | Manual edit only |
| **L2** | `.claude/ltm/index/<topic>.md` | `ltm-recall` activation | Distilled per-topic knowledge cards | `/ltm:distill` |
| **L3** | `.claude/ltm/log/` | Cold; loaded as evidence by ltm-recall or by id | Raw timestamped narrative | `ltm-append` (manual) or Stop hook (autonomous) |

An L2 card cites L3 entries via `evidence: [<id>, ...]`. Recall surfaces L2 first; drill into L3 only when the user asks "what's the source" or "history of X".

## Autonomy contract (user-authorized 2026-05-14)

- **L3 — fully autonomous.** When you (Claude) detect a closure-shaped moment that's worth recording, emit an `<ltm-record>` marker block in your assistant message (see "L3 record marker" below). The Stop hook parses the last assistant turn, finds each block, and calls `append-entry.py --autonomous`. The entry lands with `autonomous: true, distilled: false`. No per-turn user assent is required.
- **L2 — autonomous draft, batch review.** `/ltm:distill` clusters undistilled L3 entries and drafts/merges cards. The SessionEnd digest summarises what was auto-recorded; the user reviews in batch on the next session.
- **L1 — explicit assent required.** Promotions into `pinned.md` (via `/ltm:distill --promote <log-id>`) and any direct edit to pinned must be confirmed by the user in the same turn. The IRON-LAW in `ltm-append/SKILL.md` still governs manual L3 writes via the ltm-append skill path — the marker-driven autonomous path is *separate* and additive.

### L3 record marker

Emit one or more of these blocks in your assistant message when a closure moment occurs. The Stop hook parses your last assistant message after each turn and writes each block:

```
<ltm-record kind="decision" title="One-line summary (≤80 chars)" supersedes="optional,csv,of,entry,ids">
Body of the entry. Include the *reason* — what was the constraint, what
got rejected, what is the rule going forward. Future-you needs to
reconstruct the call without re-reading the whole conversation.
</ltm-record>
```

- `kind` and `title` are required. `supersedes` is optional.
- Common kinds: `decision`, `philosophy`, `process`, `failure-fix`, `eval-pattern`, `abandonment`. Project RULES (`.claude/ltm/CLAUDE.md`) may extend.
- Emit only when the turn produces *closure* — a decision settled, an approach abandoned, a lesson named, a tradeoff resolved. Open exploration is not marker-worthy.
- Do NOT mark the same closure twice in one turn. Multiple distinct closures in one turn → multiple blocks. Cap is 5 blocks per turn (Stop hook truncates beyond that).
- **Emit in plain assistant text only.** The Stop hook parses `message.content[*].type == "text"` parts. Markers placed inside Write/Edit tool_use content arguments, inside `thinking` blocks, or inside fenced code blocks (when you are *explaining* the format rather than *recording*) will not be parsed and will not be written. If you want to show an example without triggering a record, replace the angle brackets with a different delimiter or escape them.
- The user will see the block in your reply, so write it as if speaking to them. The Stop hook surfaces the resulting file path via the next SessionStart digest *and* prints a one-line `systemMessage` confirmation in the same turn.

Difference from `ltm-append`: the skill path is *suggestion + confirm + execute* for entries the user explicitly wants kept. The marker path is *Claude-judged + auto-record + batch-review-later* for entries Claude judges worth keeping without interrupting the user. Both feed L3; both get distilled by `/ltm:distill`.

## NON-NEGOTIABLE — autonomy boundaries

These are hard gates. Violating any of them defeats the entire tier separation and forces the user back into per-event interruption — which is exactly the failure mode this plugin exists to prevent.

**YOU MUST**

- emit `<ltm-record>` blocks ONLY when the turn closes a decision, abandonment, lesson, or tradeoff resolution
- include both `kind="..."` and `title="..."` attributes on every emitted block
- write to `.claude/ltm/pinned.md` (L1) ONLY after explicit user assent in the same turn (whitelisted go-words: `yes`, `go`, `do it`, `기록해`, `좋아`, etc.)
- prefer L2 cards (`.claude/ltm/index/`) over L3 raw log when answering recall queries

**YOU MUST NOT**

- call `append-entry.py` directly via Bash unless the user explicitly invoked the `ltm-append` skill (the IRON-LAW path)
- write to `.claude/ltm/index/` via Write/Edit tools — `/ltm:distill apply` is the canonical write path
- emit `<ltm-record>` for open exploration ("what if", "let's consider", "we could try")
- overwrite an existing `.claude/ltm/pinned.md` line without user confirmation in the same turn
- silently change L2 card `summary:` / `context:` fields without setting `supersedes:` to the prior card id

## When to act — trigger matrix

| User says or session shows | Skill to invoke |
|---|---|
| "remember when we…", "we already…", "previously we", references a past skill/plugin design | **ltm-recall** (load L2 + cited L3) |
| Closure phrase mid-turn ("decided", "abandoned", "the lesson") + user asks to record | **ltm-append** (IRON-LAW, explicit assent) |
| Closure phrase in turn but no record-intent expressed | Let Stop hook handle it (L3 autonomous) — do NOT invoke ltm-append |
| "let's review what got auto-recorded" / new session shows "지난 세션 자동 기록 N건" | `/ltm:distill --review-recent` |
| 5+ undistilled L3 entries / user says "clean up", "consolidate", "promote" | `/ltm:distill --retroactive` or `--promote` |
| Edit `.claude/ltm/CLAUDE.md` (rules themselves) | `/ltm:declare-rule` (records rule-evolution entry) |
| Bootstrap LTM in a new project | `/ltm:init` |

## Boundary — what LTM is NOT

- **Not current-state code mirror.** Architecture, file paths, function names → `project-mapper`'s `.claude/{map,design,spec}.md`.
- **Not session scratch.** TodoWrite / plan files / inline conversation context handle scratch.
- **Not a wiki.** Entries close on a *decision, finding, lesson, or abandoned approach*. Open exploration is not append-worthy.

## Common rationalisations to reject

| Thought | Reality |
|---|---|
| "I'll ltm-append this since user just said 'decided'" | Stop hook handles L3 autonomously. Invoke ltm-append only when user signals record-intent ("save this", "log it", "기록해"). |
| "I'll write directly to pinned.md, it's just a line" | L1 requires assent. Even one-line additions go through the promotion flow. |
| "Distill seems heavy, I'll just summarise in chat" | Summaries in chat evaporate. The L2 card is the surface that survives compaction. |
| "ltm-recall returned nothing, must be no prior context" | Check L2 first via `index/`, not just `log/`. Recall should surface cards before raw log. |
| "User said 'looks good' to my draft — proceed" | "looks good" is ambiguous. ltm-append IRON-LAW requires a clear go-word. |

## File-level reference

- Detailed rules + entry kinds → `.claude/ltm/CLAUDE.md`
- Core principles always in context → `.claude/ltm/pinned.md`
- Per-topic knowledge → `.claude/ltm/index/`
- Raw timeline (evidence) → `.claude/ltm/log/`
- Auto-record digest for next session → `.claude/ltm/.session-digest.pending`
