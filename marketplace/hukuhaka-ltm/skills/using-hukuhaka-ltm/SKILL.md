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
| **L1** | `.claude/ltm/pinned.md` | SessionStart inject (always-on) | Cross-axis distillation across the whole L2 corpus — patterns that span multiple axes, or single L2 cards whose evidence depth justifies always-loaded status | `/ltm:distill` Step 5 (one `l1-update` subagent reads new L2 + current pinned.md + policy and edits pinned.md directly); 2KB hard cap |
| **L2** | `.claude/ltm/index/<topic>.md` | `ltm-recall` activation | Within-axis distillation from L3 entries — both frontmatter (topic/summary/evidence/context) and a substantive reference body | `/ltm:distill` Steps 1-4: **cluster** subagent (L3 → axes) → **main-context file mapping** Step 2 (assigns each axis to `edit / create / create-merging / retire`; user gates the assignment plan) → **N parallel writers** (one per assignment; authors frontmatter + body) → **validate** subagent (per-card cold-read) → `distill.py reproject` |
| **L3** | `.claude/ltm/log/` | Cold; loaded as evidence by ltm-recall or by id | Raw timestamped narrative atoms | `ltm-append` (manual) or Stop hook (autonomous) |

**Tier semantics.** L1 and L2 are the same distillation operation applied at different scopes — not an importance ranking. L2 = distillation within one axis (a thematic lineage). L1 = distillation across all axes (cross-cutting patterns) or single-card-deep (one L2 card whose evidence reach is project-wide). `pinned.md` is auto-maintained by `/ltm:distill` Step 5; do not hand-edit (changes are overwritten on next cycle).

An L2 card cites L3 entries via `evidence: [<id>, ...]` — this is the **source of truth**. Each L3 entry carries a derived `distilled-into` pointer (`[index/foo.md, ...]`) that the distill `reproject` step keeps in sync with L2 evidence after every run. Recall surfaces L2 first; drill into L3 only when the user asks "what's the source" or "history of X".

### L3 `distilled-into` semantics (3-state pointer)

- **field absent** — entry has never been through `/ltm:distill` (newly captured)
- **`distilled-into: []`** — entry was scanned by distill, currently no L2 card cites it (intentional keep-in-L3, OR a cited card was retired)
- **`distilled-into: [index/foo.md, index/bar.md]`** — entry is currently cited by these L2 cards

This replaces the v0.1.x boolean `distilled: true|false`. The next `/ltm:distill` run on a v0.1.x project auto-migrates (drops the boolean, derives the pointer).

## Autonomy contract (user-authorized 2026-05-14; rewritten 2026-05-21 for v0.4.0)

- **L3 — fully autonomous.** When you (Claude) detect a closure-shaped moment that's worth recording, emit an `<ltm-record>` marker block in your assistant message (see "L3 record marker" below). The Stop hook parses the last assistant turn, finds each block, and calls `append-entry.py --autonomous`. The entry lands with `autonomous: true` and no `distilled-into` field. No per-turn user assent is required.
- **L2 — autonomous draft + main-context mapping, user-gated assignment.** `/ltm:distill` Step 1 (cluster subagent) and Step 2 (main-context file mapping) run autonomously to produce an assignment plan. The Step 2g user gate is the single trust boundary per cycle — user inspects each `edit / create / create-merging / retire` row before writers fire in Step 3. Validate (Step 4) surfaces per-card defects; non-empty issues trigger a second user gate to decide whether to re-spin individual writers.
- **L1 — autonomous, anomaly-checked.** `/ltm:distill` Step 5 (`l1-update` subagent) runs without a separate user gate by default — L1 is treated as an automatic consequence of L2 changes already approved at Step 2g. Step 6 (`final-review` subagent) is a read-only end-to-end anomaly scan: orphan L3, pinned line without L2 backing, cross-card duplication, etc. Anomalies are reported, not auto-fixed. Outside `/ltm:distill`, do NOT manually edit `pinned.md` — changes are overwritten on the next cycle.

The IRON-LAW in `ltm-append/SKILL.md` still governs manual L3 writes via the ltm-append skill path — the marker-driven autonomous path is separate and additive.

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

## Project-level policy surface

The plugin defines **mechanism** (the 6-step skeleton, the 3-state pointer, deterministic reproject, cold-read peer review at validate + final-review). Each project declares its own **policy** in `.claude/ltm/CLAUDE.md`. That file is fed verbatim to every subagent (cluster, writer, validate, l1-update, final-review) and to the main-context Step 2 mapping work.

Policy types projects can declare:

| Rule type | Example | Effect on distill |
|---|---|---|
| **Axis inventory** (L2) | "L2 axes for this project: plugin-X, plugin-Y, git-workflow, eval-framework, ..." | Cluster groups L3s under a declared axis; main-context Step 2 maps each axis to one declared topic and rejects assignments whose target doesn't match |
| **Cardinality cap** (L2) | "Hard cap: 7 L2 cards total" | Main-context Step 2 must propose `create-merging` or `retire` for any assignment count that would exceed the cap |
| **Single-card topics** (L2) | "All `train`-tagged entries go into one `train` axis" | Cluster routes matching entries regardless of name hint |
| **Naming convention** (L2) | "Plugin cards: `plugin-<name>`, skill cards: `skill-<name>`" | Step 2 enforces the slug pattern on `create` and `create-merging` targets |
| **L1-candidate hints** (L1) | "themes: validation-independence, repo-publication, plugin-guide-canon" | `l1-update` agent looks for these themes in the new L2 corpus and frames add-pin text around them |
| **Retirement criteria** (L2) | "Single-entry cards whose body 1:1-paraphrases summary are retire candidates" | Step 2 main-context proposes `retire` for matching cards (orphan check + paraphrase signal); validate confirms body density at Step 4 |

`/ltm:declare-rule` is the canonical way to evolve `.claude/ltm/CLAUDE.md`. After a policy edit, the next `/ltm:distill` run honours the new rule automatically (every run re-reconciles the full L2 and L1).

If `.claude/ltm/CLAUDE.md` declares no policy: the plugin operates in **permissive default mode** — agents use inferred semantic axes / themes with no fixed inventory. Validators still apply echo-pattern reading guidance regardless of policy.

## NON-NEGOTIABLE — autonomy boundaries

These are hard gates. Violating any of them defeats the entire tier separation and forces the user back into per-event interruption — which is exactly the failure mode this plugin exists to prevent.

**YOU MUST**

- emit `<ltm-record>` blocks ONLY when the turn closes a decision, abandonment, lesson, or tradeoff resolution
- include both `kind="..."` and `title="..."` attributes on every emitted block
- prefer L2 cards (`.claude/ltm/index/`) over L3 raw log when answering recall queries
- treat the Step 2g assignment gate in `/ltm:distill` as the user trust boundary — every `edit / create / create-merging / retire` must be visible there before writers fire
- treat any non-empty Step 4 validate issues as a second user gate — do not auto-proceed to Step 5 if `issues` is non-empty
- surface Step 6 final-review anomalies to the user verbatim in closeout

**YOU MUST NOT**

- call `append-entry.py` directly via Bash unless the user explicitly invoked the `ltm-append` skill (the IRON-LAW path)
- write to `.claude/ltm/index/` via Write/Edit tools outside `/ltm:distill` — the distill writer subagents are the only mutators
- write to `.claude/ltm/pinned.md` via Edit/Write tools outside `/ltm:distill` — the `l1-update` agent is the canonical write path
- delegate Step 2 file mapping to a subagent. Step 2 is main-context work by design — that's where the user can read your assignment reasoning and intervene
- emit `<ltm-record>` for open exploration ("what if", "let's consider", "we could try")
- silently change L2 card `summary:` / `context:` fields without setting `supersedes:` to the prior card id

## When to act — trigger matrix

| User says or session shows | Skill to invoke |
|---|---|
| "remember when we…", "we already…", "previously we", references a past skill/plugin design | **ltm-recall** (load L2 + cited L3) |
| Closure phrase mid-turn ("decided", "abandoned", "the lesson") + user asks to record | **ltm-append** (IRON-LAW, explicit assent) |
| Closure phrase in turn but no record-intent expressed | Let Stop hook handle it (L3 autonomous) — do NOT invoke ltm-append |
| 5+ L3 entries with absent `distilled-into` since last distill / user says "clean up", "consolidate" / declared axes drift / user wants L1 refresh | `/ltm:distill` (single mode — re-reconciles full L2 and L1) |
| Edit `.claude/ltm/CLAUDE.md` (rules themselves) | `/ltm:declare-rule` (records rule-evolution entry) |
| Bootstrap LTM in a new project | `/ltm:init` |

## Boundary — what LTM is NOT

- **Not current-state code mirror.** Architecture, file paths, function names → `hukuhaka-project-mapper`'s `.claude/{map,design,spec}.md`.
- **Not session scratch.** TodoWrite / plan files / inline conversation context handle scratch.
- **Not a wiki.** Entries close on a *decision, finding, lesson, or abandoned approach*. Open exploration is not append-worthy.

## Common rationalisations to reject

| Thought | Reality |
|---|---|
| "I'll ltm-append this since user just said 'decided'" | Stop hook handles L3 autonomously. Invoke ltm-append only when user signals record-intent ("save this", "log it", "기록해"). |
| "I'll write directly to pinned.md, it's just a line" | pinned.md is auto-maintained by `/ltm:distill` Stage 5. Manual edits will be overwritten next cycle. Add the L3 evidence instead and let distill promote it. |
| "Distill seems heavy, I'll just summarise in chat" | Summaries in chat evaporate. The L2 card is the surface that survives compaction. |
| "ltm-recall returned nothing, must be no prior context" | Check L2 first via `index/`, not just `log/`. Recall should surface cards before raw log. |
| "User said 'looks good' to my draft — proceed" | "looks good" is ambiguous. ltm-append IRON-LAW requires a clear go-word. |
| "I'll filter L3 by `distilled: true`" | That boolean was removed in v0.2.0. Filter by `distilled-into` presence — absent = unscanned, `[]` = scanned-uncited (intentional keep-in-L3), `[paths]` = cited. |
| "I'll create a new L2 card for this new topic" | The main-context Step 2 decides; the validate agent (cold read) challenges if the body is a frontmatter stub. If you (Claude in normal sessions) feel a `create` urge, route through `/ltm:distill` — don't write to `index/` directly. |
| "I'll approve `all` on the Step 2g gate" | Don't. Each `retire` / `create-merging` row loses files irreversibly (recovery is `git revert` on `.claude/ltm/`). Inspect each row individually — Step 2g is the single trust boundary for the cycle. |
| "I'll just emit assignments — validate will catch issues" | Validate (Step 4) catches per-card body defects, not assignment-level mistakes (wrong axis grouping, wrong file allocated). If your Step 2 mapping is sloppy, validate won't recover it — re-spinning writers can't fix "axis A was assigned to the wrong card". Get Step 2 right at the user gate. |
| "pinned.md has a hand-edit I want to keep — I'll just leave it" | Step 5 (`l1-update`) will overwrite it. If the line is worth keeping, ensure an L2 card encodes its principle; `l1-update` will re-derive the line from L2. If it's not in L2 yet, that's where to land it. |

## File-level reference

- Detailed rules + entry kinds → `.claude/ltm/CLAUDE.md`
- Core principles always in context → `.claude/ltm/pinned.md`
- Per-topic knowledge → `.claude/ltm/index/`
- Raw timeline (evidence) → `.claude/ltm/log/`
- Auto-record digest for next session → `.claude/ltm/.session-digest.pending`
