---
stage: 2
purpose: commit subject + hero finding (1 sentence each) and finalize the report short-name
prereq: Stage 1 Preflight block committed in spec.md
deliverable: spec.md Subject+Hero block appended; short-name finalized (directory renamed if needed)
verification_gate: user reads both sentences + short-name, confirms or rewords
---

## What this stage does

Three locks that anchor every later page:

- **Subject** — what the report is *about* (not about its outputs, not about its sources)
- **Hero finding** — the ONE takeaway a reader gets in 30 seconds of flipping
- **short-name** — kebab-case slug derived from SUBJECT; becomes the report directory name

## Required reading

- The Preflight block in `.claude/reports/<tmp-name>/spec.md` (Stage 1 output)
- `references/spec-schema.md` — Subject+Hero block shape

## Process

1. Re-read the input through the Stage 1 register lens (already in spec.md).

2. Draft Subject:
   - Form: "<Project / phenomenon / event> — <category> — <one defining property>"
   - Refuse subjects that describe outputs (`a report about HPM's generated docs`) instead of the thing itself (`a report about HPM, the documentation orchestrator`). This is Self-Test #6 from SKILL.md
   - Refuse subjects that span 2+ topics

3. Draft Hero finding:
   - Form: one declarative sentence stating the takeaway
   - Must be *defendable* — if a reader asks "is that true?" the rest of the report must prove it
   - Must be *visual-renderable* — must translate to a hero number, KPI strip, or annotated chart on page 2

4. Derive `<short-name>` from SUBJECT:
   - lowercase, kebab-case, ≤24 chars
   - drop articles ("the", "a", "an") and the register suffix (e.g., do NOT append `-audit`)
   - first 1-2 nouns from SUBJECT only — `hpm-architecture`, `vit-benchmark`, `q1-earnings`, `oct-2024-incident`
   - if SUBJECT has a project codename, use it (`hpm`, `vit`, `depth-anything`)

5. Show user: SUBJECT + HERO FINDING + proposed `<short-name>`. Ask: "All three correct?"

6. On user OK:
   - Rename `.claude/reports/<tmp-name>/` → `.claude/reports/<short-name>/` if changed
   - Append Subject+Hero block to spec.md per `references/spec-schema.md`

## Output (commit before Stage 3)

```
SHORT-NAME: <kebab-case>
SUBJECT: <one sentence>
HERO FINDING: <one sentence>
SPEC: .claude/reports/<short-name>/spec.md appended
```

## Verification gate

User says "OK" or proposes edits. Iterate ≤2 rounds before flagging an upstream problem (insufficient input data, wrong register pick → loop back to Stage 1).

## Failure modes

- Subject phrased as a topic ("benchmarking", "the audit") instead of a thing-with-property
- Hero finding that is a question, a hedged claim, or a multi-clause sentence
- Hero finding that does not survive the "what does this look like as a 116px number" test
- Subject and hero finding describing different things (Subject = X, Hero finding = something about Y)
- short-name that includes the register suffix (`hpm-audit` is OK only if "audit" is part of the actual subject; otherwise drop it — register is in the spec.md, not the directory name)
- Skipping the directory rename — leaves stale `tmp-<register>` path for later stages
