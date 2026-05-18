# Composition — how to order and shape sections

> Section count, ordering, and the rhythm between heavy and light surfaces. The catalog says
> what surfaces exist; this document says how to arrange them.

## The default arc

Almost every report follows the same arc:

1. **Hero** — title, lead, meta strip. Sets identity and scope.
2. **Contents / TOC** — a `.toc` block listing the sections. Skip if the report has ≤4 sections.
3. **Goal & scope** — what this report exists to answer, what's explicitly out of scope.
4. **Context / Background** — references surveyed, prior decisions, constraints.
5. **The body** — the actual content. 3–8 sections, each focused on one question or theme.
6. **Decisions / Recommendations** — what you concluded, what to do.
7. **Deferred / Open questions** — what you explicitly chose not to resolve.
8. **Definition of done / Next steps** — checklist of what shipping means.

Not every report needs all eight. A short status report might be hero → 3 body sections → DoD.
A design brief uses all eight. Pick what fits.

## Rhythm — section weight

Within a chapter, sections should alternate visual weight. Two consecutive heavy sections
(large tables back-to-back) tire the reader; two consecutive light sections (only prose) blur
together. Use the catalog mix — table, KV list, card grid, callout, pre block, SVG — to keep
rhythm moving inside each chapter.

The chapter-level polarity flip (see next section) handles the larger rhythm — section weight
is the smaller-scale tool.

## Chapter-level polarity (the load-bearing rule)

Reports of **≥6 sections must be grouped into chapters of 3–5 sections each, and chapters
must alternate polarity at the chapter boundary**. The body background stays `var(--canvas)`
(white); the tinted chapter wraps in a `.band-tinted` block that **bleeds to viewport edges**
(width 100% — does NOT respect `<main>`'s max-width container). The negative-margin trick
in `tokens.css` makes that work even when `.band-tinted` is nested inside `<main>`.

This is the Carbon design system pattern — full-bleed tinted bands between white canvas
chapters. Single-section flips read as arbitrary; chapter-grouped + viewport-edge bleed
reads as deliberate structure.

### Grouping into chapters

Group consecutive sections that share a purpose into one chapter. Typical groupings:

- **Setup** chapter — Goal / Scope / Context / Background
- **Body** chapter — the mechanism, the walk-through, the in-the-weeds
- **Closing** chapter — Decisions / Open questions / Next steps / DoD

For the 12-section eval framework example:

| Chapter | Sections | Theme |
|---|---|---|
| 1 — What & Why | 1-3 (Goal / Shape / Types) | Concept entry |
| 2 — How it works | 4-8 (Pipeline / Seeding / Capture / Extract / Judge) | Mechanism |
| 3 — How to run | 9-12 (Run / Cache / Debug / DoD) | Operation |

### The default pattern — light → tinted → light

For a 3-chapter report:

```
Chapter 1 (canvas, white) → Chapter 2 (.band-tinted, full-bleed cool gray) → Chapter 3 (canvas, white)
```

The middle chapter — usually the "how it works" body — wraps in `.band-tinted`. The band
extends viewport-edge to viewport-edge; `.band-tinted-inner` restores `--content-max` for
the actual content alignment.

For a 4-chapter report: `canvas → tinted → canvas → tinted` alternating throughout.
For a 5-chapter report: `canvas → tinted → canvas → tinted → canvas` (sandwich brackets).

### When to escalate one chapter to `.band-dark`

`.band-dark` (full Carbon-black) is reserved for **at most one chapter per document**, and
only when its content genuinely demands maximum-volume emphasis (post-mortem, lessons, "what
went wrong"). Default rhythm doesn't need it — most reports ship with zero `.band-dark`.

If used, it replaces a `.band-tinted` slot in the alternation (not in addition to one). Two
adjacent non-canvas chapters are NOT a valid pattern — polarity must return to white canvas
between them.

### Section-level texture (within a chapter)

Inside a chapter, vary surface texture so two heavy sections (large tables back-to-back)
don't tire the reader and two prose-only sections don't blur together. Use the catalog mix
— card grid / KV list / table / callout / pre block / SVG.

### What NOT to do

| Anti-pattern | Why no |
|---|---|
| Wrapping a single section in `.band-tinted` | Polarity rule operates on chapters, not sections. Single-section flips look arbitrary. |
| `.band-tinted` whose width respects `<main>`'s max-width (no full-bleed) | Visually looks like a "container box" rather than a chapter band. The negative-margin trick must apply — confirm via browser inspect. |
| `.band-dark` chapter adjacent to `.band-tinted` chapter (no white anchor between) | Two adjacent non-canvas chapters read as one big dark blob. Polarity needs canvas between them. |
| Mixing `.card-dark` inside a `.band-tinted` chapter | The chapter is already on a flipped surface; double-flipping reads as noise. |

## Section header convention

Every section gets:

- An `<p class="eyebrow">// N / CATEGORY</p>` — mono, slash-prefixed, all-caps. No period.
- An `<h2>` — sentence-case, **no trailing period**. The Carbon spec we work from
  (templates/DESIGN-IBM.md) does not specify period-termination; an earlier version of this
  file falsely claimed it did. Removing the period is also direct user preference — periods on
  headings read as cluttered in this voice.

Subsections inside use `<h3>` (sentence-case, no period) and `<h4>` (sentence-case, no period)
inside the chosen primitive (card, callout, etc). Same rule across every heading level — the
ONLY headline-style element that takes terminal punctuation is body prose, never the heading.

## Chips-in-headlines anti-pattern

Do NOT put `<code class="inline">` inside an `<h2>` or `<h3>`. A 13px monospace chip dropped
into a 32px display headline reads as a foreign object — the visual rhythm collapses and the
chip dominates. If a heading needs to reference a code identifier:

- **Preferred** — restructure: put the prose heading on its own, then the code reference in a
  paragraph or `.spec-row` underneath.
- **Acceptable** — use the heading as plain text without backticks: `<h3>Run eval.sh</h3>` not
  `<h3>Run <code class="inline">eval.sh</code></h3>`. The mono font is for body context, not
  for headlines.
- **Never** — wrap a chip in the headline and trust readers to "filter it out."

This rule extends to the hero title and h4 sub-headers as well. Code references belong in
prose, KV lists, tables, callouts, or `<pre>` blocks — never in heading slots.

## When to use the TOC

Include the TOC block when:

- The report has ≥5 sections.
- A reader is likely to jump between sections rather than read top-to-bottom.
- Section anchors are useful for sharing (`#cso`, `#tokens` etc).

Skip the TOC when:

- ≤4 sections — the TOC adds chrome without saving the reader anything.
- The report is meant to be read linearly only (e.g., a story-form post-mortem).

## Title and lead — the two highest-leverage choices

The hero title and lead are the only two pieces of copy the reader sees before deciding whether
to keep reading. Treat them like the most important sentence in the document.

**Title rules:**
- Sentence-case, **no trailing period**.
- One sentence, ≤80 characters, breaks naturally onto 1 or 2 lines.
- States the *thesis* of the report, not the *topic*. "Build and deploy on the AI Cloud" not
  "Vercel Marketing Page".
- No period — periods on hero titles read as cluttered in this voice and are inconsistent with
  the nav-title and section headings, which are also unterminated.

**Lead rules:**
- 1–2 sentences, ≤2 lines at desktop width.
- Sets the framing. Names the *posture* of the report (design brief? audit? walkthrough?).
- Does not summarise — it primes.

**Meta strip rules:**
- Mono, small (12px), gap `--space-lg`.
- Always: author, project, date.
- Often: status, source, version.
- Format: `<b>Label</b> value` per item.

## Three reports' worth of arc examples

### A. Design brief (12 sections, 3 chapters)

```
Ch 1 — Premise (canvas):     Hero · TOC · Goal & non-goal · References surveyed
Ch 2 — Mechanism (tinted):   Identity · Directory layout · SKILL.md skeleton · Building blocks
Ch 3 — Application (canvas): Decision matrix · Enforcement · Description (CSO) · Tokens · Deferred · DoD
```

Chapter 2 wraps in full-bleed `.band-tinted`. No `.band-dark` needed.

### A short status report (6 sections, 2 chapters)

```
Ch 1 — Snapshot (canvas):    Hero · Status summary (1 callout) · What's done (table)
Ch 2 — Outlook (tinted):     What's open (checklist) · Risks (callout warn) · Owner & ETA (KV)
```

`.band-tinted` for chapter 2. No TOC. The tinted band frames forward-looking content.

### B. Eval walkthrough (12 sections, 3 chapters)

```
Ch 1 — What & why (canvas):   Hero · TOC · What we evaluated · Method (SVG)
Ch 2 — Results (tinted):      Setup · Results per type ×4 (table + chart each)
Ch 3 — Takeaways (canvas):    Failure patterns · Wins · What changed · Recommendations
```

`.band-tinted` wraps the entire results chapter (full-bleed cool gray). Static SVGs in
`.svg-wrap`.

## Closing thoughts

- Reports are scanned more than read. Headlines, eyebrows, and table columns do most of the work.
- A long report is fine. A *padded* report is not. Cut anything that doesn't change a decision.
- The visual consistency comes from the tokens and the catalog. Trust the system — don't add
  custom CSS to "polish" individual sections.
- If you find yourself wanting a primitive that isn't in the catalog, that's a signal to either
  reshape the content into an existing primitive, or — if it's a real recurring need — surface
  it back as a candidate to add (do not silently invent inline).
