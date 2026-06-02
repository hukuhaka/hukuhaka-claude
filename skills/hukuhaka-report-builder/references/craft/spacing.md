---
applicability: report-builder skill — spacing scale, page margins, section gaps, vertical and scan rhythm
read_when: building any page; setting margins, gaps, or scan-rhythm pacing
---

## 8-tier scale

Use a single scale, never one-off values. All spacing in CSS resolves to one of:

| Tier | rem | px (16-base) | typical use |
|---|---|---|---|
| `--space-1` | 0.25 | 4 | inline gap, tight badge padding |
| `--space-2` | 0.5 | 8 | label-value gap, tile padding-y |
| `--space-3` | 0.75 | 12 | tile padding-x, table cell pad |
| `--space-4` | 1.0 | 16 | paragraph spacing, button padding |
| `--space-5` | 1.5 | 24 | section sub-block gap |
| `--space-6` | 2.0 | 32 | column gap, callout outer |
| `--space-7` | 3.0 | 48 | section gap |
| `--space-8` | 4.5 | 72 | page section break |

Off-scale values (37px, 52px, 19px) identify hand-tuning failure — pick the nearest tier.

## Page margins (per register, page-as-unit)

| Register | Horizontal | Vertical | Reason |
|---|---|---|---|
| **Audit / Brief** | 8% viewport | 6% viewport | reading comfort, prose-led |
| **Dashboard** | 2-3% all sides | (single surface) | maximize data surface |
| **IR-deck (16:9)** | 5% all sides | 5% all sides | slide breathing room |
| **Poster** | 3% all sides | 3% all sides | density wins |
| **Incident** | 6% horizontal | 5% vertical | timeline-led |

Print/PDF rendering: use mm-based margins for final export (e.g., 18mm horizontal on A4 audit).

## Vertical rhythm

- Body line-height: 1.45-1.55
- Headline line-height: 1.1-1.2 (display) or 1.25-1.35 (sub-display)
- Section gaps follow scale: between major sections `--space-7` or `--space-8`. Between sub-blocks within section `--space-5` or `--space-6`
- Section gap MUST be larger than paragraph gap by at least 2 tiers — otherwise sections dissolve

## Scan rhythm (density variation per page)

A scan-read artifact needs **density variation per page**:

- **Dense band**: data table, chart cluster, KPI strip — content packs vertically
- **Breathable band**: single hero number on a near-empty band, single one-line opener

Pages where every band is the same density read as uniform gray and the eye skips. Alternate deliberately — **at least one breathable band per page**.

The breathable band is not whitespace for whitespace's sake — it carries one element with high visual weight (oversized number, single sentence, prominent figure). Empty padding is decoration; weighted breath is content.

## Anti-defaults

- Tailwind default `space-y-4` everywhere — uniform rhythm = no scan path
- Off-scale ad-hoc values (37px, 52px) — visual jitter
- Equal padding all 4 sides on every container — kills hierarchy
- Section gap = paragraph gap — sections dissolve into prose
- Single space scale for type AND layout — mixing scales breaks rhythm

## Common failure modes

- **All padding-y same as padding-x** — square containers everywhere kill rhythm
- **No tier-7/8 in the page** — page reads as a single dense block
- **Tier-1/2 inside body prose** — text feels cramped
- **Margin-collapse not understood** — vertical gaps double-count or disappear under flex/grid
- **Edge-to-edge content on wide viewports** — long lines unreadable; cap measure (see `craft/typography.md`)
