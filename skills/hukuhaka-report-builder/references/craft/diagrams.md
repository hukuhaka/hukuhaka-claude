---
applicability: report-builder skill — hand-built SVG conventions for diagrams, schematics, flows
read_when: authoring or extending a component fragment (references/components/); during report builds only for judgment rules fragments cannot carry — density / per-register choice (Stages 4-5)
---

## Hand-author rule

**Never Mermaid in this context.** Auto-generated diagrams read as filler — the auto-layout is the convergence point. Hand-author every diagram in inline `<svg>`. The minimum control needed to make a diagram earn its place is incompatible with Mermaid's defaults.

This rule is absolute. If a diagram is too complex to hand-author, it is probably too complex for the report — decompose.

## Stroke discipline

- All structural strokes: 1.5px OR 2px — pick ONE per diagram, use everywhere. Mixed (1px + 2.5px) reads as accidental
- Stroke color: `currentColor` (inherits ink) for structural lines; OKLch literal accent (`oklch(50% 0.16 75)` ochre or register accent) for the highlighted path only
- Stroke-linecap: `round` for organic, `square` for technical schematics. Pick once per diagram
- Never stroke + fill the same shape unless deliberately representing nested state — pick one

## Color

- Diagram chrome: ink-on-paper, hairline rules, no fills except for severity boxes
- Accent: at most ONE accent color per diagram (the path being highlighted, the inflection node)
- Severity boxes (rare): use semantic palette from `craft/color.md`, not new colors

## Labels

- Node labels: mono (Geist Mono per `craft/typography.md`) at body size or 1-2px smaller
- Sub-labels / annotations: serif italic (deviation from default sans) at body size minus 2-3px — separates annotation from primary label
- Edge labels: mono at body size minus 2-3px, placed mid-edge with paper background slug (so the label sits over the line cleanly)
- Tabular-nums on any numeric label (counts, throughput)

## Annotation

A diagram that does not annotate the key path makes the reader hunt. For every diagram, mark at least one of: the critical path, the bottleneck, the changed component, the entry point. Annotation = short mono label + hairline rule pointing to the element.

## Density (per register)

- **Audit**: 1-2 diagrams per major finding. Diagrams thread between findings, not appendix
- **Dashboard**: rarely. Dashboards are data, not architecture
- **Brief**: at most one architectural diagram on the supporting page
- **IR-deck**: avoid — IR uses charts, not diagrams
- **Poster**: dense, multi-diagram acceptable; each must annotate
- **Incident**: timeline diagram top, system-state diagram for trigger explanation

## Anti-defaults

- Mermaid in any form, ever
- Iconography from libraries (Lucide, Feather, Font Awesome) used as diagram nodes — convergence to "tech blog hero"
- Drop-shadowed boxes with rounded corners — generic
- 3D rendering, isometric without reason — chart-junk
- All-caps labels in body diagrams — shouting
- Gradient fills on nodes — chart-junk
- Animated SVG (rotating, pulsing) — kills scan; this is a static artifact

## Common failure modes

- **No accent path** — diagram reads as inert; nothing to follow
- **Mixed stroke weights** — accident, not design
- **Sans labels without font-feature-settings** — proportional digits in counts misalign
- **Labels outside the figure with leader lines crossing each other** — restructure layout
- **Caption missing** — every figure needs a serif italic caption at body-size-minus-2 explaining what the reader is looking at
