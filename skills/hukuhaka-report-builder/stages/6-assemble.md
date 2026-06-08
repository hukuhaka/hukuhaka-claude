---
stage: 6
purpose: final assembly + 6-item Self-Test, then ship
prereq: All Stage 5 sections appended to report.html and individually verified
deliverable: .claude/reports/<short-name>/ directory complete (report.html + spec.md finalized + screenshots/)
verification_gate: 6-item Self-Test from SKILL.md, then user final read-through
---

## What this stage does

Assembly is mechanical — sections are already verified individually. Last gate is the SKILL.md Self-Test as a whole-artifact check, catching anything that only surfaces when pages sit together.

## Required reading

- `.claude/reports/<short-name>/spec.md` (full, end-to-end re-read)
- SKILL.md Self-Test section (6-item battery)

## Output directory (final state)

```
.claude/reports/<short-name>/
  ├── spec.md           ← Preflight + Subject+Hero + Outline + Build log + Screenshots index
  ├── report.html       ← final assembled artifact
  ├── cover.html        ← Stage 4 standalone (kept for reference)
  └── screenshots/
      ├── fullpage.png
      ├── p1.png
      └── ... pN.png
```

## Process

1. Re-read spec.md end-to-end. Verify every Build log line exists (Stage 4 + Stage 5 / P2..PN).
2. Combine cover + all sections into `.claude/reports/<short-name>/report.html` if not already a single file.
3. Ensure shared `<head>` / `<style>` is at the top (font load, palette tokens, page CSS, print rules matching Preflight `print mode` axis).
4. Verify font-family chain (per the kit contract — lint enforced; `craft/typography.md` is the canon source): NO `-apple-system / sans-serif`-only fallback.
5. Run the 6 Self-Tests from SKILL.md against the final artifact:
   - 30-second scan
   - Title-only summary
   - Page-thumbnail legibility
   - Register coherence
   - Comparison eye-grab (if applicable)
   - Subject check (Self-Test #6)
6. Generate fullpage screenshot + per-page screenshots via Playwright into `.claude/reports/<short-name>/screenshots/`.
7. Append to spec.md Build log: `Stage 6: assembled, Self-Test pass <date>` and the Screenshots index block.
8. Show user the screenshots. Final approval.

## Output

```
FINAL: .claude/reports/<short-name>/
  report.html
  spec.md (Build log finalized)
  cover.html
  screenshots/fullpage.png + p1..pN.png
SELF-TEST: <pass | flag list>
```

## Verification gate

User final OK. If they flag a Self-Test failure that wasn't caught earlier:

- That is data — note which stage's verification should have caught it
- Loop on the FAILING STAGE, not a full re-render
- E.g., if Self-Test #6 (Subject check) fails → back to Stage 2 (subject lock) + Stage 3 (outline regenerate)
- If the failure traces to a Preflight axis (wrong page format, wrong register) → back to Stage 1 and revise the axis in spec.md, then re-walk

## Failure modes

- Skipping Self-Test "because each section already passed"
- Treating "user said OK" as license to merge / deploy (those are separate decisions outside this skill)
- Ignoring a Self-Test #6 (Subject check) flag because sections individually felt OK
- Generating screenshots but not showing them to user (final visual gate cannot be skipped — `feedback_visual_gate_only`)
- Leaving spec.md Build log incomplete — the next session will not be able to pick up cleanly
