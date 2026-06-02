---
source: figma marketing site
applicability: mixed — the monochrome system (Black/White/Hairline/Ink) and the
  semantic role pattern transfer to any register. The pastel color-block palette
  is marketing-specific narrative scaffolding and does NOT belong in data reports,
  briefs, or dashboards (it reads as decorative rather than informational).
transferable:
  - Monochrome chrome (Black primary, White canvas, Hairline borders)
  - Ink / Inverse-Ink role split (no mid-gray text — weight carries hierarchy)
  - Single saturated promo accent (one per page max — the "magenta promo" pattern)
  - Hairline-vs-Hairline-Soft layering for divider hierarchy
non_transferable:
  - Block Lime / Lilac / Cream / Mint / Pink / Coral / Navy — these are marketing
    storytelling panels, not data-color tokens. Mining them for a data report
    makes the report read as marketing.
---

## Colors

> Source pages: figma.com (home), /design/, /figjam/brainstorming-tool/, /pricing/, /contact/.

### Brand & Accent

- **Black** ({colors.primary}): The system primary. Every primary CTA, every headline, every body line, the marquee strip, the inverse canvas of dark sections.
- **White** ({colors.on-primary}): Inverse text on black surfaces; also the canvas color used as the foreground of secondary pill buttons (`{components.button-secondary}`).
- **Magenta Promo** ({colors.accent-magenta}): A single saturated CTA pink reserved for promotional inline buttons — appears, for example, on the lilac "Save your spot" Release Notes banner. Use scarcely; it is not a section color.

### Surface

- **Canvas** ({colors.canvas}): Default page background and the body of every white card.
- **Inverse Canvas** ({colors.inverse-canvas}): Footer, marquee strip, and a subset of "ship products"-style story sections.
- **Surface Soft** ({colors.surface-soft}): Off-white tile background used for icon buttons, template cards, and feature illustration tiles when they sit on the white canvas.
- **Hairline** ({colors.hairline}): 1px borders on form inputs, pricing cards, and table dividers.
- **Hairline Soft** ({colors.hairline-soft}): Even subtler dividers — comparison-table row separators and footer column rules.
- **Block Lime** ({colors.block-lime}): The signature **systems / FAQ / contact-form** color block. Recurs across home, pricing, contact. *[MARKETING-ONLY]*
- **Block Lilac** ({colors.block-lilac}): Hero block on `/design/`; also the inline Release Notes promo banner. *[MARKETING-ONLY]*
- **Block Cream** ({colors.block-cream}): Soft warm background — FigJam hero strip, template-grid section. *[MARKETING-ONLY]*
- **Block Mint** ({colors.block-mint}): FigJam pastel section. *[MARKETING-ONLY]*
- **Block Pink** ({colors.block-pink}): FigJam pastel section. *[MARKETING-ONLY]*
- **Block Coral** ({colors.block-coral}): "Ship products" coral story block on home. *[MARKETING-ONLY]*
- **Block Navy** ({colors.block-navy}): Deep indigo story block — only place dark surfaces appear above the footer. *[MARKETING-ONLY]*

### Text

- **Ink** ({colors.ink}): All headline, body, and caption type on light surfaces. There is no softer mid-gray text role on marketing — body copy is always black at weight 320–340, and weight (not opacity) carries the hierarchy.
- **Inverse Ink** ({colors.inverse-ink}): Type on inverse-canvas surfaces (footer, marquee strip, navy color block).
- **On-Inverse Soft** ({colors.on-inverse-soft}): White used at ~16% opacity for circular icon-button surfaces against dark sections (token captures the base color; the translucency is applied at render time).

### Semantic

- **Success Green** ({colors.semantic-success}): Comparison-table checkmarks on pricing. Used as a glyph fill, not a surface.
- **Overlay Scrim** ({colors.overlay-scrim}): Black used at ~60% opacity behind modal / video-overlay surfaces (token captures the base; opacity applied at render time).
