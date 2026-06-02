---
stage: 4
purpose: render the cover page HTML, show to user, gate before building body
prereq: spec.md Preflight + Subject+Hero + Outline blocks all committed
deliverable: cover.html written to .claude/reports/<short-name>/cover.html, rendered, screenshotted
verification_gate: user views the cover, confirms register-identity reads in 3 seconds
---

## What this stage does

Cover is identity. If the cover does not establish the register in 3 seconds, no later page can recover that signal. Build it, show it, then decide whether to proceed.

## Required reading

- `.claude/reports/<short-name>/spec.md` (re-read at stage start — Preflight page-format + register + brand/version/disclaimer axes all bind cover chrome)
- `references/craft/cover.md` (full)
- `references/craft/typography.md` (font lock + CSS chain — Inter is forbidden as fallback)
- `references/craft/color.md` (palette per register from Stage 1)
- `references/craft/spacing.md` (page margin per register)

## Process

1. Re-read spec.md. Pull Preflight (page format / orientation / color mode / register / brand layer / disclaimer / versioning), Subject, short-name. Choose cover treatment per `craft/cover.md`.

2. Generate cover-only HTML — single page, no body sections. Include:
   - wordmark (subject)
   - tagline (≤8 words preferred, 15 max)
   - register chrome (header bar with mono eyebrow, footer with audit/brief metadata)
   - optional scope strip (mono list of what's inside)
   - LOCKED chrome (Geist font import via Google Fonts, CSS palette tokens, page frame per Preflight `page format` + `orientation`)
   - brand layer per Preflight `brand layer` axis (none / wordmark / logo / watermark)
   - versioning surface per Preflight `versioning surface` axis (none / date / version / author+date)
   - disclaimer per Preflight `disclaimer policy` axis (footer band)

3. Write to `.claude/reports/<short-name>/cover.html`.

4. Use Playwright (or ask user to open the file) — capture a screenshot of the cover at viewport sized to the page. Save to `.claude/reports/<short-name>/screenshots/p1.png`.

5. Show the screenshot to user. Ask:
   - "Does this read as <register> in 3 seconds?"
   - "Does the project identify in 3 seconds?"
   - "Does the cover obey the 1/3 scale rule (cover wordmark ≤ 1/3 of in-report hero scale)?"

## Verification gate

User says:
- "OK" → cover.html stays at `.claude/reports/<short-name>/cover.html`. Append `Stage 4: cover.html rendered, user OK <date>` to spec.md Build log. Proceed to Stage 5
- "<X> is off" → loop ONLY on cover (not the whole report). Re-render. Re-verify
- "wrong register" → BACK to Stage 1 (revise the register axis in spec.md Preflight block)
- "wrong page format / brand / disclaimer / versioning" → BACK to Stage 1 (revise the corresponding axis)

Do NOT proceed to body until cover passes.

## Failure modes

- Treating cover as a summary (hero number on cover — see `craft/cover.md` forbidden patterns)
- Marketing-tagline subtitle
- Skipping the screenshot gate ("I'll just build the whole thing and you'll see")
- Font-family chain ending in `-apple-system / sans-serif` (silent Geist failure — see `craft/typography.md` CSS chain rule)
