---
applicability: report-builder skill — required token contract for every foundation kit
read_when: registering a new kit (REGISTER.md step 3) or editing scripts/lint-foundation.sh
---

# Foundation token contract

Every kit file `references/foundations/<kit>.css` MUST define all tokens below
in a single `:root{}` block. `scripts/lint-foundation.sh` enforces this list —
keep the script's `REQUIRED_TOKENS` array in sync with this table.

| Group | Tokens | Lint checks |
|---|---|---|
| chrome | `--paper --surface --sunk --ink --ink-soft --ink-mute --hairline --hairline-2` | present; oklch only; never pure white/black |
| dark band | `--dark-band --dark-ink` | present; oklch only |
| semantic | `--gain --gain-soft --loss --loss-soft --warn --warn-soft --warn-deep --info` | present; oklch only |
| accent | `--accent --accent-soft --accent-2 --accent-3` | present; oklch only (register may override values; -2/-3 are series steps for stacked charts) |
| type family | `--sans --mono --serif` | present; Inter forbidden anywhere in chain; `--sans`/`--mono` chains must end with a generic family (`sans-serif` / `monospace`) |
| weight | `--w-display --w-head --w-body` | present |
| type scale | `--t-hero --t-sub --t-tile --t-dxl --t-dlg --t-dmd --t-lead --t-body --t-sm --t-caption --t-eye --t-code` | present; hero ladder within 96-140 / 56-72 / 36-44 |
| spacing | `--space-1` .. `--space-8` | all 8 tiers present |
| radius | `--r-0 --r-1 --r-2 --r-3 --r-4` | present |
| elevation | `--e-1 --e-2` | present (flat: hairline ring, ring+1px float; deeper stacks forbidden) |

Color rule: every color literal in the file must be `oklch(...)`. Hex, `rgb()`,
`hsl()`, and named colors fail lint. Comments are exempt — provenance notes
like "from #fafafa" are encouraged.

## Kit declarations (read by Stage 1)

Every kit file MUST carry exactly two declaration comment lines (lint-checked
against the RAW file — these live in comments, unlike tokens):

```
/* @kit-color-mode: <light | dark | both> */
/* @kit-brand: <none | wordmark | logo | watermark> */
```

These feed Preflight axes #4 (color mode) and #9 (brand layer) with provenance
`kit-default`. A kit declaring `light` only cannot be overridden to `dark` at
Stage 1 — dark is a kit variant (a separate kit file), not a per-report toggle.

Ordering rule: groups appear in the table order above. A kit that needs an
extra token MAY add it after the contract groups, but components may only
depend on contract tokens — kit-specific extras are for the kit's own
internal composition (e.g., a gradient stop used by its dark band).
