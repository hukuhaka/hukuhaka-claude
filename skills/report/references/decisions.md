# Decisions — surface-selection matrix

> Picking the surface deterministically. For every kind of content, there's a default — go to
> the default first, switch only if the default is plainly wrong for the data.

## At a glance

| The content is…                                | Default                | Don't reach for          |
|------------------------------------------------|------------------------|--------------------------|
| Comparison across rows × columns               | Table (+ `<caption>`)  | 3 cards in a row         |
| One idea + one supporting paragraph            | Card                   | Standalone `<p>`         |
| One identity / pull-quote sentence             | Dark card              | Italic blockquote        |
| Section-scale polarity flip (≥6 section reports) | **`.band-dark`**     | Skipping it              |
| Attribute → value pairs (sparse, ≤6)           | KV list in card        | 2-column table           |
| One paragraph that needs separation            | Callout                | Wrapping in `<strong>`   |
| Acceptance criteria / definition of done       | Checklist              | Bulleted list            |
| Code, frontmatter, directory tree              | `<pre>` block          | Inline `<code>` runs     |
| Hand-positioned diagram (known coords)         | Static SVG in `.svg-wrap` | react-flow / mermaid  |
| Numeric series (≤30 points, bar or line shape) | chart.js bar/line      | D3 + force layout        |
| Network / hierarchy / graph                    | Table (parent / child) | Any auto-layout graph    |
| Sub-units inside a section (3 traits)          | `.card-soft` × 3       | Bulleted list            |
| Status tag, inline metadata                    | Badge                  | Parenthetical            |
| Two or three coordinated metadata badges       | `.spec-row` (one taxonomy axis only) | Stack of solo badges |
| Form control (CTA, secondary action, danger)   | `.btn-primary` / `.btn-secondary` / `.btn-tertiary` / `.btn-danger` | Plain `<a>` styled inline |
| Single-line user input (search, filter)        | `.input-field`         | Borderless contenteditable |
| Mutually-exclusive top-level views (≤4)        | `.tab-bar` + `.tab`    | Buttons inside a card    |
| Active TOC item / current section anchor       | `.toc-list a[aria-current]` / `:target` style | Inline bold styling      |
| Top of the document                            | Hero band              | (nothing else)           |

---

## Two questions to ask before picking

### Q1 — Does this have inherent tabular structure?

If yes → **table**. Examples: feature × support, error × cause × fix, role × responsibilities.
Tables are the most information-dense surface. If the data wants rows and columns, give it
rows and columns.

### Q2 — Is this one idea, or three sibling ideas?

- One idea, ≤5 lines → **card** in single column, OR a callout if it's specifically a warning
  / cross-cutting note.
- One idea, single sentence, identity-defining → **dark card**.
- Three sibling ideas (peers, parallel structure) → **`.grid-3`** of `.card-soft` (light)
  or `.card` (heavier).
- Two sibling ideas (compare / contrast) → **`.grid-2`** of `.card`.

---

## Disambiguating the close calls

### Card vs table — "I have 4 things to say about X"

- If each "thing" is **internally structured** (label + value + note) → table.
- If each "thing" is a **standalone paragraph** → cards in a 2-up or 3-up grid.
- If each "thing" is **one line** → bulleted list inside a single card.

### Card vs callout — "this is important"

- Callouts have a **mono eyebrow** and a **colored left border**. They interrupt the flow.
- Cards are part of the flow. They don't shout.
- Use callout for: warnings, lessons from past failures, "if you remember nothing else".
- Use card for: the main body content of a section.

### KV list vs 2-column table — "attribute → value"

- ≤6 pairs, sparse, one line each → **KV list inside a card**.
- 7+ pairs, OR multi-line values, OR needs a third column → **table**.

### Static SVG vs chart vs table — "I want to show this visually"

Walk the ladder, top to bottom — first one that fits, stop.

1. Is the data tabular (rows × columns, no positions)? → **table**.
2. Is it a numeric series (≤30 points, bar/line shape)? → **chart.js**.
3. Is it a diagram with ≤6 nodes you can hand-place? → **static SVG**.
4. Otherwise → it doesn't belong in a report. Return to the table.

---

## When the answer is "none of the above"

Sometimes content does not fit any primitive — it's prose. That's fine. Plain `<p>` inside a
`.card` or directly under a section heading is the catch-all. The catalog doesn't try to
geometrify everything; it just removes the noise so the prose stands out.

---

## Hero — fixed mandate #1

Every report has exactly one hero band at the top. Skipping it makes the file read like a draft.
Keep the title to one or two lines, sentence-case, **no period**. Lead sentence ≤2 lines.
Meta strip has author / project / date — extend with status, source, scope as fits.

## Chapter-level polarity — fixed mandate #2 (Carbon)

Reports of **≥6 sections must be grouped into chapters of 3–5 sections each, and chapters
must alternate polarity at the chapter boundary**. Body background stays `var(--canvas)`
(white). Tinted chapters wrap in `.band-tinted` — a **full-bleed band** that extends to
viewport edges (not constrained by `<main>`'s max-width). Single Cool Gray 10 tone
(`--surface-tinted: #f2f4f8`).

Default 3-chapter pattern: `canvas → tinted → canvas` (middle chapter wraps in `.band-tinted`).
Default 4-chapter pattern: `canvas → tinted → canvas → tinted`. The white canvas always
anchors chapter 1.

`.band-dark` (full Carbon-black) is **optional** and reserved for at most ONE chapter per
document — only when a chapter genuinely demands maximum-volume emphasis (post-mortem,
lessons, "what's at stake"). When used, it replaces a tinted chapter in the alternating
pattern (not in addition to one). Most reports ship with zero `.band-dark`. Single-section
polarity flips are NOT a valid satisfaction of this rule — the polarity operates on chapters,
not sections.

**Full-bleed requirement**: `.band-tinted` MUST extend viewport-edge to viewport-edge. The
`tokens.css` rule uses negative-margin (`calc(50% - 50vw)`) to break out of any parent
container's max-width. If the band visually looks like a "box" stuck inside a 1200px column,
the bleed isn't working — confirm via browser inspect.

See [`composition.md`](composition.md) → "Chapter-level polarity" for grouping heuristics,
the full pattern table, and the four anti-patterns to avoid.

## Heading rule — fixed mandate #3

Every heading (h1, h2, h3, h4) is **sentence-case with no trailing period**. Same rule across the
nav-title and the hero-title. Eyebrows above headings (`<p class="eyebrow">`) are slash-prefixed
mono-tracked uppercase and also take no period. The only place terminal punctuation belongs is
in body prose. (DESIGN-IBM.md does not specify period-termination; an earlier draft of these
references claimed it did, and was wrong.)

## SVG color rule — fixed mandate #4

Every fill in a static SVG must map to a semantic role from this fixed set: **neutral**
(`var(--canvas)` + `var(--hairline)` stroke), **primary path** (`var(--primary)` for a
**continuous** through-line — every node on the path, not just emphasized ones), **milestone**
(`var(--ink)` for endpoints / key results), **status** (`var(--semantic-*)` only when the
node IS a status, not when it handles or relates to one). If a node has no role, it stays
neutral.

### Two-question SVG decision tree

```
Q1 — Is there a single CONTINUOUS path the reader must trace?
     YES → every node on that path = primary, off-path = neutral.
     NO  → Q2

Q2 — Is there a single endpoint / result?
     YES → all nodes neutral, endpoint only = milestone (ink).
     NO  → all nodes neutral.

Overlay (any case) — Are any nodes themselves a status?
     YES → those specific nodes = semantic color. Others by Q1/Q2.
```

The five canonical SVG patterns (linear pipeline, through-path emphasized, branching decision,
parallel-merge, status overview) and copy-pasteable skeletons live in
[`building-blocks.md`](building-blocks.md) → "SVG diagram patterns — five templates" and the
anti-example from the prior eval pipeline figure.

**Red flag**: if your diagram has TWO primary-path nodes that are NOT adjacent (a neutral
node between them), you are NOT following Pattern 2 — primary is supposed to be CONTINUOUS.
Either extend primary to cover the middle node, or drop both primaries and use Pattern 1
(neutral + final milestone).

## Chips-in-headlines — fixed mandate #5

Never wrap `<code class="inline">` inside `<h1>`, `<h2>`, `<h3>`, or `<h4>`. A 13px mono chip
dropped into a 32px display headline collapses the visual rhythm. See
[`composition.md`](composition.md) → "Chips-in-headlines anti-pattern" for the rewrites.

---

## Things you'll be tempted to do — and shouldn't

| Temptation                                                     | Why no                                                      |
|---------------------------------------------------------------|--------------------------------------------------------------|
| "I'll use 4 cards in a row to fit more"                       | Grid is `.grid-2` or `.grid-3`. 4-up cramps everything.      |
| "I'll skip the hero, this report is short"                    | The hero IS the identity. A skipped hero looks like a draft. |
| "I'll add a tab switcher so the user can pick a view"         | Reports are static. Compose all views top-to-bottom.         |
| "I'll mermaid this graph, it's small"                         | No auto-layout. Use a parent/child table or hand SVG.        |
| "I'll color this section red because it's important"          | Use a `.callout.warn` or `.callout.danger`. Don't recolor sections. |
| "I'll center-align everything for a cleaner look"             | Text is left-aligned in this system. Centering is for hero only. |
| "I'll use bold + italic + a yellow background for emphasis"   | Emphasis = a callout. Inline styling is noise.               |
