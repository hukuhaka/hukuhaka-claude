---
stage: 1
purpose: ground the Stage-0 framings in a deeper look, pick the register (judgment), derive the other 11 axes deterministically, render a register-identity seed, and lock all 12 in one receipt
prereq: Stage 0 Intake block committed in .claude/reports/tmp-draft/spec.md
deliverable: spec.md overwritten (full-file Write) with Intake carried forward + filled Preflight; a partial cover.html seed rendered + screenshotted
verification_gate: user approves the RECEIPT — the 12-axis checklist + register + the rendered seed; FAIL CLOSED on any unrecorded axis
---

## What this stage does

Stage 1 is **one judgment pick (register) + deterministic derivation of everything else**,
surfaced as a single *rendered* receipt. The Stage-0 framings (subject material / audience /
publication) are the inputs; Stage 1 reads the target deeper, picks the register, fills the
12 axes, and shows the user what the artifact will look like — a real partial cover — before
any section is built.

**Determinism-split — the load-bearing rule of this stage:**

- **Mechanical axes (9)** — the 7 register-default axes (#1 #2 #3 #5 #10 #11 #12) + the 2
  kit-default axes (#4 #9). These are **table/kit-derived and recorded silently**. Same input
  → same value, every run. Do NOT turn them into pros/cons questions — that re-improvises the
  layer the pinned-kit architecture exists to make deterministic.
- **Judgment pick (1)** — the **register** (#6). This is the one taste-bound choice: propose
  it with a 1-line rationale + alternatives. When the framings make it unambiguous
  (table-derivable), just pick it and record it. "Confident → auto-decide" means
  *table-derivable*, not gut.
- **register↔kit invariant** — picking a register MUST NOT alter any kit token. A
  register-keyed accent ("audit = ochre") is invention, not capture. The kit is fixed.

The 12 axes are NOT gone — every axis is still written to spec.md with a provenance tag
(`kit-default` / `register-default` / `user`), so nothing is silently dropped.

## Required reading

- `.claude/reports/tmp-draft/spec.md` — the Stage-0 Intake block (re-read at stage start; the 3 framings drive register inference)
- `references/spec-schema.md` — Preflight block structure + provenance/gate rules (this stage produces it)
- `references/foundations/<kit>.css` — its two `@kit-*` declaration lines (feeds axes #4, #9)
- `references/components/cover.html` + `references/components/_base.css` — the seed render assembles from these
- `references/craft/cover.md` — the 1/3 scale rule (build-time judgment for the seed)

## Process

1. **Re-read the Intake block.** Pull the 3 framings — they are the register-inference input.

2. **Deeper investigation, grounded in the framings.** Read the actual target (the code /
   data / findings the report is about) enough to know what it contains and what claims it
   can support. Confirm named entities you may cite later (commands, files, counts) against
   source — memory is not verification. This is the deep look Stage 0 deferred.

3. **Pick kit.** v1 ships one: `geist` (`references/foundations/geist.css`). Record
   `kit: geist`. The kit pins type families, full palette, spacing, radii, elevation — and is
   fixed regardless of the register picked next (register↔kit invariant).

4. **Read kit declarations** from the kit header:
   - `@kit-color-mode:` → axis #4 color mode `[provenance: kit-default]`
   - `@kit-brand:` → axis #9 brand layer `[provenance: kit-default]`

5. **Pick register (#6, JUDGMENT, `[provenance: user]`).** From the framings (subject domain /
   audience / publication form), propose one register + a 1-line rationale. Name 1-2
   alternatives only where the choice is genuinely open; if the framings make it unambiguous,
   pick it and say so. Options: *analytic-dashboard / executive-brief / technical-audit /
   ir-deck / academic-poster / forensic-incident* (deferred: status-update / research-recap /
   customer-facing-release-notes — flag they lack a lock file if requested).

6. **Derive the 9 mechanical axes — silently.** The 7 register-default axes from the table
   below `[provenance: register-default]`; the 2 kit-default axes from step 4. Do not
   deliberate these aloud.

7. **Fill the last two:** axis #8 language — infer from the conversation `[provenance: user]`;
   axis #7 count — register default from the table (`register-default`, flips to `user` only
   if adjusted).

8. **Overwrite spec.md (full-file Write — NOT an Edit-append).** Carry the `## Intake` block
   forward + write the filled `## Preflight` block (all 12 axes with values + provenance tags;
   Stage 2-6 blocks as `<TBD>`). **It must be a `Write` of the whole file** — the spec-lock
   hook validates the complete 12-axis block at this write (an Edit-append would slip past the
   check). This is a DRAFT: the receipt gate confirms it, and a loop-back rewrites it.

9. **Render the register-identity SEED** as `.claude/reports/tmp-draft/cover.html`. Assemble a
   *partial* cover from `components/cover.html`: real kit CSS (fonts/palette) + register chrome
   (`.k` eyebrow from the register, `.meta` strip) + a **provisional** wordmark drawn from the
   Stage-0 subject framing. Do NOT write a finalized Subject or tagline — those lock in Stage 2
   and pour into this same seed at Stage 3. Obey the 1/3 scale rule (`craft/cover.md`).
   Screenshot to `.claude/reports/tmp-draft/screenshots/p1-seed.png`. (The hook permits this
   write because step 8 already put a complete Preflight on disk.)

10. **Show the RECEIPT and gate** (see wording below): the 12-axis checklist + the register +
    the rendered seed screenshot. The seed is the *visual* gate — the user sees the register
    identity, not just a text table.

## Register-defaults table

The single source for the 7 register-default axes. Cell values are the **verbatim option
strings** from `references/spec-schema.md` — downstream stages apply them literally.

| Register | #1 page format | #2 orientation | #5 print mode | #10 disclaimer policy | #11 versioning surface | #12 TOC | #7 count |
|---|---|---|---|---|---|---|---|
| analytic-dashboard | freeform | landscape | web-only | none | date | none | 1 |
| executive-brief | A4 794×1123 | portrait | print-ready | none ⚠ | author+date | none | 3-4 |
| technical-audit | A4 794×1123 | portrait | print-ready | audit-trail | author+date | cover-strip | 5-7 |
| ir-deck | 16:9 1280×720 | landscape | web-only | ir-mandated | version | cover-strip | 8-12+ |
| academic-poster | freeform ⚠ | landscape ⚠ | print-ready | none | author+date | none | 1 |
| forensic-incident | A4 794×1123 | portrait | print-ready | confidential ⚠ | author+date | none | 5-7 |

Notes:

- **#3 page unit = `multi-page-deck` for all six** (v1-fixed). Dashboard and poster are
  single-surface via `count: 1`, not a page-unit change.
- **freeform dimensions**: poster = one sheet at A1/A0 ratio; dashboard = one wide surface
  (~1440px). State the chosen dimension in the checklist value.
- ⚠ flagged defaults (genuinely ambiguous — picked, with rationale):
  - **executive-brief disclaimer `none`** — brief is minimal-chrome by craft; add
    `standard`/`confidential` only on user override.
  - **academic-poster page format `freeform`** — the option list has no sheet size; freeform +
    A1/A0 ratio is the convention, do not invent new options.
  - **academic-poster orientation `landscape`** — conference posters split both ways;
    landscape is the more common default.
  - **forensic-incident disclaimer `confidential`** — incidents are sensitive by default;
    `audit-trail` is for formal audit artifacts.
- Defensible leans (one-liners): ir-deck print mode `web-only` (decks are screen-first; print
  is an export), ir-deck TOC `cover-strip` (agenda strip is IR convention), forensic-incident
  print mode `print-ready` (incident reports get filed), forensic-incident TOC `none`
  (timeline carries the navigation).

## Receipt gate

Show the filled 12-axis checklist + the rendered seed screenshot, then ask exactly one question:

> **Confirm all 12 + the register identity, or override any axis in one line** (e.g.
> `count: 8-12+`, `language: en`, `register: executive-brief`).

Checklist shape:

```
KIT: geist (pins: fonts, palette, spacing, radii, elevation — fixed regardless of register)
SEED: screenshots/p1-seed.png  ← does this read as <register> in 3 seconds?
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

- On confirm → proceed to Stage 2.
- On override → flip that axis's provenance to `user`, **rewrite spec.md (full-file Write —
  Case A re-validates)**, re-render the seed, re-show the receipt.
- **Refuse** an override of a kit-default axis to a value the kit does not declare: geist
  declares `@kit-color-mode: light` only — `dark` requires a separate kit file, not a Stage-1
  toggle. Brand-layer overrides are fine (additive chrome).
- **FAIL CLOSED**: if any of the 12 axes is missing a value OR a provenance tag, Stage 1
  cannot pass — the spec-lock hook denies the write. The provenance tag records the value's
  SOURCE, not the confirmation: confirming the receipt does not flip axes to `user`.

## Output (commit before Stage 2)

```
SPEC: .claude/reports/tmp-draft/spec.md overwritten (Intake + Preflight)
KIT: geist
PREFLIGHT: 12/12 axes recorded — N kit-default · N register-default · N user
SEED: .claude/reports/tmp-draft/cover.html + screenshots/p1-seed.png (inherited by Stage 3)
```

## v1 restrictions (carried from the 12-axis preflight era)

- page unit: **multi-page-deck** is the only v1 option — `long-scroll` and `tabbed` are
  `[DEFERRED]` and cannot be selected; craft assets only support deck
- registers `status-update` / `research-recap` / `customer-facing-release-notes` are available
  but DEFERRED — flag that they lack a lock file if requested
- no register blending (e.g., "audit-brief hybrid") — pick one or split into two reports

## Failure modes to refuse

- **Turning a mechanical axis into a per-report decision** — deliberating page-format /
  print-mode / TOC as pros/cons. They are table-derived; only the register is a judgment pick.
- **Letting the register alter a kit token** — register↔kit invariant; the kit is fixed.
- Recording register and skipping the other 11 axes (every axis gets a value + provenance tag)
- Passing the gate with an unrecorded axis — FAIL CLOSED, the hook denies the write
- **Appending the Preflight via Edit instead of a full-file Write** — the hook's content check
  fires only on a Write; an Edit-append slips the 12-axis validation
- Rendering the seed with a finalized Subject/tagline — those are Stage 2; the seed uses a
  provisional wordmark only
- Overriding color mode to a value absent from the kit's `@kit-color-mode`
- Selecting `long-scroll` / `tabbed` for page unit, or a DEFERRED register without flagging it
- Blending two registers — pick one or split into two reports
- Skipping the disk write or the seed render — later stages re-read spec.md and Stage 3
  inherits the seed
