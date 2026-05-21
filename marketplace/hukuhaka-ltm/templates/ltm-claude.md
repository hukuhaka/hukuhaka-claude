# LTM — Long-Term Memory

> Self-hosted accumulated knowledge for this project. This file *is* an LTM
> entry — every change to it is a `kind: rule-evolution` event recorded
> alongside content in `log/`.
>
> **Default language: English.** Plugin defaults assume English entries
> and triggers. Projects working in another language may add
> language-specific trigger phrases below; the skills will load and
> honour them. Keep entry bodies in English where practical for
> portability across sessions and contributors.

## Purpose (project-declared)

> Replace this section during `/ltm:init`. State plainly: what kind of
> knowledge tends to evaporate between sessions in this project? What
> would be lost if you stopped working on this for 6 months? This
> declaration scopes everything else.

(unset — run `/ltm:init`)

## Tier architecture (L1 / L2 / L3)

LTM storage is split into three tiers, each with a distinct loading
discipline and write policy. The `using-hukuhaka-ltm` skill explains the
operational contract; this section is the rule reference.

| Tier | Path | Loaded | Schema | Write policy |
|---|---|---|---|---|
| **L1** | `.claude/ltm/pinned.md` | Always (SessionStart inject) | `## Core` list of `- <≤140-char principle>` lines, ≤2KB total | **l1-update** subagent (reads new L2 corpus + current pinned.md + policy, edits pinned.md directly) via `/ltm:distill` Step 5. Do not hand-edit — overwritten next cycle. |
| **L2** | `.claude/ltm/index/<topic>.md` | On-demand by `ltm-recall` | frontmatter card: `topic`, `summary`, `context`, `evidence: [<id>...]` (source of truth), `supersedes`, `last-updated`, plus body authored as reference | **Cluster** (L3 → axes) → **main-context file mapping** (Step 2: assigns each axis to `edit / create / create-merging / retire / noop` against existing L2; user gates the assignment plan) → **N parallel writers** (one per assignment; authors frontmatter + body) → **validate** (per-card cold-read) → **reproject** via `/ltm:distill` Steps 1-4. |
| **L3** | `.claude/ltm/log/<date>-<slug>.md` | As evidence drill-down | frontmatter: `id`, `timestamp`, `kind`, `tier: l3`, optional `autonomous: true`, optional `distilled-into: [index/foo.md, ...]` (3-state: absent / `[]` / `[paths]`) | **Fully autonomous** via `<ltm-record>` marker (Stop hook) OR **manual user-assent** via `ltm-append`. |

**Tier semantics.** L1 and L2 are the same distillation operation at different scopes. L2 = within-axis distillation from L3 atoms. L1 = cross-axis distillation from L2 corpus (or single-card-deep when one L2 card's evidence reach is project-wide). Not an importance ranking. Both tiers are auto-distilled by `/ltm:distill`; the Step 2g assignment gate is the user trust boundary for L2, and Step 6 final-review surfaces any cross-tier anomalies.

## Universal guardrails (managed by hukuhaka-ltm)

These are enforced or nudged by the plugin. Do not edit lightly.

1. **Every entry is timestamped.** `append-entry.py` auto-applies ISO 8601 UTC.
2. **Every entry has a stable id.** `slug + 6-char hash` of `slug|timestamp`.
3. **L1 is always in context, L2 on demand, L3 cold.** SessionStart
   hook injects `pinned.md` + the `using-hukuhaka-ltm` SKILL.md content;
   `ltm-recall` loads L2 cards (and their cited L3 entries on drill-down).
4. **RULES = LTM entry.** This very file is in `.claude/ltm/`. Edits to
   it are ordinary LTM events, traceable in `log/` via `/ltm:declare-rule`.
5. **Overwrite is allowed but nudged.** PreToolUse hook reminds you to
   supersede-with-reason or record-removal-reason when editing
   `index/` (L2) or `pinned.md` (L1). L3 (`log/`) is permissive — append-
   only is the convention there, edits silent.
6. **Manual ltm-append confirmation is in-conversation, hook-nudged.** The
   IRON-LAW in `ltm-append/SKILL.md` is the real gate for *user-driven*
   recording; Claude must verify a clear user go-word before writing.
7. **Autonomous L3 record marker.** When you (Claude) detect a closure
   moment worth recording without a record-request from the user, emit a
   `<ltm-record kind="..." title="...">body</ltm-record>` block in your
   reply. The Stop hook parses it and calls `append-entry.py --autonomous`.
   The block is visible to the user in the same turn — auto-record is
   transparent, not silent. Use sparingly: only when the closure is a
   *decision, abandonment, lesson, tradeoff resolution*. Open exploration
   is not marker-worthy.
8. **SessionEnd digest.** Auto-recorded entries accumulate in
   `.claude/ltm/.session-digest` during the session; SessionEnd rotates
   it to `.session-digest.pending`, which the *next* SessionStart inject
   surfaces. Errors or wrong entries are corrected by running
   `/ltm:distill` (which sees them as ordinary L3) — or via direct
   `Edit` on the L3 file if the user wants to fix mid-cycle.

## Project conventions (project-declared)

> Replace this section during `/ltm:init` and grow it via
> `/ltm:declare-rule`. Below are *suggestions only* — keep, drop, or
> rewrite freely.

### Entry kinds (suggested starting points)

> Pick what fits, drop what doesn't, invent your own. None are required
> by the harness.

- `decision` — choices made, with alternatives considered
- `anti-pattern` — what was tried and why it failed
- `finding` — analysis result that took effort to reach
- `philosophy` — meta-decisions about how this project is driven
- `discarded-hypothesis` — beliefs we abandoned and why
- `rule-evolution` — changes to this file (auto)
- `harness-version-changed` — auto event on plugin upgrade
- `model-version-changed` — auto event on model swap

### When to append (suggested triggers)

> The skill `ltm-append` watches for these phrases in conversation and
> proposes to record. Adjust phrases to fit how *you* actually talk.
> Add language-specific phrases here if your team works in another
> language; the skill will read this section.
>
> Two activation paths: passive (closure detection) + active (explicit
> user invocation, "let's record this" / "이거 기록하자"). See
> ltm-append SKILL.md for the active-mode trigger list.

- "decided", "we chose", "let's go with"
- "abandoned", "this won't work", "won't ship"
- "turns out", "the actual reason is", "we found that"
- "general principle", "lesson", "the takeaway is"
- "trade-off resolved as"

### Assent words (extending the IRON-LAW whitelist)

> `ltm-append` requires a clear go-word from the user before writing.
> Defaults are listed in the skill's IRON-LAW (English + Korean direct
> affirmatives). Add team-specific or language-specific go-words here;
> the skill will honour them. Keep ambiguous "soft yes" tokens out —
> the discipline is to filter `ok / okay / sure / 오케이 / ㅇㅋ` etc.

- (project-specific additions go here)

### Supersession

> How `supersedes` is used in your project. Default below; override here
> if you want different semantics (replace vs. fade vs. graph-link).

When a new entry contradicts an old one, set `supersedes: [<old-id>]` in
its frontmatter. The old entry stays on disk — history is preserved.
`ltm-recall` filters out superseded entries unless explicitly asked for
history.

### Read pattern

> How `ltm-recall` selects what to surface. Default below.

Default scan: latest 30 entries on activation, plus any entries whose
frontmatter `kind` matches the topic Claude inferred from the user
question. Rewrite this rule if your LTM grows large enough that
recency-only retrieval misses things.

## Boundary with hukuhaka-project-mapper

If this project also uses `hukuhaka-project-mapper`:

- `.claude/{map,design,backlog,changelog,spec}.md` = current-state mirror
  of the codebase (managed by hukuhaka-project-mapper)
- `.claude/ltm/` = time-axis narrative (managed by hukuhaka-ltm)

Both are valid. They split on whether the content has a *time axis*
(LTM) or describes *current state* (hukuhaka-project-mapper).

## Slash commands

| Command | Purpose |
|---|---|
| `/ltm:init` | (Re)bootstrap this file via interactive Q&A |
| `/ltm:declare-rule` | Propose change to this file; recorded as `rule-evolution` entry |
| `/ltm:distill` | Single mode — 6-step skeleton: cluster (subagent) → file mapping (main context) → N parallel card writers → validate (per-card cold-read) → l1-update → final-review → reproject. User gate at Step 2g (assignment plan) + Step 4 (validate issues, if any). No arguments. |
