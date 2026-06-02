---
applicability: report-builder skill — code snippets in technical audit and engineering reports
read_when: including any code snippet, config block, command, file path, or log excerpt
---

## When code belongs

- **Audit**: regularly — code is the primary evidence
- **Incident**: configuration excerpts, log lines, query strings, stack traces
- **Brief / IR-deck / Poster**: rarely — only if the snippet IS the finding
- **Dashboard**: configuration blocks only

If the snippet exceeds 15 lines, it likely belongs in an appendix or external link. The body should show the diff or the critical 3-5 lines.

## Typography

- Family: **Geist Mono** at body size or 1-2px smaller (see `craft/typography.md`)
- Weight: 400 for normal code; 500 for highlighted lines
- Line-height: 1.4-1.5 (denser than body prose)
- Tabular-nums on any inline metrics within code

## Syntax highlighting

If used, must be **subdued**:

- Keywords in body ink weight 600, NOT colored
- Strings in single muted accent (`oklch(45% 0.08 25)` or register accent)
- Comments in `oklch(55% 0 0)` italic
- Numbers + booleans: body ink, no color change
- Never use VSCode-default rainbow theme — instantly identifies blog-essay aesthetic

Plain (no highlighting) is often better — typography carries the structure.

## Line numbers

- Optional. Only include if prose explicitly references line numbers ("see line 42")
- If included: mono, dimmed (`oklch(60% 0 0)`), right-aligned, separated by `--space-3` from the code
- Never include if not referenced — pure chrome

## Background + padding

- Background: subtle tint (`oklch(97% 0.005 60)` warm), NOT pure white
- Padding: `--space-4` all sides; `--space-3` for inline-feel blocks
- Border: hairline 1px `oklch(90% 0 0)` OR no border. Never both background AND heavy border
- Border-radius: 0 or 2-3px. Larger reads as generic card

## Inline code

In body prose, inline `<code>` (e.g., `--space-4`):

- Same mono family, 0.9× body size
- Background: very subtle tint (`oklch(96% 0.005 60)`) or no background + body ink + bold weight (500)
- Padding: 0 1-2px
- Never bordered

## Highlighting within a block

- Highlighted line: 2-3px left border in register accent, NO background change (background change competes with syntax)
- Highlighted token (rare): mono weight 600, no color change
- Diff:
  - `+` (added): left border `oklch(60% 0.18 145)` green
  - `-` (removed): left border `oklch(60% 0.20 25)` red
  - Symbols (+/-) in mono dimmed at 0.7× opacity

## Caption / filename

Every code block needs a small mono caption above showing filename or context (`src/handler.ts`, `config.yaml:42`). A code block without context leaves the reader hunting.

## Anti-defaults

- VSCode dark theme code blocks on a light report — register collision
- Rainbow syntax highlighting (purple keywords, orange strings, green comments)
- Heavy drop-shadow on code block — generic blog look
- Light-gray monospace on light-gray bg — illegible
- Inline code with rounded pill + accent bg — over-decorated
- "Copy" button overlay — interaction chrome, irrelevant in scan-mode report

## Common failure modes

- **20+ line code blocks in body** — break into 3-5 line excerpts with prose between
- **Code block without caption / filename** — leaves the reader hunting
- **Syntax highlighting that distracts from the finding** — strip the syntax
- **Long lines that wrap** — adjust measure or use horizontal scroll with caption marker
