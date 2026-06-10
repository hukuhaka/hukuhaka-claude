---
stage: 3
purpose: assemble the cover page from the cover fragment, show to user, gate before building body
prereq: spec.md Preflight + Subject+Hero + Outline blocks all committed
deliverable: cover.html written to .claude/reports/<short-name>/cover.html, rendered, screenshotted
verification_gate: user views the cover, confirms register-identity reads in 3 seconds
---

## What this stage does

Cover is identity. If the cover does not establish the register in 3 seconds, no later page can recover that signal. **Stage 1 already rendered the register-identity SEED** (`cover.html` with real kit CSS + register chrome + a *provisional* wordmark). Stage 3 does NOT rebuild it — it **inherits the seed and completes it** with the now-locked Subject/Hero, then shows it and decides whether to proceed.

## Required reading

- `.claude/reports/<short-name>/spec.md` (re-read at stage start — Preflight page-format + register + brand/version/disclaimer axes all bind cover chrome; Subject + Hero from Stage 2; `kit:` field names the foundation)
- `.claude/reports/<short-name>/cover.html` — the **Stage-1 seed** to inherit (already carries kit CSS + register chrome; renamed here from `tmp-draft` by Stage 2)
- `references/components/cover.html` (the fragment — markup, slots, and its header comments; reference only, the seed is already built from it) + `references/components/_base.css`
- `references/foundations/<kit>.css` (the kit named in spec.md — all chrome values come from these tokens)
- `references/craft/cover.md` — build-time judgment only: the 1/3 scale rule + tagline craft
- `references/craft/spacing.md` — build-time judgment only: page margins per register

## Process

1. Re-read spec.md. Pull Preflight (page format / orientation / color mode / register / brand layer / disclaimer / versioning), Subject, Hero, short-name, kit.

2. **Inherit the seed and complete it.** Open the existing `.claude/reports/<short-name>/cover.html` (the Stage-1 seed). Its kit CSS, register chrome, page frame and palette are already correct — do NOT rebuild them or write new CSS. Edit ONLY the content slots:
   - wordmark — replace the **provisional** Stage-1 wordmark with the **locked Subject** (Stage 2)
   - tagline — fill from the Hero finding (≤8 words preferred, 15 max); the seed left this empty/provisional
   - register chrome (`.k` eyebrow, `.meta`) — already in the seed; only correct content (date/author/version) per Preflight if it was a placeholder
   - brand layer per Preflight `brand layer` axis (none / wordmark / logo / watermark)
   - versioning surface per Preflight `versioning surface` axis (none / date / version / author+date)
   - disclaimer per Preflight `disclaimer policy` axis (footer band)
   If the seed is missing (older report, or hand-deleted), fall back to assembling fresh from `components/cover.html` — but the normal path is inherit-and-complete.

3. Save the completed cover at `.claude/reports/<short-name>/cover.html` (Edit the seed in place).

4. Render in a browser — capture a screenshot of the cover at viewport sized to the page. Save to `.claude/reports/<short-name>/screenshots/p1.png`.

5. Show the screenshot to user. Ask:
   - "Does this read as <register> in 3 seconds?"
   - "Does the project identify in 3 seconds?"
   - "Does the cover obey the 1/3 scale rule (cover wordmark ≤ 1/3 of in-report hero scale)?"

## Verification gate

User says:
- "OK" → cover.html stays at `.claude/reports/<short-name>/cover.html`. Append `Stage 3: cover.html rendered, user OK <date>` to spec.md Build log. Proceed to Stage 4
- "<X> is off" → loop ONLY on cover (not the whole report). Re-render. Re-verify
- "wrong register" → BACK to Stage 1 (revise the register axis in spec.md Preflight block)
- "wrong page format / brand / disclaimer / versioning" → BACK to Stage 1 (revise the corresponding axis)

Do NOT proceed to body until cover passes.

## Failure modes

- Treating cover as a summary (hero number on cover — see `craft/cover.md` forbidden patterns)
- Marketing-tagline subtitle
- Skipping the screenshot gate ("I'll just build the whole thing and you'll see")
- Overriding kit font tokens with a raw `font-family` value (kit violation — `scripts/lint-components.sh` catches this in fragments; do not reintroduce it in the report)
