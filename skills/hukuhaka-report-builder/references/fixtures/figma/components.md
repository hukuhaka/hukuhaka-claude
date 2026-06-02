---
source: figma marketing site
applicability: MARKETING-ONLY — every component documented here (pill CTAs, color-block
  sections, pricing tabs, promo banner, marquee strip, comparison checkmarks) is a
  marketing-site primitive. None of them belong in a data report, dashboard, or
  technical brief. SKIP this file unless your register is marketing, landing page,
  or product surface; otherwise it will pollute your design with brand decoration
  that has no informational role.
transferable_meta_patterns:
  - The discipline of giving every recurring component an explicit name + variant slot
  - The "primary = scarce, secondary = pair" pattern (apply to your own components)
  - "Selected state = primary surface, not a passive grey" — applies to any toggle
non_transferable: every concrete component below
---

## Components

### Buttons

**`button-primary`** — The black "Get started for free" pill that appears in the top nav, every hero, and every closing CTA.
- Background `{colors.primary}`, text `{colors.on-primary}`, type `{typography.button}`, padding 10px 20px, rounded `{rounded.pill}`.
- Pressed state lives in `button-primary-pressed` (same surface; the live site relies on micro-scale rather than a darkened fill).

**`button-secondary`** — White pill with black text. Used for tertiary navigation actions ("Contact sales") and as the visual counterpart to the primary pill.
- Background `{colors.canvas}`, text `{colors.ink}`, type `{typography.button}`, padding 8px 18px 10px (asymmetric vertical to optically center the type), rounded `{rounded.pill}`. No border.

**`button-tertiary-text`** — Plain text link styled as a button hit target inside top nav and footer.
- Background `{colors.canvas}`, text `{colors.ink}`, type `{typography.link}`, rounded `{rounded.full}` (hit target only), padding `{spacing.xs}` `{spacing.sm}`.

**`button-icon-circular`** — 40px circular icon button used for carousel controls, social links, and inline actions on light surfaces.
- Background `{colors.surface-soft}`, text `{colors.ink}`, rounded `{rounded.full}`, size 40px.

**`button-icon-circular-inverse`** — Same shape, used on inverse-canvas / dark color blocks.
- Background `{colors.on-inverse-soft}` (translucent white), text `{colors.inverse-ink}`, rounded `{rounded.full}`, size 40px.

**`button-magenta-promo`** — Saturated pink pill used only inside promotional surfaces such as the lilac "Save your spot" Release Notes banner. Reserved for moments where Figma's product team wants the CTA to pop against an already-colored panel.
- Background `{colors.accent-magenta}`, text `{colors.on-primary}`, type `{typography.button}`, rounded `{rounded.pill}`, padding 10px 18px.

### Pricing Tabs

**`pricing-tab-default`** + **`pricing-tab-selected`** — The pill-toggle that switches between Starter / Professional / Organization / Enterprise on `/pricing/`.
- Default: `{colors.canvas}` background, `{colors.ink}` text, rounded `{rounded.pill}`.
- Selected: `{colors.primary}` background, `{colors.on-primary}` text — exactly the same surface as `button-primary`, which makes the selected tab feel like an active CTA, not a passive state.

### Inputs & Forms

**`text-input`** + **`text-input-focused`** — Form fields on `/contact/` and pricing seat-count steppers.
- Background `{colors.canvas}`, text `{colors.ink}`, type `{typography.body}`, rounded `{rounded.md}`, padding 12px 14px.
- Focused state retains the same surface — focus is communicated via ring, not via fill change.

### Cards & Containers

**`pricing-card`** — Each tier on `/pricing/`.
- Background `{colors.canvas}`, text `{colors.ink}`, type `{typography.body}`, rounded `{rounded.lg}`, padding `{spacing.lg}`. Stroked with `{colors.hairline}` rather than shadowed.

**`pricing-card-feature-row`** — Single row inside the comparison table.
- Background `{colors.canvas}`, text `{colors.ink}`, type `{typography.body-sm}`. Row separator is `{colors.hairline-soft}`.

**`template-card`** — Thumbnail tile in the home "Explore what people are making" grid and the FigJam template gallery.
- Background `{colors.surface-soft}`, text `{colors.ink}`, type `{typography.body-sm}`, rounded `{rounded.md}`, padding `{spacing.md}`.

**`feature-illustration-tile`** — Larger composition tile that holds a product UI mock or pastel illustration.
- Background `{colors.surface-soft}`, text `{colors.ink}`, type `{typography.eyebrow}`, rounded `{rounded.md}`, padding `{spacing.lg}`.

### Color-Block Sections (signature)

The defining surface of Figma's marketing. Each is a full-content-width panel with `{rounded.lg}` corners and `{spacing.xxl}` interior padding. Variants:

**`color-block-section`** — lime ground for "systems" stories (home), pricing FAQ, and the contact form.
- Background `{colors.block-lime}`, text `{colors.ink}`, type `{typography.subhead}`, rounded `{rounded.lg}`, padding `{spacing.xxl}`.

**`color-block-section-lilac`** — lavender ground for `/design/` hero and FigJam highlight sections.
- Background `{colors.block-lilac}`, otherwise identical structure.

**`color-block-section-navy`** — deep indigo ground for the home "Ship products" story block. The only inverse color-block surface above the footer.
- Background `{colors.block-navy}`, text `{colors.inverse-ink}`, otherwise identical structure.

(Cream, mint, pink, and coral block variants follow the same shape with their respective `{colors.block-*}` surface.)

### Promo Banner

**`promo-banner-lilac`** — The Release Notes / "Save your spot" inline banner that floats above the contact form.
- Background `{colors.block-lilac}`, text `{colors.ink}`, type `{typography.body-sm}`, rounded `{rounded.md}`, padding `{spacing.md}` `{spacing.lg}`. Carries a `button-magenta-promo` on the right edge.

### Navigation

**`top-nav`** — Sticky white bar with logo, primary nav links, sign-in link, and the right-anchored `button-secondary` ("Contact sales") + `button-primary` ("Get started for free") pair.
- Background `{colors.canvas}`, text `{colors.ink}`, type `{typography.body-sm}`, height 56px.
- Mobile: collapses primary links into a hamburger that opens a full-canvas overlay; the two pill CTAs remain visible on the bar.

**`marquee-strip`** — Thin black ribbon directly under the nav that scrolls through customer logos in white.
- Background `{colors.inverse-canvas}`, text `{colors.inverse-ink}`, type `{typography.body-sm}`, height 36px.

### Comparison Glyphs

**`comparison-checkmark`** — Green check used in the pricing comparison matrix.
- Background `{colors.canvas}`, glyph color `{colors.semantic-success}`, rounded `{rounded.full}`, size 16px.

### Footer

**`footer`** — Dense link grid on white canvas with the wordmark "Figma" set in display weight at the top-left.
- Background `{colors.canvas}`, text `{colors.ink}`, type `{typography.caption}` for column headings and small links, padding `{spacing.section}` top/bottom · `{spacing.xl}` sides.
