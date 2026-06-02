---
source: figma marketing site
applicability: mixed — some rules transfer (weight-as-hierarchy discipline, scarce
  primary color, mono-not-body), some are marketing-bound (pill-only, color-block
  cadence). Read each rule with "does this rule transfer or is it figma-specific?"
  in mind. Each item below is tagged.
transferable_rules:
  - "Don't introduce mid-gray text" — weight, not opacity, carries hierarchy
  - "Don't put mono in body copy" — mono is for taxonomy, not reading
  - "Reserve primary color for genuine primary actions"
  - "Commit to a palette and stop adding accents"
  - "Pick a discrete weight set and stick to it"
non_transferable_rules:
  - "Compose every CTA as a pill" — marketing brand signature
  - "Choose one color block per story section" — marketing storytelling
  - "Don't square off CTAs" — marketing brand
---

## Do's and Don'ts

### Do

- Reserve `{colors.primary}` for genuine primary CTAs and selected states (e.g., `pricing-tab-selected`). Don't use it as a decorative accent.  *[TRANSFERS — applies to any committed accent color in any register]*
- When introducing a story section, choose **one** color block from the `{colors.block-*}` family and let it span full content width with `{rounded.lg}` corners and `{spacing.xxl}` interior padding.  *[MARKETING-ONLY]*
- Keep type in `figmaSans` at variable weights — pick from 320, 330, 340, 480, 540, 700 to express hierarchy. Avoid intermediate weights outside this set.  *[TRANSFERS as "pick a discrete weight set and commit"]*
- Use `figmaMono` only for eyebrows and captions, always uppercase, with the documented positive letter-spacing.  *[TRANSFERS as "mono is taxonomy, not body"]*
- Compose every CTA as a pill (`{rounded.pill}`) and every icon button as a circle (`{rounded.full}`).  *[MARKETING-ONLY — for reports, pick whatever shape grammar fits your register and commit]*
- Allow the page to **return to white canvas** between every two color blocks so each block reads as deliberate.  *[Generalised: any high-density section needs breathing room around it]*
- Pair `button-primary` and `button-secondary` whenever a section needs both a primary action and a sales / secondary action — the black-and-white pair is the brand signature.  *[MARKETING-ONLY shape, but "primary/secondary pair as a unit" pattern transfers]*

### Don't

- Don't introduce mid-gray text. Body hierarchy comes from `figmaSans` weight, not from opacity.  *[TRANSFERS — never use opacity to fake hierarchy]*
- Don't add drop shadows to color-block sections — the color is the depth device.  *[MARKETING-ONLY shape; generalised: don't double-up depth devices]*
- Don't introduce new accent colors outside the documented `{colors.block-*}` palette and `{colors.accent-magenta}`. Adding, e.g., a saturated brand orange would break the system.  *[TRANSFERS as "commit to a palette and stop adding"]*
- Don't combine more than one color block visible inside a single viewport — Figma's pacing always lets the white canvas separate them.  *[MARKETING-ONLY]*
- Don't square off CTAs. Square buttons read as a different brand.  *[MARKETING-ONLY]*
- Don't put `figmaMono` in body copy — it's a taxonomy tool, not a reading typeface.  *[TRANSFERS]*
- Don't replace the `pricing-tab-selected` black fill with a colored tab; the brand pattern is "selected = primary surface".  *[MARKETING-ONLY for the specific surface; the meta-principle "selected = active CTA color, not passive grey" transfers]*
