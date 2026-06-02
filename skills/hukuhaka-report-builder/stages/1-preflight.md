---
stage: 1
purpose: lock the report's format spec (6 required + 6 recommended axes) BEFORE any layout starts
prereq: user has provided source material + (optional) audience hint
deliverable: spec.md created at .claude/reports/<short-name>/spec.md with Preflight block filled
verification_gate: user confirms each axis (or accepts proposed defaults) in chat
---

## What this stage does

Preflight is a single decision *with twelve axes*. Picking a register is one of those axes, not all of them. Page width, orientation, page unit, color mode, print mode, count, language, brand layer, disclaimer, versioning, TOC — every one of these is hard to change after Stage 4 begins. Lock them here.

The user does not have to *know* each axis. The skill proposes a default per axis based on input cues; the user accepts or overrides.

## Required reading

- `references/spec-schema.md` — full Preflight block structure (this stage produces it)

## Process

1. Read user input. Extract:
   - subject domain (code / metrics / incident / academic / IR)
   - audience (executive / engineer / regulator / customer / oncall / board)
   - artifact form hint (deck / PDF / web / print)
   - any explicit format hint (e.g., "make a 16:9 deck", "long-scroll web page")

2. Propose a default for each of the 6 required axes. Mark each axis with the recommendation + 1-line rationale, ask user to confirm or override:

   | # | Axis | Options |
   |---|---|---|
   | 1 | page format | A4 794×1123 / Letter 816×1056 / 16:9 1280×720 / square 1080 / freeform |
   | 2 | orientation | portrait / landscape |
   | 3 | page unit | **multi-page-deck** (only v1 option) — `long-scroll` and `tabbed` are listed as `[DEFERRED]` and cannot be selected; craft assets only support deck |
   | 4 | color mode | light / dark / both |
   | 5 | print mode | print-ready / web-only |
   | 6 | register | analytic-dashboard / executive-brief / technical-audit / ir-deck / academic-poster / forensic-incident (status-update / research-recap / customer-facing-release-notes available but DEFERRED) |

3. Propose a default for each of the 6 recommended axes, ask user to confirm or override:

   | # | Axis | Options |
   |---|---|---|
   | 7 | count | 1 / 3-4 / 5-7 / 8-12+ |
   | 8 | language | en / ko / mixed |
   | 9 | brand layer | none / wordmark / logo / watermark |
   | 10 | disclaimer policy | none / standard / ir-mandated / confidential / audit-trail |
   | 11 | versioning surface | none / date / version / author+date |
   | 12 | TOC | none / cover-strip / dedicated-page |

4. Surface the auto-derived and deferred axes from `spec-schema.md` to the user as **read-only** information — do not ask, but make visible:
   - Auto: visual hierarchy depth, asset budget, page numbering, 8-tier spacing, gap ratio
   - Deferred: accessibility, interactivity, distribution medium, cover treatment variation

5. After user confirms or overrides:
   - Pick a temporary `<short-name>` placeholder (Stage 2 finalizes it from SUBJECT) — use `tmp-<register>` for now
   - Create `.claude/reports/<short-name>/` directory
   - Create `.claude/reports/<short-name>/spec.md` per `references/spec-schema.md` template, filling Preflight block, leaving Stage 2-6 blocks as `<TBD>`

## Output (commit before Stage 2)

```
SPEC: .claude/reports/<short-name>/spec.md created
PREFLIGHT BLOCK:
  page format: <X>
  orientation: <X>
  page unit: multi-page-deck
  color mode: <X>
  print mode: <X>
  register: <X>
  count: <X>
  language: <X>
  brand layer: <X>
  disclaimer policy: <X>
  versioning surface: <X>
  TOC: <X>
```

## Verification gate

User says "OK" or proposes per-axis overrides. Iterate until all 12 axes acknowledged. Do NOT proceed to Stage 2 until spec.md Preflight block is committed to disk.

## Failure modes to refuse

- Picking a register without surfacing the other 11 axes (regresses to v0 stage 1)
- Selecting `long-scroll` or `tabbed` for page unit — craft assets do not support these in v1
- Selecting `status-update` / `research-recap` / `customer-facing-release-notes` register without flagging it lacks a lock file
- Blending two registers (e.g., "audit-brief hybrid") — pick one or split into two reports
- Skipping the disk write — spec.md must exist before Stage 2 so later stages can re-read it for drift control
