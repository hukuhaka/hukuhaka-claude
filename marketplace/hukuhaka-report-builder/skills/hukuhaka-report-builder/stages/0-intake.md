---
stage: 0
purpose: turn a natural-language request into 3 confirmed framings (subject material / audience / publication) that become the explicit input to Stage 1 register inference
prereq: user issued a report-shaped request (any of the SKILL.md triggers)
deliverable: .claude/reports/tmp-draft/spec.md created with ONLY the Intake block (3 framings)
verification_gate: user confirms/edits all 3 framings
---

## What this stage does

The real entry is a sentence — "이 프로젝트 코드구조 설명 문서 만들어줘", "write up the
Q1 benchmark", "audit this service". NOT a pre-classified `subject=code-analysis,
audience=engineer`. So Stage 0 does the classifying the user never types: it
**investigates the target briefly, then proposes the framing for confirmation**. This is
"I request / you analyze" — the report must be *well* made, which requires the framing to
match the user's actual intent before any layout decision is touched.

The 3 framings are NOT the Subject (that is locked in Stage 2). They are the inputs that
make Stage 1's register pick grounded instead of guessed.

## Process

1. **Detect intent + target.** From the request, identify what artifact the user wants and
   what it is about. If the request is too thin to frame (no identifiable subject), ask ONE
   clarifying question — otherwise proceed.

2. **Brief investigation.** Look at the target enough to frame it — no more. Reuse existing
   `.claude/` docs (`map.md`, `design.md`, `README`) when present rather than re-deriving;
   otherwise a light look at the relevant files/data. This is *brief* (orient, don't audit) —
   Stage 1 does the deeper look once the framing is fixed.

3. **Propose 3 framings**, each as a recommendation + 1-2 alternatives:
   - **subject material** — what the report is *about* (the thing itself, not its outputs or
     sources). One line.
   - **audience** — who flips it, in what context, for what decision (executive / engineering
     peer / researcher / regulator / customer / board / investor / oncall).
   - **publication** — where/what form (internal web doc / customer PDF / embedded artifact /
     print / deck).
   Where the input makes a framing obvious, state your pick with a 1-line rationale and move
   on; surface alternatives only where the choice is genuinely open.

4. **GATE** — show the 3 framings, ask: "Confirm all three, or correct any in one line."
   Iterate until confirmed.

5. **Write** `.claude/reports/tmp-draft/spec.md` with ONLY the `## Intake (Stage 0)` block
   per `references/spec-schema.md` (the 3 confirmed framings). spec.md is born here. The
   directory is `tmp-draft` (register is not known yet); Stage 2 renames it from SUBJECT.

## Required reading

- `references/spec-schema.md` — the Intake block shape (this stage produces it)

## Output (commit before Stage 1)

```
INTAKE confirmed:
  subject material: <one line>
  audience:         <one line>
  publication:      <one line>
SPEC: .claude/reports/tmp-draft/spec.md created (Intake block only)
```

## Verification gate

User confirms the 3 framings. The write is mechanically gated: `validate-spec.sh` (via the
PreToolUse hook) rejects a spec.md whose Intake framings are unfilled — so an
auto-filled-but-unconfirmed framing cannot silently slip to disk as a complete record.

## Failure modes

- Framing the **subject** as its outputs ("the docs HPM generates") instead of the thing
  itself ("HPM, the documentation orchestrator") — this is Self-Test #6, caught early here.
- Skipping the investigation and guessing the framing — the whole point is to ground it.
- Over-investigating — Stage 0 is brief; the deep read is Stage 1.
- Picking the register here — that is Stage 1. Stage 0 only fixes the *inputs* to that pick.
- Writing Subject/Hero/Outline content into the Intake block — hard boundary: Stage 0 + 1 =
  framing/spec only; Subject is Stage 2.
- Skipping the disk write — Stage 1 re-reads `tmp-draft/spec.md`; without it the chain breaks.
