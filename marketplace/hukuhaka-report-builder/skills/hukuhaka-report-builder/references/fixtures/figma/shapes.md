---
source: figma marketing site
applicability: general — the radius scale and shadow-light philosophy transfer
  across registers. Specific component shapes (pill-only CTAs) are marketing-bound
  but the underlying principle ("commit to one shape grammar") transfers.
transferable:
  - Radius token scale (xs/sm/md/lg/xl/pill/full) as a discipline
  - Shadow-light philosophy: substitute color contrast for drop shadows where possible
  - "One shape grammar per system" — pick a primary shape language and commit
non_transferable:
  - Pill being the ONLY button shape (marketing brand signature)
  - Sticky-note-style FigJam thumbnails with off-axis rotation (toy-like, marketing-specific)
---

## Elevation & Depth

| Level | Treatment | Use |
|---|---|---|
| 0 (flat) | No shadow, no border | Default for color-block sections, inverse-canvas footer, hero |
| 1 (hairline) | 1px `{colors.hairline}` border on `{colors.canvas}` | Pricing cards, form inputs, comparison table cells |
| 2 (soft elevation) | Subtle drop shadow approx 0 4px 16px rgba(0,0,0,0.06) | Floating template tiles, dropdown menus |
| 3 (modal) | Stronger shadow + `{colors.overlay-scrim}` behind | Video / image lightbox overlays |

Figma's marketing system is shadow-light by design — the color blocks substitute for traditional elevation. Where most SaaS sites use a shadowed white card to draw attention, Figma uses a saturated background panel. This makes the rare actual shadow (e.g., a floating template card hovering over a cream section) feel like an exception worth noticing.

**Transferable principle**: pick ONE depth device per system. If you commit to color-as-depth (Figma), keep shadows out. If you commit to shadows, do not also use heavy borders. Doubling depth devices reads as nervous design.

### Decorative Depth

- **Color-block sections** are the primary depth device. The change from white canvas to lime / lavender / cream is the section break. *[MARKETING-ONLY]*
- **Sticky-note style component thumbnails** in FigJam — slightly off-axis pastel rectangles arranged like notes on a board — read as collage, not card-stack. *[MARKETING-ONLY]*
- **Embedded product UI mocks** (Figma Design panels, FigJam canvas snippets) appear as flat compositions on color blocks; their internal shadows are subtle and stay within the mock.

## Border Radius Scale

| Token | Value | Use |
|---|---|---|
| `{rounded.xs}` | 2px | Anchor / link decoration corners |
| `{rounded.sm}` | 6px | Small chips, sub-nav tabs |
| `{rounded.md}` | 8px | Form inputs, list items, image frames |
| `{rounded.lg}` | 24px | Pricing cards, color-block sections, large image containers |
| `{rounded.xl}` | 32px | Hero feature panels, oversized callouts |
| `{rounded.pill}` | 50px | All text CTAs (primary, secondary, tab toggles) |
| `{rounded.full}` | 9999px | Circular icon buttons, comparison-table checkmark glyphs |

### Photography & Illustration Geometry

- Image frames use `{rounded.md}` (8px) — generous enough to feel friendly, conservative enough to read as editorial.
- Template thumbnails on the home grid sit in `{rounded.md}` tiles with `{spacing.md}` interior padding around the embedded preview.
- FigJam pastel sticky-note component thumbnails preserve a small `{rounded.sm}` corner that mimics actual sticky paper. *[MARKETING-ONLY]*
- No avatar circles appear in marketing surfaces — Figma's marketing avoids personification.
