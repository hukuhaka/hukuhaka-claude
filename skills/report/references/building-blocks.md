# Building Blocks — primitive catalog

> The closed surface vocabulary. Every report section is composed from exactly these primitives.
> CSS classes are defined in `assets/tokens.css` (mirror of templates/DESIGN-IBM.md, IBM Carbon
> Design System) and embedded in `assets/template.html`. Just use the class names — do not
> redefine styles inline.
>
> Carbon principles in force across every primitive:
> 1. **Flat 0px corners.** No rounded radius anywhere.
> 2. **Depth = surface change + 1px hairline.** No drop shadow. No gradient.
> 3. **IBM Blue is the only chromatic accent.** Semantic green / yellow / red are status-only.
> 4. **Letter-spacing 0.16px on body, 0.32px on caption.** Carbon precision detail.
> 5. **IBM Plex Sans** for everything sans; **IBM Plex Mono** for eyebrows / code / kv labels.

## Quick reference

| Primitive          | Class                              | Depth cue                   | One-line use                                       |
|--------------------|------------------------------------|------------------------------|----------------------------------------------------|
| Card               | `.card`                            | canvas + 1px hairline        | One self-contained idea. Grouped in `.grid-2` / `.grid-3`. |
| Soft card          | `.card-soft`                       | surface-1 + 1px hairline     | Sub-unit inside a grid where `.card` chrome would be heavy. |
| Dark card          | `.card-dark`                       | inverse-canvas, no border    | Identity statement, pull-quote, single polarity flip. |
| Tinted band        | `.band-tinted` + `.band-tinted-inner` | **viewport-edge full-bleed** Cool Gray 10 | **Default chapter-level polarity flip.** Use for the gray chapter in canvas → tinted → canvas rhythm. |
| Dark band          | `.band-dark` + `.band-dark-inner`  | full-bleed inverse-canvas    | Strong-emphasis chapter flip. **Max 1 per report**, only when content genuinely demands maximum contrast. |
| Table              | `<table>` (no class)               | 1px hairline + zebra surface-1 | Comparison across rows × columns.                |
| KV list            | `<dl class="kv">`                  | flat, inside a card          | Sparse attribute → value pairs.                    |
| Callout            | `.callout` `.warn` `.danger` `.success` | surface-1 + 3px left accent | One paragraph that needs separation.            |
| Code block         | `<pre>`                            | inverse-canvas, mono         | Code, frontmatter, directory tree.                 |
| Checklist          | `<ul class="check">`               | 1px hairline rows            | Definition-of-done, acceptance criteria.           |
| Badge              | `.badge` `.badge-primary` `.badge-ink` `.badge-success` `.badge-warn` `.badge-danger` | flat, 1px hairline | Tiny metadata pill — inline or in `.spec-row`. |
| Spec row           | `.spec-row`                        | flex layout, taxonomy-bound  | 2–3 coordinated badges on a single classification axis. |
| Button             | `.btn` `.btn-primary` `.btn-secondary` `.btn-tertiary` `.btn-danger` `.btn-ghost` | 0 radius, semantic fill | CTA, secondary action, danger action.    |
| Input              | `.input-field`                     | flat, surface-1 fill         | Single-line text / search input.                   |
| Tab bar            | `.tab-bar` + `.tab`                | 1px bottom rule, active border-bottom 3px | Mutually exclusive top-level views (≤4). |
| Static SVG         | `<svg>` (hand coords)              | flat                         | Bespoke diagram, positions known up-front.         |
| Static chart       | `chart.js` bar/line                | flat                         | Numeric series ≤ 30 points.                        |
| Hero band          | `.hero` + `.hero-inner`            | white canvas + 1px bottom rule | Top-of-report. Once per document.                |
| SVG wrap (mobile)  | `.svg-wrap`                        | scrollable                   | Wraps a static SVG so mobile gets horizontal scroll instead of crushed text. |
| TOC active state   | `.toc-list a[aria-current]` / `:target` | accent left border + bold ink | Mark the section the user just scrolled to / jumped from. |

---

## Card — `.card`

White surface, 1px `--hairline` border, 0 radius. Padding `--space-lg` (24px). No shadow.

```html
<div class="grid-2">
  <div class="card">
    <h3>One idea</h3>
    <p>One supporting paragraph.</p>
  </div>
  <div class="card">
    <h3>Sibling idea</h3>
    <p>One supporting paragraph.</p>
  </div>
</div>
```

**Reach for it when:** an idea has a 1-line headline plus 2–5 lines of body.
**Avoid when:** the idea wants tabular structure (use `<table>`) or needs visual prominence (use
`.card-dark`).

---

## Soft card — `.card-soft`

`--surface-1` (#f4f4f4) fill, 1px `--hairline` border, 0 radius. Use inside a grid where the
default white card chrome would be too heavy (e.g., three "characteristics" cards under one
section heading). This is Carbon's "Recommended" tile pattern.

```html
<div class="grid-3">
  <div class="card-soft">
    <h4>Trait A</h4>
    <p>Short body.</p>
  </div>
  <div class="card-soft"> … </div>
  <div class="card-soft"> … </div>
</div>
```

**Reach for it when:** secondary grids inside a section, or KV-list containers.
**Avoid when:** the unit needs to draw a strong frame against the page — promote to `.card`.

---

## Dark card — `.card-dark`

Inverse-canvas (#161616) fill, white text, 0 radius. Reserved for identity statements or one
pull-quote-style sentence to elevate.

```html
<div class="card-dark">
  <p class="eyebrow">IDENTITY</p>
  <p style="font-size: 18px; line-height: 1.40;">
    The single load-bearing sentence of the document.
  </p>
</div>
```

**Reach for it when:** one pull-quote sentence, or one identity card.
**Avoid when:** the content runs more than ~5 lines — use `.band-dark` instead.

---

## Full-width tinted band — `.band-tinted` + `.band-tinted-inner`

**The default chapter-level polarity flip.** A viewport-edge-to-viewport-edge full-bleed
band tinted in Cool Gray 10 (`--surface-tinted: #f2f4f8`). The band breaks out of any
parent container's max-width via a negative-margin trick (`margin-left: calc(50% - 50vw)`),
so it works even when placed inside `<main>`'s 1200px column. `.band-tinted-inner` restores
`--content-max` for the actual content alignment.

This is the Carbon design system pattern — visually the page reads as alternating
white-canvas and tinted bands, edge to edge, with content always aligned to the same
1200px center column.

```html
<!-- Wrap an entire chapter (3-5 sections) in one .band-tinted.
     Placing it inside <main> is fine — the negative-margin trick still bleeds
     to viewport edges. -->
<div class="band-tinted">
  <div class="band-tinted-inner">

    <section id="capture">
      <p class="eyebrow">// 4 / CAPTURE</p>
      <h2>Capture</h2>
      <p>…</p>
    </section>

    <section id="extract">
      <p class="eyebrow">// 5 / EXTRACT</p>
      <h2>Extract</h2>
      <p>…</p>
    </section>

    <section id="judge">
      <p class="eyebrow">// 6 / JUDGE</p>
      <h2>Judge</h2>
      <p>…</p>
    </section>

  </div>
</div>
```

**Verify full-bleed in browser**: the tinted area must touch the left and right window
edges (no white margin showing). If it stops at the 1200px column boundary, the negative-
margin rule isn't applying — check parent overflow settings.

**Reach for it when:** every report of ≥6 sections needs one. Wrap the middle chapter (the
one most about "how it works underneath" — the body, the mechanism, the in-the-weeds part).
**Avoid when:** wrapping a single section (chapter primitive — single-section flips look
arbitrary), or wrapping the opening/closing chapter (kills the document's natural canvas
anchor).

## Full-width dark band — `.band-dark` + `.band-dark-inner`

**Strong-emphasis chapter flip.** Maximum-contrast Carbon-black full-bleed band. Reserved
for at most ONE chapter per document, and only when its content genuinely warrants the
volume — a post-mortem narrative, a lessons-learned chapter, a "what went wrong" chapter.
Use sparingly; default to `.band-tinted` for ordinary chapter rhythm.

The band uses the same negative-margin viewport-bleed trick as `.band-tinted`. Same
HTML wrapping pattern (`.band-dark` outer, `.band-dark-inner` for max-width content).

**Reach for it when:** a single chapter genuinely demands maximum-volume emphasis.
**Avoid when:** the rhythm need is satisfied by `.band-tinted`. Default to tinted; promote
to dark only when tinted feels insufficient.

---

## Table — `<table>`

The default for comparison. surface-1 header band, 14/600 header type, alternating-row zebra
stripes (`tr:nth-child(even)` → surface-1), 1px hairline border around the table, 0 radius.
Include a `<caption>` whenever the table's purpose isn't obvious from surrounding prose — it
both labels the table for sighted readers (mono eyebrow style) and provides a screen-reader
landmark.

```html
<table>
  <caption>5 EVAL TYPES — extract + judge pipeline per type.</caption>
  <thead><tr>
    <th>Type</th><th>Extract</th><th>Judge</th>
  </tr></thead>
  <tbody>
    <tr><td>logic</td><td>(none)</td><td>eval_logic.py</td></tr>
    <tr><td>quality</td><td>extract_docs.py</td><td>eval_quality.py</td></tr>
  </tbody>
</table>
```

**Reach for it when:** ≥3 columns OR ≥4 rows of comparable items.
**Avoid when:** sparse attribute→value pairs (use KV list) or three "cards in a row"-shaped items.

### Density and comfort

Carbon's default table is the **comfortable** density — `--line-height-table` 1.60, padding
`var(--space-sm) var(--space-md)`. That's the default and what `tokens.css` ships. Use this
for any table where a row contains more than ~6 words on average — without breathing room,
adjacent rows visually fuse and the user reads two rows as one.

- **Cell wrapping**: leave it on (default). Forcing `white-space: nowrap` makes long values
  scroll horizontally and breaks the mobile view. If a column genuinely never wraps (status
  badges, version numbers), wrap its content in `.badge` or `<code>` instead of touching
  white-space.
- **Vertical alignment**: top (default in tokens.css). Bottom or middle break Carbon's
  reading rhythm.
- **Inline code in cells**: use `<code>` directly — `tokens.css` styles `tbody td code` to
  inherit the inline-chip treatment, no `class="inline"` needed. Quote characters (`"`, `'`)
  inside the chip read as visual noise — drop the quotes or move the code out of the chip if
  the literal quotes matter (e.g., `<code>empty</code>`, not `<code>"empty"</code>`).
- **Column widths**: let the browser size them automatically. The only time to override is
  when a primary identifier column needs a fixed width — use `<col style="width: 18%">` then,
  not inline styles on `<td>`.

If your table needs **denser** rows (e.g., 30+ rows of numeric data where line-height 1.60
wastes vertical space), add `class="table-dense"` to the `<table>` element — that switches
to `--line-height-table-dense` 1.30 and reduced padding. Avoid for any text-heavy table.

---

## KV list — `<dl class="kv">`

Compact attribute → value rendering. Mono label column (160px) in `--ink-muted`, ink value column.
Lives inside a `.card` or `.card-soft`.

```html
<div class="card">
  <h3>Reference</h3>
  <dl class="kv">
    <dt>file</dt><dd>scripts/deploy.sh</dd>
    <dt>lines</dt><dd>898</dd>
    <dt>owner</dt><dd>scripts/</dd>
  </dl>
</div>
```

**Reach for it when:** ≤6 sparse pairs, content fits on one line each.
**Avoid when:** 3+ columns needed → promote to a table.

---

## Callout — `.callout` / `.callout.warn` / `.callout.danger` / `.callout.success`

surface-1 fill, 3px left accent border (color carries the semantic), no rounded corners. Four
variants — info (IBM Blue), warning (yellow-30), danger (red-60), success (green-50). Always
carries a mono eyebrow.

```html
<div class="callout warn">
  <p class="callout-eyebrow">LESSON — FLOWMAP</p>
  <p>The one-paragraph thing that needs separation from the flow.</p>
</div>
```

**Reach for it when:** a cross-cutting note, a warning, a "if you remember nothing else".
**Avoid when:** stacking three in a row — convert to a card grid.

---

## Code block — `<pre>`

Inverse-canvas (#161616) fill, IBM Plex Mono at 13px / 1.50, inverse-ink text. 1px inverse-surface-1
border, 0 radius. Color tokens for sparse highlighting: `.c-key` (blue-30), `.c-val` (yellow),
`.c-cmt` (gray italic), `.c-tag` (purple-30), `.c-str` (green-30). Light dark-mode-friendly stops,
not full syntax.

```html
<pre><span class="c-cmt">---</span>
<span class="c-key">name:</span> <span class="c-val">report</span>
<span class="c-cmt">---</span>
</pre>
```

**Reach for it when:** any code, schema, or path tree.
**Avoid when:** prose — readability collapses in monospace.

---

## Checklist — `<ul class="check">`

1px hairline rows, square unchecked-box marker (no checkmarks — Carbon resists them). For
definition-of-done, acceptance criteria, audit punch lists. Visually distinct from regular `<ul>`.

```html
<ul class="check">
  <li>The thing is done.</li>
  <li>The other thing is verified.</li>
</ul>
```

**Reach for it when:** definition-of-done, action-item list with finite scope.
**Avoid when:** open-ended bulleted thoughts — use plain `<ul>`.

---

## Badge — `.badge` and variants

Mono-tracking caption pill. 0 radius (square — Carbon never pills badges on marketing).
Variants: `.badge` (surface-1 / ink-muted), `.badge-primary` (IBM Blue fill), `.badge-ink`
(charcoal fill), `.badge-success` / `.badge-warn` / `.badge-danger` (white fill + semantic
border + text).

```html
<h3>Reference <span class="badge badge-ink">spec</span></h3>
```

**Reach for it when:** inline metadata tag, status indicator.
**Avoid when:** the content needs more than ~3 words — promote to a callout or KV row.

> A row of 2–3 coordinated badges goes in `.spec-row` — see the next entry. A solo badge
> inline in a heading or paragraph does not need any wrapper.

---

## Spec row — `.spec-row`

A horizontal flex row of 2–3 badges that all express **one classification axis** (e.g.,
"required / optional / contextual", or "deterministic / heuristic / raw"). The badges are
peers on the same dimension, not three unrelated tags. Use `.spec-row` to give that group
its own breathing room above/below.

```html
<!-- Three peers on one axis: pipeline stage classification -->
<div class="spec-row">
  <span class="badge badge-primary">required</span>
  <span class="badge">optional</span>
  <span class="badge badge-warn">deprecated</span>
</div>
```

**Reach for it when:** you have 2–3 badges that together form a small classification (filter
chips, taxonomy tags, status set). The visual unit is the row, not the individual badge.
**Avoid when:**
- A single solo badge — drop it inline instead of wrapping.
- More than ~4 badges — escalate to a `.callout` or a small `<table>`.
- Badges from different taxonomies mixed together (e.g., "passing" + "v1.1" + "high-risk")
  — that's not one axis, that's three separate facts; use a KV list or three solo inline
  badges.
- **Directly under a `<table>` with no intervening text.** A `.spec-row` placed against the
  bottom edge of a table reads as a table footer. Always separate with a paragraph or a
  `<h3>` so the reader knows the badges belong to the next section, not the table.

**Naming the axis:** if the three badges' relationship isn't obvious from the labels alone,
precede the `.spec-row` with a short eyebrow or sentence: `<p class="eyebrow">// PIPELINE
STAGE</p>`. Don't make the reader guess what dimension the badges are sorting on.

---

## Static SVG — `<svg>` (with mandatory accessibility)

Hand-positioned coordinates only. Always include `<title>` (short) and `<desc>` (longer
description) immediately after the opening `<svg>` tag — screen readers need them, and they
double as documentation for future-you.

For diagrams wider than ~700px, wrap in `.svg-wrap` so mobile gets horizontal scroll instead
of crushed-to-illegible labels.

```html
<div class="svg-wrap">
  <svg viewBox="0 0 1040 220" xmlns="http://www.w3.org/2000/svg" role="img"
       aria-labelledby="pipeline-title pipeline-desc">
    <title id="pipeline-title">Eval pipeline overview</title>
    <desc id="pipeline-desc">Seven sequential steps from scenario load through aggregate output.</desc>

    <rect x="20"  y="60" width="140" height="80" fill="var(--canvas)" stroke="var(--hairline)"/>
    <text x="90"  y="105" text-anchor="middle" font-family="var(--font-sans)" font-size="14"
          fill="var(--ink)">Load</text>
    <!-- … more boxes / arrows … -->
  </svg>
</div>
```

**Reach for it when:** ≤8 nodes, positions decided by you, no data-dependent layout.
**Avoid when:** positions depend on data — return to a table.

### SVG color semantics (mandatory)

Every fill in a static SVG maps to a **semantic role** from this fixed set. There is no
"decorative" color. If a node has no role, leave it neutral. Mixing roles across the same
diagram is the fastest way to confuse a reader.

| Role | Fill | Stroke | When |
|---|---|---|---|
| **Neutral** (default) | `var(--canvas)` | `var(--hairline)` 1px | Any node whose meaning is "just a step". 80% of nodes in most diagrams. |
| **Primary path** | `var(--primary)` (#0f62fe) | `var(--primary)` | The through-line you want the reader to trace — main flow arrow, recommended branch, "happy path." Use sparingly; one path per diagram. |
| **Milestone** | `var(--ink)` (#161616) | `var(--ink)` | Endpoints, key states, "you are here" markers. Carbon's heaviest fill — reserves attention. |
| **Status — success** | `var(--semantic-success)` (#24a148) | same | The node IS reporting success (e.g., "tests passed"). Not "this part is good". |
| **Status — warning** | `var(--semantic-warning)` (#f1c21b) | same | The node IS a warning condition. |
| **Status — error** | `var(--semantic-error)` (#da1e28) | same | The node IS an error / failure state. |
| **On-dark surface** | `var(--inverse-canvas)` for fill, `var(--inverse-ink-muted)` for stroke | — | SVGs inside `.band-dark` or `.card-dark`. Swap the entire palette to inverse tokens; never mix light + dark fills in one diagram. |

**Rules of consistency** within one diagram:

- Use **one** primary-path color per diagram (always `var(--primary)`). If a second flow
  needs distinction, use `var(--ink)` (milestone family). Never introduce a third chromatic
  color "just because we have three branches" — restructure into two diagrams or use line
  style (`stroke-dasharray`) to distinguish.
- Status colors only appear on nodes that ARE statuses. Coloring node 3 yellow because
  "it's tricky" is not a status — it's authorial intuition leaking into the diagram. Either
  promote it to a `.callout warn` outside the SVG, or leave it neutral.
- Text labels: `var(--ink)` on light surfaces, `var(--inverse-ink)` on dark surfaces. Never
  color the label to match the node fill — Carbon labels are always high-contrast text.
- Stroke widths: 1px for neutral, 1.5–2px for primary path / milestone. Don't use stroke
  width to indicate importance independently of color — color carries the role.

**Anti-pattern checklist** (red flags from past reports):

- Coloring 3 of 6 boxes "for visual interest" with no role mapping → all 6 should be neutral.
- Using `--semantic-warning` (yellow) as a generic "highlight" → reserved for actual warning
  conditions. Use neutral + a bold stroke if you need attention without semantic meaning.
- Two adjacent primary-path nodes with different shades of blue → use the same `--primary`.
- Status fills on connecting arrows → arrows carry role via color too; only color arrows
  that ARE the primary path. Other arrows stay neutral.

### SVG diagram patterns — five templates

Before coloring an SVG, identify which of these five patterns it is. Each row tells you
exactly which color goes where. If your diagram doesn't fit any of these, default to "all
neutral, last node milestone."

| # | Pattern | Color rule | Skeleton |
|---|---|---|---|
| 1 | **Linear pipeline** (A → B → C → D) | All nodes `var(--canvas)` + `var(--hairline)` stroke. Last node `var(--ink)` fill (milestone). All arrows `var(--hairline-strong)`. | `seed → capture → extract → judge → result` — only `result` gets ink fill |
| 2 | **Through-path emphasized** | The entire path (every node on it) gets `var(--primary)` stroke (width 2px). Off-path nodes stay neutral. Arrows on path get `var(--primary)`, off-path arrows stay neutral. | "Happy path" through a 7-step flow — the 4 success steps are primary, the 3 alternate branches stay neutral |
| 3 | **Branching decision** (A → {B, C} → D) | Decision node = `var(--ink)` fill (milestone — "here we choose"). Branches neutral. Convergence node neutral. | Yes/no fork: question node ink, both answer nodes neutral |
| 4 | **Parallel flows merging** | Each flow's nodes neutral. Convergence / result node `var(--ink)` fill (milestone). | 3 concurrent jobs → 1 aggregate result; result is ink |
| 5 | **Status overview** (dashboard) | All nodes neutral by default. Only nodes that ARE a status get `var(--semantic-success / --semantic-warning / --semantic-error)`. | Component health grid: green for "up", red for "down" — no other color |

Skeletons in SVG form (copy-paste, swap labels):

```html
<!-- Pattern 1: linear pipeline (all neutral + milestone last) -->
<rect x="20" y="60" width="140" height="60" fill="var(--canvas)" stroke="var(--hairline)"/>
<rect x="180" y="60" width="140" height="60" fill="var(--canvas)" stroke="var(--hairline)"/>
<rect x="340" y="60" width="140" height="60" fill="var(--canvas)" stroke="var(--hairline)"/>
<rect x="500" y="60" width="140" height="60" fill="var(--ink)" stroke="var(--ink)"/>
<text x="570" y="95" text-anchor="middle" fill="var(--on-primary)" font-weight="600">result</text>
```

```html
<!-- Pattern 2: through-path emphasized (continuous primary) -->
<rect x="20" y="60" width="140" height="60" fill="var(--canvas)" stroke="var(--primary)" stroke-width="2"/>
<rect x="180" y="60" width="140" height="60" fill="var(--canvas)" stroke="var(--primary)" stroke-width="2"/>
<rect x="340" y="60" width="140" height="60" fill="var(--canvas)" stroke="var(--primary)" stroke-width="2"/>
<rect x="180" y="160" width="140" height="60" fill="var(--canvas)" stroke="var(--hairline)"/> <!-- off-path -->
<line x1="160" y1="90" x2="180" y2="90" stroke="var(--primary)" stroke-width="2"/>
<line x1="320" y1="90" x2="340" y2="90" stroke="var(--primary)" stroke-width="2"/>
```

### Two-question decision tree

If the patterns table isn't an obvious match, walk this:

```
Q1 — Is there a single connected path the reader must trace?
     YES → Pattern 2 (every node on that path = primary, continuous; off-path = neutral)
     NO  → Q2

Q2 — Is there a single endpoint / result / target?
     YES → Pattern 1 or 4 (all neutral, endpoint = milestone ink)
     NO  → All nodes neutral. Stop.

Q3 (overlay — applies regardless) — Are any nodes themselves a status (success/warn/error)?
     YES → Those specific nodes get --semantic-*. Others follow Q1/Q2.
     NO  → No semantic color anywhere.
```

Three rules that are easy to forget:

- **Primary path is CONTINUOUS**, not "the nodes you want to emphasize". If two non-adjacent
  nodes both feel important but the path between them is also important, the *whole* span is
  primary. If you can't justify the in-between nodes as primary, the path you actually want is
  shorter — restrict primary to the genuinely continuous run.
- **Milestone is for ENDPOINTS**, not "the cool stage". A node gets ink fill because the
  reader's eye should land there last, not because it's interesting.
- **Semantic colors are for NODES THAT ARE STATUSES**, not "the part that's working / broken".
  "This stage handles errors" does not earn the node a red fill; "this node reports a failure
  state to the reader" does.

### Anti-example — from a real prior report

The eval pipeline figure in `2026-05-18-eval-framework-walkthrough-v2.html` was:

```
seed (neutral) → capture (PRIMARY) → extract (neutral) → judge (PRIMARY) → result (ink)
```

**Why this was wrong:** Primary path is supposed to be one continuous chain. Coloring
capture and judge as primary while leaving extract neutral made the "through-line" skip a
node — visually it looked like two unrelated highlights, not a traced path. The author
intent was "these two stages define each eval type" — but that's a *grouping* claim, not a
*path* claim, and SVG color encodes path-ness.

**Two valid fixes:**

```
Fix A (linear pipeline — Pattern 1):
seed (neutral) → capture (neutral) → extract (neutral) → judge (neutral) → result (ink)
All arrows neutral. Reader's eye lands on result.

Fix B (through-path emphasized — Pattern 2):
seed (neutral) → capture (PRIMARY) → extract (PRIMARY) → judge (PRIMARY) → result (PRIMARY ink)
Arrows from capture onwards all primary. Reader traces the whole "scenario flow"
continuously. seed is the off-path setup.
```

Pick A if the figure's job is "show the linear sequence". Pick B if the figure's job is
"show the through-line the reader should follow." Don't mix.

---

## Static chart — `chart.js` bar/line

Load chart.js from CDN at point of use. Bar and line only. Use tokens for axis and bar fill —
default to `var(--ink)` for primary series, `var(--primary)` only when contrasting with a second
series.

```html
<div class="card">
  <h3>Throughput</h3>
  <canvas id="c1" height="200"></canvas>
</div>
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<script>
new Chart(document.getElementById('c1'), {
  type: 'bar',
  data: { labels: [...], datasets: [{ data: [...], backgroundColor: '#161616' }] },
  options: { plugins: { legend: { display: false } } }
});
</script>
```

**Reach for it when:** ≤30 numeric points, bar or line is the right shape.
**Avoid when:** networks, hierarchies, geographic — return to table or hand-positioned SVG.

---

## Hero band — `.hero` + `.hero-inner`

Top of the document. White canvas (no gradient mesh), 1px bottom rule, light-weight Plex Sans
title at 60px / weight 300 / -0.4px tracking (IBM signature). Carries the eyebrow (mono,
slash-prefixed, no period), the title (sentence-case, **no trailing period**, ≤80 chars), the
lead (20px / 400), and a meta strip with vertical-rule separators.

```html
<section class="hero">
  <div class="hero-inner">
    <p class="hero-eyebrow">// CATEGORY / SUBTYPE / topic</p>
    <h1 class="hero-title">Sentence-case headline with no trailing period</h1>
    <p class="hero-lead">One or two lines of supporting copy.</p>
    <div class="hero-meta">
      <span><b>Author</b> name</span>
      <span><b>Project</b> hukuhaka-claude</span>
      <span><b>Date</b> 2026-05-18</span>
    </div>
  </div>
</section>
```

**Reach for it when:** every report. Once per document.
**Avoid when:** never — the hero is mandatory.

---

## Button — `.btn` and variants

Square corners, 14px Plex Sans 400, sentence-case label (no trailing period). Carbon's
button-type field maps to a class:

| Class | Use |
|---|---|
| `.btn-primary` | The primary action of a section or document. Solid IBM Blue (`var(--primary)`), white text. Max **one per section**. |
| `.btn-secondary` | A peer action that is not the recommended path. Solid `var(--ink)` (charcoal), white text. |
| `.btn-tertiary` | A less-prominent action. Transparent fill, 1px `var(--primary)` border, `var(--primary)` text. |
| `.btn-danger` | A destructive action (delete, discard). Solid `var(--semantic-error)` (red), white text. Confirms before firing. |
| `.btn-ghost` | An icon-or-text action that lives inside another container. No border, `var(--primary)` text on hover. |

Modifier sizes (compose with any variant): `.btn-sm` (32px height), default (40px), `.btn-lg`
(48px). Reports rarely use anything but the default.

```html
<a class="btn btn-primary" href="/get-started">Get started</a>
<a class="btn btn-secondary" href="/docs">Read the docs</a>
<button class="btn btn-tertiary" type="button">Compare alternatives</button>
<button class="btn btn-danger" type="button">Delete this report</button>
```

**Reach for it when:** the report needs a call-to-action (link to live page, github,
deploy script). Reports skew read-only — buttons should be rare. Two CTAs max per document.
**Avoid when:** the action is "open this file in your editor" — that's a code path, not a
button. Use `<code>` instead.

---

## Input — `.input-field`

Single-line text input. Surface-1 fill, 1px hairline border (bottom 2px on focus to follow
the Carbon style). Used in reports for inline search boxes (e.g., "filter the table below"
when paired with a tiny JS snippet) or for static "this is what the input looks like" demos.

```html
<label class="input-label">Search builds</label>
<input class="input-field" type="text" placeholder="commit sha, branch, author" />
<p class="input-helper">Searches across the last 30 days of CI logs.</p>
```

The label uses `<label class="input-label">` (12px mono caption above the field) and the
helper text uses `<p class="input-helper">` (12px sans below, ink-muted). Errors swap helper
to red and the field border to `var(--semantic-error)`.

**Reach for it when:** showing input UI in a design walkthrough or annotating a real
search/filter element on the page.
**Avoid when:** the report doesn't have any UI interaction — don't add an input "just for
completeness." Reports are static documents.

---

## Tab bar — `.tab-bar` + `.tab`

Up to four mutually exclusive views at the top of a section. Bottom-border-only — Carbon
tabs do not have backgrounds. The active tab gets a 3px `var(--primary)` bottom border;
inactive tabs are ink-muted.

```html
<div class="tab-bar" role="tablist">
  <button class="tab is-active" role="tab" aria-selected="true">Overview</button>
  <button class="tab" role="tab" aria-selected="false">Methodology</button>
  <button class="tab" role="tab" aria-selected="false">Results</button>
  <button class="tab" role="tab" aria-selected="false">Discussion</button>
</div>
```

In a static HTML report, "tab" usually means showing four sections in sequence rather than
behind a JS switcher. If the report genuinely needs a switcher, hand-roll it with
`<details>`/`<summary>` instead — it's a 4-line implementation and degrades gracefully.

**Reach for it when:** a visual mockup, design walkthrough, or annotation of a real tab UI
elsewhere in the product.
**Avoid when:** trying to hide content from a static report behind tabs to make it "feel
shorter." Reports are top-to-bottom artefacts — don't fight that.

---

## TOC active state — `.toc-list a[aria-current] | :target`

When the user clicks a TOC entry or jumps to an anchor, the active item should be visually
marked. tokens.css handles this with two selectors:

- `.toc-list a:target` — applies when the URL has a fragment matching the link's `href`
  (works on click and on direct-URL load).
- `.toc-list a[aria-current="location"]` — applies when JS (optional, scroll-spy) sets this
  attribute as the reader scrolls past each section.

Both render the same way: ink (not ink-muted), 600 weight, a 2px `var(--primary)` left
accent. Inactive items stay 14/400 ink-muted.

No HTML change needed in the report itself — the styles activate automatically based on URL
fragment. If you want scroll-spy, add a tiny IntersectionObserver script at the bottom of
the document; otherwise click-only activation is fine.

---

## What is NOT in the catalog (and why)

- **Gradients of any kind** (atmospheric mesh, nav-mark, button hover). Carbon depth = surface
  change + 1px hairline. Gradients flatten the system.
- **Drop shadows.** Same reason. Cards lift via surface change to `surface-1`, not via shadow.
- **Rounded corners.** Carbon is 0px on every component. Even 4px rounding reads as a different
  brand.
- **Pill buttons** (`border-radius: 100px`). Carbon uses square corners — pills belong to a
  different design language.
- **react-flow / mermaid / dagre / cytoscape / D3 force** — any auto-layout engine. The flowmap
  plugin failed for this exact reason. Permanently out of scope.
- **Tab switcher / accordion / collapse / scroll-spy.** Reports are top-to-bottom artefacts in
  v1. If a repeated need emerges, reconsider with `<details>`.
- **Search box, filter UI, sort controls.** Runtime interaction. Reports are static.
- **Embedded video, animated SVG, hover-lift transforms.** Distraction; Carbon is engineered,
  not stylized.
- **Custom font weights beyond 300 / 400 / 600.** Carbon caps display at 300 (signature
  light-weight treatment); body at 400; emphasis at 600.
- **Second chromatic accent beyond IBM Blue.** Semantic green / yellow / red exist for status
  only — never as decoration.
