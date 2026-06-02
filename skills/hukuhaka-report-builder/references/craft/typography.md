---
applicability: report-builder skill — default typography lock + register-specific deviations
read_when: any time you need to pick fonts for a report
---

## Default Lock — Geist

For clean report registers (technical audit, executive brief, status update, forensic incident, dashboard, internal architecture doc), default to:

- **Body + display**: Geist (variable, open source — `fonts.google.com/specimen/Geist`)
- **Mono**: Geist Mono (variable, open source — `fonts.google.com/specimen/Geist+Mono`)

This is the lock. Subagents should not re-deliberate for clean reports unless the register specifically justifies deviation (see below).

## Weight + role mapping

| Role | Family / weight | Notes |
|---|---|---|
| Display (cover wordmark, page hero) | Geist 700–800 | Tight tracking on large sizes (-0.02em at >48px) |
| Headline (section finding) | Geist 600 | Slight negative tracking at >24px |
| Body | Geist 400 (or 350 for long passages) | line-height 1.45–1.55 |
| Eyebrows / chrome / metric units | Geist Mono 500–600 uppercase | tracked +0.04–0.08em |
| Code / file refs / tabular numerals | Geist Mono 400 | `font-variant-numeric: tabular-nums` |

## Anti-defaults (always avoid)

- System font stack (`-apple-system, BlinkMacSystemFont, ...`) — careless default; always pick
- Multiple display weights (300/400/500/700) on the same surface — pick 2 weights max per role
- Mono in body text — mono is for taxonomy / metrics / code, never narrative
- Mid-gray text to fake hierarchy — use weight instead

## When to deviate (register-specific exceptions)

Other registers MAY justify a different stack — deviation must be defended in writing:

- **Editorial-academic / paper review**: pair serif display (Source Serif, Crimson Text) with Geist body. Justify why serif fits the report's authority claim.
- **IR-style earnings deck**: high-contrast serif display (Fraunces optical-sized, Tiempos) is OK if the deck's gravity demands it.
- **Academic poster**: dense humanist sans (IBM Plex Sans) often beats Geist at small sizes in tight layouts.
- **Long-form editorial / newsletter**: a transitional serif (Charter, Source Serif) for body if reading-time is long.

Default is the lock. Deviations are exceptions to defend, not a menu to browse.

## Fallback alternates (if Geist unavailable)

Inter is FORBIDDEN as a fallback even though it's the most common AI default — it's the single most identifying convergence font and is called out by the anti-defaults above. Use one of the alternates below and *load it explicitly* (Google Fonts `@import` or bundled).

In order of preference:

1. **IBM Plex Sans** (+ IBM Plex Mono) — slightly more character, engineering-feel; good for technical audits and incident registers
2. **Söhne** (+ Söhne Mono) — commercial, if licensed; sharper, well-suited to IR/brief registers
3. **Berkeley Mono** for code pair if IBM Plex Mono / Söhne Mono unavailable

## CSS font-family chain (required)

Every CSS `font-family` declaration in the report MUST end with a curated alternate, NOT with `-apple-system` / `BlinkMacSystemFont` / `sans-serif` alone. The system stack is the silent failure path that turns the Geist lock into the default macOS UI font — defeating the entire anti-default premise when the network blocks the Google Fonts request or the artifact is viewed offline / printed to PDF.

Wrong (silent fail to system):

```css
font-family: 'Geist', -apple-system, BlinkMacSystemFont, sans-serif;
```

Right (curated fallback):

```css
font-family: 'Geist', 'IBM Plex Sans', 'Söhne', sans-serif;
```

The trailing `sans-serif` is acceptable ONLY as a last-resort generic — curated alternates must precede it. Validate by loading the report with the network throttled / DevTools "Disable cache" + offline mode — the rendered identity must still read as a Geist-class grotesque, not as San Francisco.
