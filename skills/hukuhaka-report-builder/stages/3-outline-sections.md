---
stage: 3
purpose: produce the section title list (3-10 titles), each a finding-shape claim
prereq: Stage 2 Subject+Hero block committed in spec.md; short-name finalized
deliverable: spec.md Outline block appended (section titles + per-section anchor)
verification_gate: user reads the list top-to-bottom, confirms it forms an argument
---

## What this stage does

Section titles read in sequence ARE the argument of the report. If the titles do not form an argument, the report is structurally broken — fix it here, not after rendering.

## Required reading

- `.claude/reports/<short-name>/spec.md` (re-read at stage start — Preflight register/count + Subject/Hero anchor every title)
- `references/spec-schema.md` — Outline block shape

## Process

1. Re-read spec.md. The Stage 1 `count` axis bounds your section count (1 → 1 surface; 3-4 → 3 sections; 5-7 → 4-6 sections; 8-12+ → 6-10 sections).

2. From hero finding + register, derive section titles within the count bound. Each must:
   - read as a claim, not a topic ("Determinism beats orchestration" not "Architecture")
   - extend or specialize the hero finding
   - have a visible page-defining anchor (hero number / chart / table / diagram / annotated figure)

3. For each section, draft 1 line stating what visual element carries the page (e.g., `page-2 anchor: 116px hero "11 of 14 paths" + 4-tile KPI strip`).

4. Order the titles so reading them top-to-bottom forms a connected argument. The 30-second flipper reads ONLY titles + page anchors — that sequence must deliver the case.

5. Cover page (P1) is identity-only — no finding, no anchor. List it but don't title it as a claim.

6. On user OK, append Outline block to spec.md per `references/spec-schema.md`.

## Output (commit before Stage 4)

```
SPEC: .claude/reports/<short-name>/spec.md appended
OUTLINE:
  P1 COVER — identity only (no finding)
  P2 <FINDING TITLE> — anchor: <what carries it>
  P3 <FINDING TITLE> — anchor: <what carries it>
  ...
```

## Verification gate

User reads titles top-to-bottom. Does the argument hold? If "no" or "one of these is weak": loop on that one title, do not proceed to cover.

## Failure modes

- Topic titles ("Background", "Methodology", "Discussion") — rewrite as findings
- Section count exceeds Preflight `count` axis (split into appendix or trim, or loop back to Stage 1 to revise the count axis)
- A section whose anchor is "prose" (nothing to land on at scan speed) — rework or fold into a neighbor
- Cover treated as a section with a finding (Cover is identity, not summary — `references/craft/cover.md`)
