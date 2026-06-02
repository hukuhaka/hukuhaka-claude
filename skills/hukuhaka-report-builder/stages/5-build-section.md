---
stage: 5
purpose: build ONE section at a time, render, verify, then proceed to next
prereq: Stage 4 cover.html locked at .claude/reports/<short-name>/cover.html
deliverable: per-section page appended to .claude/reports/<short-name>/report.html, screenshotted, user-approved
verification_gate: per section, user confirms scan-deliverability before next section
---

## What this stage does

Reports drift section-by-section. Verify each section before building the next. Catching a chart problem on section 3 is cheaper than catching it after sections 4-7 inherit the same problem.

## Required reading (per section)

- `.claude/reports/<short-name>/spec.md` (re-read at the START of each section loop — Outline anchor for THIS section binds the build; Preflight axes 9-12 (brand layer / disclaimer / versioning / TOC) bind body-page chrome (footer band, header strip, page numbering) on every page, not only the cover)
- `references/craft/registers/register-<stage-1-register>.md` (when this file exists; defer to common craft otherwise — register lock files build out in later phase)
- `references/craft/<craft-relevant-to-this-section>.md` — at minimum:
  - `charts.md` if the section has a chart
  - `tables.md` if the section has a table
  - `kpi-tiles.md` if the section has a KPI / hero number
  - `diagrams.md` if the section has a diagram
  - `callouts.md` if the section uses a sidebar / margin / highlight
  - `code-blocks.md` if the section has code

## Process per section (loop)

For section i in spec.md Outline:

1. Re-read spec.md. Pull Outline anchor + section title for section i.
2. Build section-i HTML — this section only, NOT the whole report.
3. Append to `.claude/reports/<short-name>/report.html` OR render standalone first.
4. Screenshot section-i in the browser (Playwright or user-opened). Save to `.claude/reports/<short-name>/screenshots/p<i>.png`.
5. Show user, ask:
   - "Does the anchor read at scan speed?"
   - "Does the section title earn the claim?"
   - "Is the density OK (not gray-wall, not empty)?"
6. If OK → append `Stage 5 / P<i>: built + verified <date>` to spec.md Build log → next section.
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
- Adopting craft library defaults (rainbow chart palette, Tailwind slate ramp) — re-read the cited craft file if so
- Skipping the spec.md re-read at the loop start (drift on register/palette/density across sections is exactly what spec.md prevents)
