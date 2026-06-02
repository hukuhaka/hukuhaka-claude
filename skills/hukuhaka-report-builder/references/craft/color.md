---
applicability: report-builder skill — palette construction per register
read_when: choosing a palette for a new register, section, chart family, or any color decision
---

## Three-layer foundation

A report palette has three layers, kept structurally distinct:

- **Chrome** (paper, ink, rules, body text): near-neutrals. Never pure `#ffffff` paper or pure `#000000` ink — slightly tinted neutrals carry more authority
  - Paper: `oklch(98-100% 0.005-0.015 60-90)` (warm tint) or `oklch(99% 0.005 240)` (cool tint)
  - Ink: `oklch(18-22% 0.005-0.020 60-90)` (warm near-black, not pure)
  - Rules: `oklch(85-92% 0 0)` (hairline)
- **Semantic** (data, comparisons, deltas): reserved for meaning, never used for chrome
  - Comparison pair: assigned ONCE per report, applied to every chart cell badge legend
  - Gain/loss: `oklch(60% 0.18 145)` green / `oklch(60% 0.20 25)` red
  - Warning/info: `oklch(75% 0.16 80)` amber / `oklch(60% 0.12 240)` blue
- **Accent** (one hue per register): used sparingly for highlights, badges, hero callouts. Never for body text

## Per-register guidance

- **Audit / Brief**: warm-neutral chrome + single ochre accent (`oklch(50% 0.16 75)`). Severity uses semantic red/amber/green sparingly
- **Dashboard**: cooler-neutral chrome (`oklch(99% 0.005 240)`) + saturated semantic palette for KPI deltas. Subtle bg tints on KPI tiles only
- **IR-deck**: institutional palette (deep navy `oklch(25% 0.08 250)` or single corporate hue) + semantic for QoQ deltas
- **Poster**: high-contrast pair (ink-on-paper) + single inverted band per section. Color secondary to typography
- **Incident**: muted neutrals + severity colors only (red/amber/green/grey) — no decorative accent

## Print / PDF contrast

If the report will be printed or exported to PDF:

- Body text vs paper: ≥7:1 contrast (WCAG AAA), test in greyscale
- Semantic colors must remain distinguishable in greyscale (red vs green fails — pair with shape or label)
- Accent must still read on monochrome printer — saturation alone is not signal

## Anti-defaults

- Tailwind's full `slate-200/300/400/500` ramp as chrome — instantly identifies "AI internal-doc" look
- Generic blue (`#3b82f6`, `#2563eb`) as accent — undeliberate
- Purple-to-pink gradient on hero band — kills analytic authority
- Emerald-to-cyan gradient on chart bars — chart-junk
- Pure white paper + pure black ink — careless
- Mid-gray body text (`#6b7280`) to fake hierarchy — use weight, not color (see `craft/typography.md`)
- Different accent per page — register dissolves; one accent per report

## Common failure modes

- **Same accent as a rule color** — chrome dissolves into accent
- **More than 3 saturated hues per surface** — circus
- **Semantic green/red applied to chrome** (e.g., section header in green) — semantic exhausted, deltas no longer pop
- **Dark mode auto-derived from light** — both modes must be intentionally designed; auto-invert reads as careless
- **Accent used on every page** — accent stops anchoring; reserve for the page-defining element
