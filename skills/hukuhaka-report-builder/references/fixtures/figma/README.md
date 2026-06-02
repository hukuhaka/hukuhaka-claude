---
source: figma marketing site (figma.com — home, /design/, /figjam/, /pricing/, /contact/)
applicability: gestalt — read FIRST to grasp the system, then read only the sub-files
  relevant to your current decision. Do NOT read all sub-files in one pass — that
  signals you are about to clone, not study.
sub_files:
  - typography.md   — general (most patterns transfer to reports)
  - color.md        — mixed (monochrome transfers; color blocks marketing-only)
  - layout.md       — mostly general (spacing scale transfers)
  - shapes.md       — general (radius scale, shadow philosophy transfer)
  - components.md   — MARKETING-ONLY (skip unless register is marketing/landing)
  - responsive.md   — general structure transfers, specific behaviors marketing-bound
  - do-dont.md      — mixed
---

## Overview

Figma's marketing canvas is, at the system level, an editor-clean black-and-white frame. The chrome — top nav, body type, footer, primary CTA — is monochrome. Headlines are oversized `{typography.display-xl}` set in `figmaSans` with aggressive negative tracking, body copy hovers around weight 320–340 of the same variable family, and small mono `{typography.eyebrow}` and `{typography.caption}` labels (figmaMono, all-caps, positive tracking) act as section markers. Every CTA is a pill — `{rounded.pill}` — and the primary action across the entire site is the same black `{components.button-primary}` paired with the same white `{components.button-secondary}`.

What makes the design unique is what happens **between** those monochrome bookends: the page repeatedly drops into oversized pastel **color-block sections** — lime, lavender, cream, mint, pink, coral, and a deep navy — that span the full content width with `{rounded.lg}` corners and `{spacing.xxl}` interior padding. These blocks are where the storytelling lives. They aren't accents tucked into a card; they take over a whole viewport's worth of vertical space, like a designer arranging giant sticky notes on a clean wall. FigJam is the most pastel-saturated, the home page rotates through the full set, and the pricing page ends with a lime FAQ panel — same vocabulary, different rhythm per route.

This is a system built on contrast: the monochrome chrome makes the color blocks feel intentional rather than decorative, and the color blocks make the monochrome chrome feel like editorial paper rather than enterprise SaaS. Density is generous, line-heights are tight on display sizes, and the interface never reaches for shadows or gradients to do the work that color blocks and confident typography already do.

## Key Characteristics

- Monochrome system core: `{colors.primary}` (black) and `{colors.canvas}` (white) carry every CTA, every body line, every footer link.
- Oversized pastel **color-block sections** (`{colors.block-lime}`, `{colors.block-lilac}`, `{colors.block-cream}`, `{colors.block-mint}`, `{colors.block-pink}`, `{colors.block-coral}`, `{colors.block-navy}`) define the narrative rhythm of every long-form page.
- Pill is the only button shape — `{rounded.pill}` for text CTAs, `{rounded.full}` for icon buttons. No square buttons anywhere.
- `figmaSans` variable typeface used at unusually fine weight increments (320, 330, 340, 450, 480, 540) — the type system reads as a single voice that flexes rather than a multi-weight family.
- Tight negative letter-spacing on display sizes (-1.72px at 86px, -0.96px at 64px) creates a confident editorial cadence.
- `figmaMono` reserved for category labels, eyebrows, and captions — always uppercase, positive tracking — to flag taxonomy without competing with display type.
- Color-block page rhythm (home): white hero → marquee strip → white feature → lime systems block → navy ship-products block → coral developer block → white template grid → white footer.

## Iteration Guide (when mining this system for your own register)

1. Read the Overview first. Decide whether Figma's *gestalt* even fits the register you are building — if your register is data-report, the gestalt does NOT transfer (Figma is marketing); skip directly to typography.md and stop there.
2. For each decision, read only the relevant sub-file (typography.md for font picks, color.md for palette, etc.). If you find yourself opening every sub-file, stop — you are cloning, not mining.
3. Each sub-file declares `applicability` in frontmatter. If it says MARKETING-ONLY for your register, close it.
4. When introducing a new section, decide **first** which surface family it sits on — that surface choice is the most consequential decision. (For Figma marketing, that means picking a `{colors.block-*}`. For a data report, that means picking whether the section is a KPI band, a chart band, or a verdict band.)
5. Keep accent / primary colors scarce. The Figma rule "if two `button-primary` instances appear in the same viewport, the section is doing too much" generalises: any committed accent should appear once or twice per viewport, not five times.

## Known Gaps

- The exact pastel hex values of `{colors.block-*}` are derived from screenshot pixels; the production source likely uses named tokens that aren't exposed via CSS variables. Treat the documented hex values as faithful approximations rather than exact brand specs.
- Dark mode is not documented because the marketing site does not ship a dark theme — the closest analog is the navy color-block (`color-block-section-navy`) and the inverse-canvas footer.
- Form-field error and validation styling is not visible on `/contact/` because no error states render in the static screenshot. Inputs have hairline borders and rounded `{rounded.md}` corners; error treatment is not documented.
- The animated marquee-strip and color-block reveal animations are not documented (per the no-interaction policy).
