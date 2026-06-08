---
applicability: report-builder skill — procedure for registering a new foundation kit from a DESIGN-*.md capture
read_when: user asks to add a new kit / design skin; NEVER during report builds
---

# Kit registration — DESIGN capture -> foundation

Run ONCE per kit. Report builds never run this — they consume the finished
kit file. This is the only place where design-system judgment happens; after
registration, every report assembles from fixed values.

## Inputs

- A capture file: e.g. `templates/DESIGN-Vercel.md`, `references/fixtures/figma/`
- Normalization rule sources (read them now, not at report time):
  `references/craft/typography.md`, `references/craft/color.md`,
  `references/craft/spacing.md`

## Step 1 — extract

Collect from the capture: color values, type families + scale, spacing,
radius, elevation, voice/brand notes. Expect ~90% coverage from a good
capture; list what is missing instead of inventing it.

## Step 2 — normalize to report rules

Marketing captures are not report foundations. Apply every row:

| Capture value | Foundation value | Rule source |
|---|---|---|
| pure `#fff` / `#000` neutrals | oklch tinted neutrals | color.md — never pure paper/ink |
| shadow stacks (multi-level) | single hairline ring `--e-1` | flat elevation |
| display weight 600 | hero weights 700-800 | kpi-tiles.md — room-distance legibility |
| marketing gradients / CTA colors | DROP | not report grammar |
| single flat palette | chrome / semantic / accent 3-layer split | color.md |
| marketing type scale | + hero ladder 96-140 / 56-72 / 36-44 | typography.md + kpi-tiles.md |
| latin-only font chain | + Korean fallback; Inter forbidden; end with generic family | typography.md chain rule |

## Step 3 — tokenize

Write `references/foundations/<kit>.css` as one `:root{}` block in the exact
group order of `_schema.md`. Comment provenance per group: `(1)` extracted
as-is, `(2)` normalized, plus the original value where it changed
(e.g. `/* from #fafafa */`).

Add the two kit declaration lines above `:root{}` — `@kit-color-mode:` and
`@kit-brand:` (syntax in `_schema.md` "Kit declarations"; they feed Preflight
axes #4/#9 at Stage 1 and are lint-checked).

## Validation (both required — registration is not done without them)

1. `scripts/lint-foundation.sh references/foundations/<kit>.css` -> exit 0
2. Render `references/components/spec-sheet.html` with the new kit swapped
   in; inspect screenshots directly. Zero layout breakage expected —
   components are token-driven, so breakage means the kit violates the
   contract (fix the kit, not the components).

## Failure modes to refuse

- Copying capture values verbatim without Step 2 — marketing look leaks into reports
- Inventing values absent from both capture and rules — the improvise regression this skill exists to kill
- Editing components to fit a kit — NEVER; the kit adapts to the contract, components stay fixed
- Registering a kit during a report build — finish or abort the report first
