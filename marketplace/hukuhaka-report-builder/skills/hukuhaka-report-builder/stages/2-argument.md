---
stage: 2
purpose: lock the report's argument — subject + hero finding + section outline — in one stage; commit to a single Hero before expanding it into section titles
prereq: Stage 1 Preflight block committed in .claude/reports/tmp-draft/spec.md
deliverable: spec.md Subject+Hero block AND Outline block appended; short-name finalized; directory renamed tmp-draft → <short-name>
verification_gate: user confirms subject + hero + outline read as ONE argument (combined gate at 2c; a lightweight subject/hero checkpoint precedes the outline at 2a)
---

## What this stage does

This is the **argument lock**. Everything later renders what is committed here; nothing here is
visual yet. Three things get locked, in a deliberate order:

- **Subject** — what the report is *about* (not its outputs, not its sources)
- **Hero finding** — the ONE takeaway a reader gets in 30 seconds of flipping
- **Outline** — the section titles whose sequence IS the report's argument

**The order is load-bearing: commit to one Hero first, then expand it into sections.** Drafting
sections before the Hero is fixed is how a report becomes a pile of sections with no spine — the
sections turn into the de-facto argument and the Hero is back-fitted to them. So `2a` locks
Subject + Hero behind a cheap checkpoint, and only then does `2b` derive the outline *from that
Hero*. A wrong Subject caught at the 2a checkpoint costs one sentence; caught after outlining it
costs the whole outline. `2c` is the one binding gate over the assembled argument.

short-name (kebab slug from SUBJECT) is also derived here — it becomes the report directory name.

## Required reading

- The Intake + Preflight blocks in `.claude/reports/tmp-draft/spec.md` (Stage 0 + 1 output) — re-read at stage start
- `references/spec-schema.md` — the Subject+Hero block AND the Outline block shapes (this stage produces both)

## Process

### 2a — Subject + Hero + short-name

1. Re-read the input through the Stage 1 register lens (already in spec.md).

2. Draft **Subject**:
   - Form: `<Project / phenomenon / event> — <category> — <one defining property>`
   - Refuse subjects that describe outputs (`a report about HPM's generated docs`) instead of the thing itself (`a report about HPM, the documentation orchestrator`). This is Self-Test #6 from SKILL.md.
   - Refuse subjects that span 2+ topics.

3. Draft **Hero finding**:
   - Form: one declarative sentence stating the takeaway.
   - Must be *defendable* — if a reader asks "is that true?" the rest of the report must prove it.
   - Must be *visual-renderable* — must translate to a hero number, KPI strip, or annotated chart on page 2.

4. Derive `<short-name>` from SUBJECT:
   - lowercase, kebab-case, ≤24 chars
   - drop articles ("the", "a", "an") and the register suffix (e.g., do NOT append `-audit`)
   - first 1-2 nouns from SUBJECT only — `hpm-architecture`, `vit-benchmark`, `q1-earnings`, `oct-2024-incident`
   - if SUBJECT has a project codename, use it (`hpm`, `vit`, `depth-anything`)

5. **Inline checkpoint** (the cheap catch before any outline work). Show SUBJECT + HERO FINDING + proposed `<short-name>` and ask: "Is this one sentence the trunk the whole report grows from? Correct any, or confirm to outline." Iterate ≤2 rounds; if it will not converge, the upstream is wrong (insufficient input data or wrong register → loop back to Stage 1). This is a lightweight checkpoint, NOT the binding gate — that is 2c.

6. On checkpoint confirm:
   - Rename `.claude/reports/tmp-draft/` → `.claude/reports/<short-name>/` (carries spec.md + the Stage-1 seed cover.html + screenshots).
   - Append the **Subject+Hero block** to spec.md per `references/spec-schema.md`.

### 2b — Outline (derive from the locked Hero)

7. Re-read spec.md. The Stage 1 `count` axis bounds your section count (1 → 1 surface; 3-4 → 3 sections; 5-7 → 4-6 sections; 8-12+ → 6-10 sections).

8. From the **now-locked Hero** + register, derive section titles within the count bound. Each must:
   - read as a claim, not a topic ("Determinism beats orchestration" not "Architecture")
   - extend or specialize the Hero finding (every section grows from the trunk locked in 2a)
   - have a visible page-defining anchor (hero number / chart / table / diagram / annotated figure)

9. For each section, draft 1 line stating what visual element carries the page (e.g., `page-2 anchor: 116px hero "11 of 14 paths" + 4-tile KPI strip`).

10. Order the titles so reading them top-to-bottom forms a connected argument. The 30-second flipper reads ONLY titles + page anchors — that sequence must deliver the case.

11. Cover page (P1) is identity-only — no finding, no anchor. List it but don't title it as a claim.

12. Append the **Outline block** to spec.md per `references/spec-schema.md`.

### 2c — Combined gate

13. Show the user the **whole argument together**: SUBJECT + HERO FINDING + the ordered title list with anchors. Ask:
    - "Read the titles top-to-bottom — do they form one argument?"
    - "Does every title grow from the Hero?"
    Subject and outline can be revised together here — they are one lock.

14. Loop-back targets:
    - a weak / topic title → loop on that one title; if the title is weak because the **Hero** is weak, revise 2a (the common case — the argument and its spine are coupled)
    - section count exceeds the `count` axis → trim / move to appendix, or loop to Stage 1 to revise the count axis
    - insufficient input data / wrong register pick → Stage 1

## Output (commit before Stage 3)

```
SHORT-NAME: <kebab-case>
SUBJECT: <one sentence>
HERO FINDING: <one sentence>
OUTLINE:
  P1 COVER — identity only (no finding)
  P2 <FINDING TITLE> — anchor: <what carries it>
  P3 <FINDING TITLE> — anchor: <what carries it>
  ...
SPEC: .claude/reports/<short-name>/spec.md appended (Subject+Hero block + Outline block)
```

## Verification gate

The binding confirmation is **2c** — the user reads Subject + Hero + Outline as one argument. The
2a inline checkpoint is a lightweight pre-outline catch, not the full gate. Iterate; if the
argument will not converge in ≤2 rounds, flag the upstream (Stage 1 register / input data) rather
than forcing it.

## Failure modes

- Subject phrased as a topic ("benchmarking", "the audit") or as the subject's *outputs* instead of a thing-with-property — Self-Test #6
- Subject and Hero finding describing different things (Subject = X, Hero = something about Y)
- Hero finding that is a question, a hedged claim, or a multi-clause sentence
- Hero finding that does not survive the "what does this look like as a 116px number" test
- short-name that includes the register suffix (`hpm-audit` is OK only if "audit" is part of the actual subject; otherwise drop it — register lives in spec.md, not the directory name)
- **Outlining before the Hero is locked** — sections become the de-facto argument and the Hero is back-fitted; the 2a → 2b order exists to prevent exactly this
- Topic titles ("Background", "Methodology", "Discussion") — rewrite as findings
- A section whose anchor is "prose" (nothing to land on at scan speed) — rework or fold into a neighbor
- Section count exceeds Preflight `count` axis — trim, appendix, or loop back to Stage 1 to revise the count axis
- Cover treated as a section with a finding (Cover is identity, not summary — `references/craft/cover.md`)
- Skipping the directory rename — leaves the stale `tmp-draft` path for later stages
