---
applicability: report-builder skill — table density, alignment, color, typography
read_when: authoring or extending a component fragment (references/components/); during report builds only for judgment rules fragments cannot carry — density / per-register choice (Stages 4-5)
---

## Density

Row height = **1.5–1.8× body line-height**. Not taller. Tall row heights (2.5×+) read as space-filler and signal lack of conviction.

Column padding: consistent across rows (no per-row variation). Inter-column gap should match horizontal padding (commonly 16–24px on desktop).

Cells should feel **dense, not airy**. A 6-column 20-row data table is dense material — let it look that way. Loose cell spacing makes data look like a layout draft.

## Rules

- **Horizontal rules**: hairline (1px, neutral-300 / `oklch(85% 0 0)` or similar) between rows, OR omitted entirely. Thicker only on header separator and table-bottom (2px ink-tone).
- **Vertical rules**: omit by default. Alignment carries the column. Reach for vertical rules only when the table has grouped columns that need visual separation.
- **Zebra stripes**: skip unless density genuinely requires (≥10 columns, or visually-similar-text-heavy rows). Even then, prefer a single subtle off-paper tone, not alternating saturated bands.

## Alignment

- **Numbers**: right-aligned, `font-variant-numeric: tabular-nums` always (proportional digits in metric content read as careless)
- **Text**: left-aligned
- **Headers**: same alignment as their column (right-align number-column headers)
- **Currency / units**: right-aligned with unit as smaller mono suffix (e.g., `$2,345` `M` where M is `.unit` class at 0.85× and muted)
- **Mixed-type columns** (text + delta number): right-align the number, let the text fill leftward

## Color

- **Deltas**: gain = green (`color-gain`), loss = red (`color-loss`). Use the SAME pair across every table in the same report. Subtle saturation; reserve high-saturation for the genuine outlier
- **Header row**: subtle bg tint (`oklch(96% 0.005 60)` or similar) OR weight bump (mono 600), not both — avoid heavy banded headers
- **Body cells**: no bg color unless data semantically demands it (e.g., heatmap, status pill). Chrome color in data cells makes data hard to read
- **Hover row**: optional subtle bg tint on hover for interactive contexts; never bold/border-change on hover

## Typography in tables

- Body text in tables = same size as report body, OR 1–2px smaller, never larger
- Numbers always in mono (with tabular-nums)
- Header labels in mono uppercase tracked +0.05em if the report's chrome uses mono eyebrows; otherwise sentence-case body weight 600
- Avoid italic in tables (italic + tabular-nums fights for the eye)

## Common failure modes

- **Looms**: row heights at 3× line-height — table looks padded for space, not dense
- **Bordered grid**: vertical + horizontal rules on every cell — reads as spreadsheet, not report
- **Sentence-case headers with quote-marks** — pseudo-formal; use mono uppercase or weight bump instead
- **Center-aligned numbers** — kills column-eye-scan; right-align always
- **Inline icons in numeric cells** — fights tabular-nums alignment; put icons in a separate small column
