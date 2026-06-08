---
applicability: report-builder skill — hero numbers, KPI tiles, stat cards, oversized metrics
read_when: authoring or extending a component fragment (references/components/); during report builds only for judgment rules fragments cannot carry — density / per-register choice (Stages 4-5)
---

## Hero number scale

Every section, ideally every page, has at least one number large enough to be legible from across a room — the page-defining metric. If your page has no hero number, the page has no spine.

Size ladder:

| Role | size | weight |
|---|---|---|
| Cover wordmark (subordinated, see `craft/cover.md`) | 32-48px | 700-800 |
| In-report hero (page-defining metric) | 96-140px | 700-800 |
| Sub-hero / secondary KPI | 56-72px | 600-700 |
| Tile metric (within KPI strip) | 36-44px | 600 |
| Inline metric (in prose) | body size | 500-600 |

**Tabular-nums always** (`font-variant-numeric: tabular-nums`). Proportional digits in metric content read as careless and misalign in grids.

Decoration on a hero number weakens it. Let weight, scale, and contrast do the work — no shadow, no gradient, no icon-background, no bg tint.

## Tile structure

A KPI tile has 4 elements, in order top-to-bottom:

1. **Label** — eyebrow, mono uppercase tracked +0.04em, smaller than body (12-14px)
2. **Metric** — oversized number (see ladder), tabular-nums
3. **Unit / suffix** — smaller mono, baseline-aligned, dimmed (`oklch(50% 0 0)`)
4. **Delta** (optional) — small inline with semantic gain/loss color + arrow glyph

Tile-padding: `--space-3` to `--space-4` per side. Tile-grid gap: `--space-3` to `--space-5`. No tile-shadow, no tile-border + tile-bg simultaneously — pick at most one.

## Unit placement

- Currency / percent: postfix at 0.5-0.65× metric size, dimmed
- Per-unit ("per request", "per day"): smaller mono postfix at 0.4× size
- Time units (ms, s): postfix, same treatment as currency
- Multi-unit values ($2.3B): treat `$` + `B` as separate sub-units, both dimmed at 0.6× of "2.3"

## Per-register usage

- **Dashboard**: KPI strip top, 3-6 tiles, hero number per tile
- **IR-deck**: 1-2 hero numbers per slide, no tile grid
- **Brief**: at most 1 hero number on TL;DR, supporting metrics inline
- **Audit**: hero number for the lead finding only — overuse dilutes
- **Poster**: hero numbers as section anchors, large but contained
- **Incident**: severity score, MTTR, blast-radius % — as small dense strip

## Anti-defaults

- KPI tile with 4 elements crammed into one line — illegible
- Number in same weight as body (e.g., 400) — fails the across-the-room test
- Icon to the left of every KPI — chart-junk; the number is the icon
- Rounded card with shadow + border + bg color — generic AI-doc; pick at most one of bg-tint OR border
- Centered number with massive padding — wastes the tile, reads as empty
- Same-size KPIs in a grid where one is THE finding — weight the hero, demote the rest

## Common failure modes

- **Proportional digits** in grid — columns misalign
- **All KPIs same weight** — eye has no anchor
- **Delta arrow without semantic color** — direction unclear at scan
- **2×2 KPI block on cover** (see `craft/cover.md`) — cover identity dissolves
- **Hero number not the largest element on the page** — page hierarchy unclear
