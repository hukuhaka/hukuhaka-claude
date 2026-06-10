---
stage: 4
purpose: build ONE section at a time from component fragments, render, verify, then proceed to next
prereq: Stage 3 cover.html locked at .claude/reports/<short-name>/cover.html
deliverable: per-section page appended to .claude/reports/<short-name>/report.html, screenshotted, user-approved
verification_gate: per section, user confirms scan-deliverability before next section
---

## What this stage does

Reports drift section-by-section. Verify each section before building the next. Catching a chart problem on section 3 is cheaper than catching it after sections 4-7 inherit the same problem.

## Required reading (per section)

- `.claude/reports/<short-name>/spec.md` (re-read at the START of each section loop — Outline anchor for THIS section binds the build; Preflight axes 9-12 (brand layer / disclaimer / versioning / TOC) bind body-page chrome (footer band, header strip, page numbering) on every page, not only the cover)
- `references/components/<fragments matching this section's anchor>` — the fragment IS the rules; its header comments carry intent / swap / keep / needs. At minimum:
  - `chart-bar.html` / `chart-line.html` / `chart-stacked.html` if the section has a chart — the section's MESSAGE picks the fragment (RANKING → bar, CHANGE-OVER-TIME → line, PART-TO-WHOLE → stacked; each fragment's header comment says so)
  - `data-table.html` if the section has a table
  - `kpi-tiles.html` / `hero-metric.html` if the section has a KPI / hero number
  - `diagram.html` if the section has a diagram (SVG content is hand-authored per report; conventions in the fragment)
  - `callout-side.html` / `callout-highlight.html` / `margin-note.html` if the section uses a sidebar / margin / highlight
  - `code-block.html` if the section has code
  - `section-head.html` / `badges.html` / `source-line.html` as the section needs them
- `references/craft/<file>.md` — build-time judgment ONLY, per each file's `read_when` scope:
  - `charts.md` for axis / annotation judgment (which inflection to annotate, when a legend earns its place)
  - `tables.md` for density judgment
  - `spacing.md` for density / scan-rhythm pacing across pages

## Process per section (loop)

For section i in spec.md Outline:

1. Re-read spec.md. Pull Outline anchor + section title for section i.
2. Assemble section-i HTML from the matching fragments — copy fragment markup, pour this section's content. Do not restyle fragments; do not write non-token CSS. This section only, NOT the whole report.
3. Append to `.claude/reports/<short-name>/report.html` OR render standalone first.
4. Screenshot section-i in the browser. Save to `.claude/reports/<short-name>/screenshots/p<i>.png`.
5. Show user, ask:
   - "Does the anchor read at scan speed?"
   - "Does the section title earn the claim?"
   - "Is the density OK (not gray-wall, not empty)?"
6. If OK → append `Stage 4 / P<i>: built + verified <date>` to spec.md Build log → next section.
7. If not OK → fix ONLY this section (Edit on the marker, not Write the whole file), re-verify.

## Output (per loop iteration)

- An appended page in `.claude/reports/<short-name>/report.html`
- A screenshot at `.claude/reports/<short-name>/screenshots/p<i>.png`
- A Build log line appended to `.claude/reports/<short-name>/spec.md`

## Verification gate (per section)

User confirms section-by-section. Do NOT batch 3+ sections without a verify in between — that is first-shot mode in disguise.

## Failure modes

- Building 2+ sections before verifying (loses the per-section catch)
- Re-generating the whole report when one section is off (use Edit on the marker / sub-range, not Write)
- Skipping the section anchor check (a section without a scan-deliverable element is essay-mode)
- Adopting craft library defaults (rainbow chart palette, Tailwind slate ramp) — re-bind to the fragment + kit tokens if so
- Skipping the spec.md re-read at the loop start (drift on register/palette/density across sections is exactly what spec.md prevents)
