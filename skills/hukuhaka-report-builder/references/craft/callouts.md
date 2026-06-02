---
applicability: report-builder skill — sidebars, margin notes, highlight boxes, pull-quotes
read_when: presenting commentary that should not flow as body prose
---

## When to use

A callout is for content that is **adjacent** to the main flow but should not be a body paragraph. Use sparingly — every callout costs scan attention.

Use a callout for:
- Definition or footnote-style detail readers might want
- Warning, caveat, or scope limit on a finding
- Quote from source material that anchors a claim
- Recommendation or next-step under a finding

Do NOT use a callout for:
- A transitional sentence (rewrite as a body bullet)
- Multiple paragraphs (becomes a section, not a callout)
- Decoration (callouts are content; if it doesn't add, drop it)

## Sidebar (vertical block, gutter or in-flow)

- Width: 180-260px in left/right margin, OR full-content width if in-flow
- Background: subtle paper tint (`oklch(96% 0.005 60)`) OR no background + 2px left rule in accent
- Header: mono uppercase eyebrow label (`NOTE`, `CAVEAT`, `SOURCE`), tracked +0.04em
- Body: same size as body text, or 1-2px smaller
- Never combine heavy border + heavy background + accent header simultaneously — pick one or two

## Margin note (Tufte-style)

A small callout placed in the page margin, near the body sentence it annotates.

- Width: 140-200px
- Type: serif italic body or mono small — visually distinct from body
- No background — only spacing isolates
- Best on wide-margin layouts (audit, brief). Useless on dashboard/poster

## Highlight box (in-flow, severity-tinted)

In-flow box for a finding or warning that must not be skipped.

- Background: subtle tint of the relevant semantic color (`oklch(96% 0.04 25)` for warning, `oklch(96% 0.04 145)` for success) — see `craft/color.md`
- Left border: 3-4px in the full semantic color
- Header: mono eyebrow + finding text in body weight 600
- Padding: `--space-4` to `--space-5` (per `craft/spacing.md`)
- One per page max — overuse turns them into chrome

## Pull-quote (editorial registers only)

Used in research-recap / customer-facing editorial registers. Almost never in audit/dashboard/incident.

- Type: serif italic display size (24-32px), `oklch(35% 0.005 60)` (slightly dimmed ink)
- Width: 75% of content measure, indented
- No quote marks — typography carries the quotation

## Anti-defaults

- Yellow `#fef9c3` background with grey border — generic Tailwind warning look
- Emoji icon header (⚠️ ✅ 💡) — kills authority, especially in audit/IR registers
- Callout with marketing-tagline body ("Did you know...") — wrong register
- Box-shadow on the callout — chart-junk
- Multiple callouts in a row — they cancel each other; consolidate or restructure
- Heavy 2-3px border on all 4 sides — generic admonition look

## Common failure modes

- **Every section has a callout** — they become chrome, not content
- **Callout repeats body content** — delete the callout or delete the body
- **Decorative use** (e.g., a "Quick Stats" callout that's actually a small table) — make it a real table or remove
- **Wrong semantic color** (success tint on a warning) — semantic exhausted
- **Margin note used on narrow layouts** (dashboard) — has nowhere to live, collides with content
