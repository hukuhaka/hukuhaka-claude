---
applicability: report-builder skill — chart styling for any register
read_when: designing any chart, plot, bar, line, scatter, or data-vis figure
---

## Default

A chart is content, not chrome. Every chart answers a question prose cannot answer as efficiently. If the chart can be replaced by one sentence, delete the chart.

Use **Chart.js with explicit overrides** OR **hand-built SVG**. Either works; both require intentional choices for axis, palette, label, annotation. Library defaults are never acceptable — they identify the report as a template-of-template instantly.

## Axes

- Label both axes with units (`Latency (ms)`, `Throughput (req/s)`). Unitless axes read as careless
- Tabular-nums always on tick labels (`font-variant-numeric: tabular-nums`)
- Tick density: ≤7 major ticks per axis; more = noise
- Origin: include zero unless explicitly framing a delta range. If you crop the axis, **annotate the crop** (`// y-axis starts at 80%`) — silent cropping misleads
- Gridlines: hairline (1px, `oklch(90% 0 0)` or similar), horizontal only. Vertical gridlines are noise unless the chart is time-series with date ticks

## Palette

- 2-series chart → use the report's committed comparison color pair (winner-loser, baseline-proposed). Same pair across every chart in the same report (see `craft/color.md`)
- ≥3 series → one accent + greyscale shades. Rainbow palettes are forbidden
- Categorical (not comparative) → ordinal greyscale + one accent for the focus category
- Single-series → one accent color, neutral chrome
- Never assign meaning to color alone — pair with shape, label, or position

## Annotation

A chart that does not annotate the inflection point makes the reader hunt. For every chart, mark at least one of: the bar that matters, the inflection, the crossover, the outlier. Annotation = short text label + hairline rule pointing to the data point, NOT a callout balloon with shadow.

## Strip the defaults

Never ship: 3D bars, drop-shadowed bars, gradient fills on data, rainbow palettes, legend below scroll-fold, percentage labels on pie slices >5 categories, chart-junk borders, axis numbers in proportional digits, bottom-aligned legends when direct labels would fit.

## Anti-defaults

- Default Chart.js colors (`rgba(54, 162, 235)`, `rgba(255, 99, 132)`) — instantly identifies AI default
- Pie chart with >5 slices → use horizontal bar instead
- Time-series with x-axis labels `1, 2, 3, 4` — show actual dates
- Stacked bars without category total annotation — reader has to do mental math
- "Smooth" line interpolation on noisy data — misleads about between-point values

## Common failure modes

- **Legend-instead-of-direct-label**: if you can fit a label next to each line/bar, direct-label and drop the legend
- **Tick density set by library default** (~10-12 ticks) — too dense at report scale
- **Axis labels not visible at page-thumbnail zoom** (Self-Test #3) — too small or low-contrast
- **No annotation** — chart is content but conveys no specific finding
