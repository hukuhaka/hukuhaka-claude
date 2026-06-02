---
source: figma marketing site
applicability: mostly general — the 8px base unit, spacing token scale, and 96px
  section rhythm transfer to any register. The color-block-section grid-break
  (full-content-width pastel panels with rounded corners) is marketing-specific
  and does not belong in data reports.
transferable:
  - 8px base unit + xxs/xs/sm/md/lg/xl/xxl/section token scale
  - 1280px max content width, side gutters that scale with breakpoint
  - 96px `{spacing.section}` between major sections as a rhythm constant
  - Whitespace-as-deliberateness philosophy (let content breathe so each section reads as intentional)
non_transferable:
  - Color-block sections grid-breaking out of column grid
  - 1/4-block side margin inside pastel panels (marketing poster aesthetic)
---

## Layout

### Spacing System

- **Base unit**: 8px.
- **Tokens (front matter)**: `{spacing.hair}` 1px · `{spacing.xxs}` 4px · `{spacing.xs}` 8px · `{spacing.sm}` 12px · `{spacing.md}` 16px · `{spacing.lg}` 24px · `{spacing.xl}` 32px · `{spacing.xxl}` 48px · `{spacing.section}` 96px.
- Section interior padding: `{spacing.xxl}` (48px) on color-block sections.
- Card interior padding: `{spacing.lg}` (24px) on pricing cards and template tiles.
- Form input padding: `{spacing.sm}` 12px vertical · 14px horizontal.
- Button padding: `{spacing.xs}` 8px vertical · `{spacing.lg}` 24px horizontal for pill buttons (the asymmetric `8px 18px 10px` extracted on `button-secondary` nudges the type optically inside the pill).
- Universal rhythm constant: `{spacing.section}` (96px) — the vertical gap between major content sections holds across home, pricing, and FigJam pages.

### Grid & Container

- Max content width sits around 1280px (one of the explicit breakpoints), with side gutters that scale from `{spacing.xxl}` on desktop down to `{spacing.lg}` on mobile.
- Three- and four-column grids on the desktop pricing comparison and FigJam template galleries.
- Color-block sections break the column grid — they span content width with full bleed inside the rounded `{rounded.lg}` corners, then place a single editorial column of headline + body inside. *[MARKETING-ONLY]*

### Whitespace Philosophy

White space is used to make the color blocks feel deliberate. Between every colored panel and the next, the page returns to white canvas with `{spacing.section}` of breathing room. Inside a color block, the type itself is given generous side margins (often more than 1/4 of the block's width on each side) so the panel reads as a poster, not a wall of copy.

**Transferable principle**: regardless of whether you use color blocks, the "let sections breathe so each reads as intentional" rule transfers — generous whitespace between major content units is what makes density variations register as deliberate pacing rather than randomness.
