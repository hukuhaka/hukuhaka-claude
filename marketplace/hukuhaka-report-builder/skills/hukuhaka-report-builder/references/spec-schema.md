# spec.md schema

Every report is built into its own directory:

```
.claude/reports/<short-name>/
  ├── spec.md           ← grows stage-by-stage; the lock record
  ├── report.html       ← final assembled artifact (Stage 5)
  ├── cover.html        ← Stage 3 standalone cover (kept for reference)
  └── screenshots/
      ├── fullpage.png
      ├── p1.png
      └── ... pN.png
```

spec.md is **born at Stage 0** under `.claude/reports/tmp-draft/` carrying only the `## Intake` block. Stage 1 **overwrites** it (full-file Write) with `## Intake` carried forward + a filled `## Preflight`. `<short-name>` is auto-derived in Stage 2 from SUBJECT (lowercase, hyphenated, ≤24 chars, no register suffix) and the directory is renamed `tmp-draft` → `<short-name>` then. Examples: `hpm-audit`, `vit-benchmark`, `q1-earnings`. User can override at Stage 2 gate.

## spec.md — full template (all stages appended)

```markdown
# <Subject short title> — <register> · <YYYY-MM-DD>

## Intake (Stage 0)

- subject material: <what the report is about — the thing itself, not its outputs>
- audience: <who flips it, in what context, for what decision>
- publication: <where/what form — internal web doc | customer PDF | embedded artifact | print | deck>

## Preflight (Stage 1 lock)

- kit: <geist>   # foundation kit (references/foundations/<kit>.css) — only geist in v1; untagged, not one of the 12 axes

### Required (rework cost: large)
- page format: <A4 794×1123 | Letter 816×1056 | 16:9 1280×720 | square 1080 | freeform>   [provenance: register-default | user]
- orientation: <portrait | landscape>   [provenance: register-default | user]
- page unit: multi-page-deck   [provenance: register-default]   # [DEFERRED: long-scroll, tabbed — craft assets do not yet support]
- color mode: <light | dark | both>   [provenance: kit-default | user]   # only values the kit's @kit-color-mode declares
- print mode: <print-ready | web-only>   [provenance: register-default | user]
- register: <analytic-dashboard | executive-brief | technical-audit | ir-deck | academic-poster | forensic-incident>   [provenance: user]

### Recommended (rework cost: partial)
- count: <1 | 3-4 | 5-7 | 8-12+>   [provenance: register-default | user]   # register-default when accepted as derived; user once adjusted
- language: <en | ko | mixed>   [provenance: user]
- brand layer: <none | wordmark | logo | watermark>   [provenance: kit-default | user]
- disclaimer policy: <none | standard | ir-mandated | confidential | audit-trail>   [provenance: register-default | user]
- versioning surface: <none | date | version | author+date>   [provenance: register-default | user]
- TOC: <none | cover-strip | dedicated-page>   [provenance: register-default | user]

### Auto (register-derived, no user decision)
- visual hierarchy depth (from register)
- asset budget per page (from register)
- page numbering style (from register)
- spacing scale: kit tokens --space-1..8 (foundations/<kit>.css) [SUPERSEDES the former register-locked 8-tier scale]
- section vs paragraph gap ratio (locked)

### Deferred (TBD — not enforced in v1)
- accessibility (color-blind safe / WCAG AA): TBD
- interactivity (hover / nav / animation): TBD (INHERITANCE BLOCKED — static scan artifact)
- distribution medium: TBD (covered partially by print mode)
- cover treatment variation: TBD (register-derived for now)

## Subject + Hero (Stage 2 lock)

- SUBJECT: <one sentence>
- HERO FINDING: <one sentence>
- short-name (derived): <kebab-case>

## Outline (Stage 2 lock)

- P1 COVER — identity only
- P2 <FINDING TITLE> — anchor: <what carries it>
- P3 <FINDING TITLE> — anchor: <what carries it>
- ...

## Build log (Stages 3-5 append)

- Stage 3: cover.html rendered, user OK <date>
- Stage 4 / P2: built + verified <date>
- Stage 4 / P3: ...
- Stage 5: assembled, Self-Test pass <date>

## Screenshots

- screenshots/fullpage.png
- screenshots/p1.png ... pN.png
```

## Rules

- **Intake rule (Stage 0)**: the `## Intake` block holds exactly 3 framings (`subject material` / `audience` / `publication`), each non-empty. They are the explicit INPUT to Stage 1 register inference — not the Subject (which is locked in Stage 2). spec.md is born at Stage 0 with this block alone; `validate-spec.sh` rejects a Stage-0 write whose framings are unfilled.
- **Determinism-split (Stage 1)**: the 9 mechanical axes (7 register-default + 2 kit-default) are table/kit-derived and recorded silently — same input → same value. Only the **judgment** choices (register pick) get the investigate→recommend→gate treatment. The analysis layer must NOT turn a mechanical axis into a per-report decision; that resurrects the output-variance the pinned-kit architecture exists to kill.
- **register↔kit invariant**: picking a register MUST NOT alter any kit token (palette, type, spacing). A register-keyed accent (e.g. "audit = ochre") is invention, not capture — the kit's tokens are fixed regardless of register. (Token re-derivation from a capture is a kit-registration concern, never a per-report or per-register tweak.)
- spec.md is **append-only within a stage** — a later stage does not edit an earlier stage's blocks. (Stage 1 is the exception: it overwrites the Stage-0 Intake-only file with a full Intake+Preflight write, so the hook's content-validation fires on the complete 12-axis block.)
- If a later stage discovers a Stage 1-2 lock is wrong, loop back to that stage and **edit the block there**, do not patch downstream.
- Every stage's first action: re-read spec.md. Drift across stages is the failure this file exists to prevent.
- Deferred axes (long-scroll / tabbed / accessibility / interactivity) MUST stay in the template as visible TBD markers — silent omission hides the missing capability from future readers.
- **Provenance rule**: every one of the 12 axes carries a provenance tag recording the SOURCE of its value — `kit-default` (read from the kit's `@kit-*` declarations), `register-default` (from the Stage 1 register-defaults table), or `user` (inferred from input or overridden at the gate). The tag records where the value came from, NOT the act of confirming it — batch-confirm does not flip an axis to `user`; only an explicit per-axis override (or per-axis inference, e.g. register/language) does.
- **Gate rule (fail closed)**: if any of the 12 axes is unrecorded — missing value OR missing provenance tag — Stage 1 cannot pass and spec.md must not be written. The `kit:` field is required but untagged; it is not counted among the 12.
