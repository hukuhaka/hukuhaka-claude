---
stage: 1
purpose: pick the kit + register, auto-derive the other 10 axes, lock all 12 in one batch confirm BEFORE any layout starts
prereq: user has provided source material + (optional) audience hint
deliverable: spec.md created at .claude/reports/<short-name>/spec.md with Preflight block filled — kit field + all 12 axes, each with a provenance tag
verification_gate: user batch-confirms the filled 12-axis checklist (or overrides any axis with one line); FAIL CLOSED if any axis is unrecorded
---

## What this stage does

Stage 1 is two picks, not twelve questions. Pick a **kit** (the foundation
file that pins fonts, palette, spacing) and a **register** (inferred from the
input, proposed for confirmation). Everything else — page format, orientation,
print mode, disclaimer, versioning, TOC, color mode, brand — derives
automatically from the kit's declarations and the register-defaults table
below. The user sees the **filled 12-axis checklist once** and confirms in one
reply, overriding any axis with a single line.

The 12 axes are NOT gone — absorption moves the *answering party*, not the
record. Every axis is still written to spec.md with a provenance tag
(`kit-default` / `register-default` / `user`), so nothing is silently dropped.

## Required reading

- `references/spec-schema.md` — Preflight block structure + provenance/gate rules (this stage produces it)
- `references/foundations/<kit>.css` — read its two `@kit-*` declaration lines (feeds axes #4, #9)

## Process

1. **Pick kit** — v1 ships one kit: `geist` (`references/foundations/geist.css`).
   Record `kit: geist`. Tell the user what the kit pins — and therefore what
   they will NOT be asked: type families (Geist / Geist Mono / Source Serif 4),
   full color palette, spacing scale, radii, elevation. Changing any of these
   means a different kit, not a per-report tweak.

2. **Read kit declarations** — from the kit file header:
   - `@kit-color-mode:` → axis #4 color mode `[provenance: kit-default]`
   - `@kit-brand:` → axis #9 brand layer `[provenance: kit-default]`

3. **Infer register** (axis #6, `[provenance: user]`) from input cues —
   subject domain (code / metrics / incident / academic / IR), audience
   (executive / engineer / regulator / customer / oncall / board), artifact
   form hint (deck / PDF / web / print). Propose with a 1-line rationale.

4. **Derive the 7 register-default axes** (#1 #2 #3 #5 #10 #11 #12,
   `[provenance: register-default]`) from the table below.

5. **Fill the last two**:
   - axis #8 language — infer from the conversation (`[provenance: user]`)
   - axis #7 count — register default from the table; stays
     `register-default` if accepted as derived, flips to `user` once adjusted

6. **Display the filled checklist once** — all 12 axes in this shape:

   ```
   KIT: geist (pins: fonts, palette, spacing, radii, elevation)
   #  axis                 value             provenance
   1  page format          A4 794×1123       register-default
   2  orientation          portrait          register-default
   3  page unit            multi-page-deck   register-default
   4  color mode           light             kit-default
   5  print mode           print-ready       register-default
   6  register             technical-audit   user
   7  count                5-7               register-default
   8  language             ko                user
   9  brand layer          none              kit-default
   10 disclaimer policy    audit-trail       register-default
   11 versioning surface   author+date       register-default
   12 TOC                  cover-strip       register-default
   ```

7. **Batch-confirm gate** (see wording below).

8. After confirmation:
   - Pick a temporary `<short-name>` placeholder (Stage 2 finalizes it from
     SUBJECT) — use `tmp-<register>` for now
   - Create `.claude/reports/<short-name>/` directory
   - Create `.claude/reports/<short-name>/spec.md` per
     `references/spec-schema.md` template — `kit:` field + Preflight block
     filled with values AND provenance tags, Stage 2-6 blocks as `<TBD>`

## Register-defaults table

The single source for the 7 register-default axes. Cell values are the
**verbatim option strings** from `references/spec-schema.md` — downstream
stages apply them literally.

| Register | #1 page format | #2 orientation | #5 print mode | #10 disclaimer policy | #11 versioning surface | #12 TOC | #7 count |
|---|---|---|---|---|---|---|---|
| analytic-dashboard | freeform | landscape | web-only | none | date | none | 1 |
| executive-brief | A4 794×1123 | portrait | print-ready | none ⚠ | author+date | none | 3-4 |
| technical-audit | A4 794×1123 | portrait | print-ready | audit-trail | author+date | cover-strip | 5-7 |
| ir-deck | 16:9 1280×720 | landscape | web-only | ir-mandated | version | cover-strip | 8-12+ |
| academic-poster | freeform ⚠ | landscape ⚠ | print-ready | none | author+date | none | 1 |
| forensic-incident | A4 794×1123 | portrait | print-ready | confidential ⚠ | author+date | none | 5-7 |

Notes:

- **#3 page unit = `multi-page-deck` for all six** (v1-fixed). Dashboard and
  poster are single-surface via `count: 1`, not a page-unit change.
- **freeform dimensions**: poster = one sheet at A1/A0 ratio; dashboard = one
  wide surface (~1440px). State the chosen dimension in the checklist value.
- ⚠ flagged defaults (genuinely ambiguous — picked, with rationale):
  - **executive-brief disclaimer `none`** — brief is minimal-chrome by craft;
    add `standard`/`confidential` only on user override.
  - **academic-poster page format `freeform`** — the option list has no sheet
    size; freeform + A1/A0 ratio is the convention, do not invent new options.
  - **academic-poster orientation `landscape`** — conference posters split
    both ways; landscape is the more common default.
  - **forensic-incident disclaimer `confidential`** — incidents are sensitive
    by default; `audit-trail` is for formal audit artifacts.
- Defensible leans (one-liners): ir-deck print mode `web-only` (decks are
  screen-first; print is an export), ir-deck TOC `cover-strip` (agenda strip
  is IR convention), forensic-incident print mode `print-ready` (incident
  reports get filed), forensic-incident TOC `none` (timeline carries the
  navigation).

## Batch-confirm gate

Display the filled checklist, then ask exactly one question:

> **Confirm all 12, or override any axis in one line** (e.g. `count: 8-12+`,
> `language: en`).

- On confirm → write spec.md, proceed to Stage 2.
- On override → flip that axis's provenance to `user`, re-display the
  checklist, re-confirm.
- **Refuse** an override of a kit-default axis to a value the kit does not
  declare: geist declares `@kit-color-mode: light` only — `dark` requires a
  separate kit file, not a Stage-1 toggle. Brand-layer overrides are fine
  (additive chrome).
- **FAIL CLOSED**: if any of the 12 axes is missing a value OR a provenance
  tag, Stage 1 cannot pass — do not write spec.md. The provenance tag records
  the value's SOURCE, not the confirmation: batch-confirm does not flip axes
  to `user`.

## Output (commit before Stage 2)

```
SPEC: .claude/reports/<short-name>/spec.md created
KIT: geist
PREFLIGHT: 12/12 axes recorded — N kit-default · N register-default · N user
```

## v1 restrictions (carried from the 12-axis preflight era)

- page unit: **multi-page-deck** is the only v1 option — `long-scroll` and
  `tabbed` are `[DEFERRED]` and cannot be selected; craft assets only support deck
- registers `status-update` / `research-recap` / `customer-facing-release-notes`
  are available but DEFERRED — flag that they lack a lock file if requested
- no register blending (e.g., "audit-brief hybrid") — pick one or split into
  two reports

## Failure modes to refuse

- Recording register and skipping the other 11 axes (the checklist exists so
  nothing is dropped — every axis gets a value + provenance tag)
- Passing the gate with an unrecorded axis — FAIL CLOSED, no spec.md
- Overriding color mode to a value absent from the kit's `@kit-color-mode`
- Re-interviewing the user axis-by-axis — that regresses to the 12-question
  preflight this stage replaced; one batch confirm, overrides by exception
- Selecting `long-scroll` or `tabbed` for page unit — craft assets do not
  support these in v1
- Selecting a DEFERRED register without flagging it lacks a lock file
- Blending two registers — pick one or split into two reports
- Skipping the disk write — spec.md must exist before Stage 2 so later stages
  can re-read it for drift control
