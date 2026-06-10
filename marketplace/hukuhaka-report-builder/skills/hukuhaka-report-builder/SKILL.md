---
name: hukuhaka-report-builder
description: "Build visual-first reports — artifacts read by SCANNING page-by-page, not top-to-bottom. Hero numbers, KPI tiles, charts, tables, and annotated diagrams carry the page; prose is reference, not narrative. Generates intentional standalone HTML — never blog-essays inside report wrappers, never PPT-as-HTML, never generic Tailwind-card internal-doc look. Triggers — ANY of: report, writeup, summary, audit, benchmark, comparison, analysis, brief, deck, dashboard, slides, presentation, poster, memo, postmortem, retrospective, scorecard, dossier, recap, overview, findings, evaluation, review, walkthrough, technical writeup, executive summary, status update, incident report. Registers (pick one per artifact, never blend): analytic dashboard, executive brief, technical audit, IR-style earnings deck, academic conference poster, status update, forensic incident report, research recap, customer-facing release notes. New registers extend by adding a row to the Stage-1 register-defaults table. Subjects: code / architecture audit, ML benchmark, model comparison, research finding, system performance, capacity report, A/B test result, financial metrics, ops postmortem, security incident, product launch recap, regulatory submission, infra inventory. Audiences: executive, engineering peer, researcher, regulator, customer, board, investor, oncall. Outputs HTML with hand-built CSS (no Tailwind, no UI library shell, no Mermaid). Typography, palette, and spacing are pinned by a foundation kit (v1: geist — Geist + Geist Mono); pages assemble from token-driven component fragments under references/components/. Skip when: long-form essay, blog post, marketing copy, API reference, changelog list, chat-style transcript, pure narrative documentation."
---

This skill guides creation of visual-first reports through a **staged workflow with user verification at each step**. A report's job is to deliver findings at the speed of *flipping pages*: the reader scans, the eye lands on hero numbers and charts, and prose is consulted only to look up a detail after the scan has already delivered the takeaway.

The skill operates as **Stage 0 intake + 5 build stages**, each producing a single small deliverable and surfacing it for user verification before the next stage begins. This replaces the "generate the whole report and hand it over" pattern that loses 3-5 decisions per render to LLM convergence — instead, decisions are made one at a time with the user in the loop, and any decision can be revised without invalidating the others.

The real entry is a natural-language request ("write up the Q1 benchmark", "audit this service", "이 프로젝트 코드구조 설명 문서 만들어줘") — NOT pre-classified material. So the skill opens with **"I request / you analyze"**: Stage 0 investigates the target briefly and proposes 3 framings (subject material / audience / publication) for confirmation; Stage 1 reads deeper and turns the framings into a locked spec. The user never fills a form — they confirm a grounded proposal.

## Workflow

Run the stages in order. Do NOT batch stages. The verification gate at the end of each stage is non-optional — it catches the failure modes that compound across pages when skipped.

| # | File | Purpose | Verification gate |
|---|---|---|---|
| 0 | `stages/0-intake.md` | Brief investigation → propose 3 framings (subject material / audience / publication); spec.md born at `.claude/reports/tmp-draft/` with the Intake block | User confirms/edits the 3 framings |
| 1 | `stages/1-pick-kit.md` | Read deeper, pick register (judgment), derive the other 11 axes deterministically, render a register-identity seed; overwrite spec.md with Intake + Preflight | User approves the RECEIPT (12-axis checklist + register + rendered seed); FAIL CLOSED on any unrecorded axis |
| 2 | `stages/2-argument.md` | Argument lock: Subject + Hero finding (2a, with an inline checkpoint) → Outline derived from the Hero (2b) → combined gate (2c); appends Subject+Hero + Outline blocks, renames `tmp-draft` | User confirms subject + hero + outline form one argument |
| 3 | `stages/3-build-cover.md` | Inherit the Stage-1 seed `cover.html` and complete it with the locked Subject/Hero, screenshot | User confirms 3-second register identity |
| 4 | `stages/4-build-section.md` | Build one section from matching component fragments, append to report.html, screenshot, verify, loop | Per-section user confirmation (no batching) |
| 5 | `stages/5-assemble.md` | Finalize directory + Self-Test + screenshots | User final OK after Self-Test |

**Open the stage file BEFORE executing that stage.** Do not work from memory. Each stage file has its own prereq / deliverable / process / failure-modes that the skill body cannot replicate without going stale.

**When a later stage uncovers a decision that should have been made earlier, loop back to the failing stage** — do not patch the symptom in the current stage. Example: if Stage 4 keeps producing prose-shaped sections, the failure is Stage 2 (outline titles weren't claim-shaped). Fix Stage 2, then re-walk forward. The cost of replaying 1-2 cheap stages beats the cost of fighting symptoms downstream.

The workflow is the skill. Skipping the gates — "I'll generate the whole thing and show you the result" — is the failure mode this skill exists to prevent.

## Output directory

Each report is built into its own directory. Locks and the artifact live together so a future session can pick up cleanly.

```
.claude/reports/<short-name>/
  ├── spec.md           ← Intake (Stage 0) + Preflight (Stage 1) + Subject+Hero + Outline + Build log (grows stage-by-stage)
  ├── report.html       ← final assembled artifact (Stage 5)
  ├── cover.html        ← Stage-1 seed, completed at Stage 3 (kept for reference)
  └── screenshots/
      ├── fullpage.png
      └── p1.png ... pN.png
```

`spec.md` is **born at Stage 0** under `.claude/reports/tmp-draft/` (Intake block only), overwritten by Stage 1 (Intake + Preflight). `<short-name>` is derived from SUBJECT in Stage 2 (kebab-case, ≤24 chars, no register suffix); the directory is renamed `tmp-draft` → `<short-name>` on user confirm.

`spec.md` is the lock record — every stage's first action is to re-read it. See `references/spec-schema.md` for the full template.

## Report Thinking (primitives the stages consume)

Stages 1-2 commit these primitives; Stages 3-5 honor them.

- **Subject** (locked Stage 2): what the report is *about* in a single sentence. A report about HPM is not a report about HPM's outputs; a report about ViT is not a report about ML benchmarking in general. Confusing the subject with its inputs, outputs, or surrounding domain produces drift by page 2 — the surest sign is a section narrating "what X produces" when the report should be describing X itself.
- **Register** (locked Stage 1): one of *analytic-dashboard / executive-brief / technical-audit / IR-deck / academic-poster / forensic-incident*, or one of the deferred-lock registers (status-update / research-recap / customer-facing-release-notes). Each has its own scan rhythm, density, chart-vs-prose ratio, and tonal authority. Blending registers is the default failure mode — pick one and execute it with conviction.
- **Hero finding** (locked Stage 2): the ONE takeaway someone gets after 30 seconds of flipping, in one declarative sentence. If it does not survive the "what does this look like as a 116px hero number" test, it is not yet a hero finding.
- **Data shape**: what numbers, charts, comparisons, or diagrams actually carry each finding. Where does prose end and visual begin? In a real report the honest answer is "prose ends almost immediately."
- **Audience contract**: who flips, in what context, for what decision. An executive flipping pre-meeting reads different from an engineer auditing post-incident.

CRITICAL: a well-executed *brief* beats a half-blended brief-dashboard. The default LLM failure is to produce a "report-shaped wrapper with paragraph content" — cover page + TOC + numbered sections, but every section is essay prose. Refuse this. The register must show on every page, not only in the chrome.

## Visual-First Craft (principles, applied across Stages 3-4)

The stages reference these principles when building cover and sections. The concrete decisions behind each principle are already baked into the kit tokens (`references/foundations/<kit>.css`) and the component fragments (`references/components/`); the cited craft file is the canon source, read at kit-registration / fragment-authoring time (each file's `read_when` says when) plus the named build-time judgment scopes.

- **Cover is identity, not summary.** The cover answers "what is this?" at a glance — name + brief tagline. A reader should identify the project in 3 seconds. See `references/craft/cover.md` for scale (the 1/3 rule), forbidden patterns, and tagline craft.

- **Section titles are findings, not topics.** Section headers must read as *claims*. "ViT surpasses ResNet at JFT-300M scale" earns a section; "Empirical behavior" is a placeholder. If you cannot phrase the title as a finding, the section should not exist — fold it into a more meaningful neighbor. The set of section titles read in sequence should form the argument of the report. Within sections that contain both figure and prose, the figure leads (top of section), prose follows as brief support — prose-then-figure is essay-shaped.

- **Hero numbers carry the page.** Every section, ideally every page, has at least one number large enough to be legible from across a room. KPI tiles, oversized headline numbers, large stat-cards. Use `font-variant-numeric: tabular-nums` for every metric. Decoration on a hero number weakens it; let weight, scale, and contrast do the work. See `references/craft/kpi-tiles.md` for the size ladder, tile structure, and unit placement.

- **Charts and tables are content, not garnish.** A chart that could be replaced by one sentence is chart-junk. Every chart answers a question prose cannot answer as efficiently. Annotate the inflection point or the bar that matters; don't make the reader hunt. Strip defaults — no 3D, no gradients on bars, no chart-junk borders, no legend if direct labels work. See `references/craft/charts.md` and `references/craft/tables.md`.

- **Comparisons need committed semantic color.** When the report compares two things (before/after, A/B, baseline/proposed), assign each a fixed color and use it everywhere — chart bars, table cells, callout borders, badges, legend chips. The eye must grab the *winner* without reading labels. See `references/craft/color.md` for the three-layer palette and per-register guidance.

- **Scan rhythm comes from density variation.** A scan-read artifact needs *pace*: alternate dense (data table, chart cluster, KPI strip) with breathable (single hero number on a near-empty band). All-equal-density pages look identical — the eye has no anchor and skips. Vary deliberately, not randomly. See `references/craft/spacing.md`.

- **Prose is reference, not narrative.** When prose appears, treat it like a caption or sidebar: short, dense, factual. Long paragraphs in a report are read by no one. Findings that need explanation should structure as *bullet → expansion → callout*, not as essay paragraphs. If you find yourself writing transitional sentences ("First, we examined... Then we considered..."), you have drifted into blog mode — stop and restructure. See `references/craft/callouts.md`.

NEVER produce: blog-essay rhetorical structure (intro / body / conclusion paragraphs). Report-shape *wrappers* (cover page + TOC + numbered sections) wrapped around essay-prose content. Cliché chart styling (rainbow palettes, 3D pie, drop-shadowed bars, gradient fills on data). Centered hero with marketing-tagline subtitle. Mermaid diagrams or auto-generated icons — hand-author SVG instead (see `references/craft/diagrams.md`). Equal-weight section/subsection/sub-subsection — flat hierarchy gives the eye no scan path. The generic Tailwind-card "internal-doc" look — slate-200 borders, rounded-2xl, gray-500 muted text.

**IMPORTANT**: match implementation complexity to the register. A *brief* is short, dense, and severe — minimal chrome, three pages, every word earns space. A *dashboard* is grid-heavy with many small data units. An *audit* threads diagrams between findings. A *poster* is one dense surface, no scroll. Picking the register is picking the implementation effort.

## Self-Test (Stage 5 applies these)

After rendering, open the HTML and apply these tests yourself. Failing any one means rework — do not deliver.

1. **30-second scan**: flip page-by-page at ~3 seconds per page without reading. Can you state every key finding from visual alone? If findings live inside paragraphs, restructure them as hero numbers, KPI tiles, or annotated charts.
2. **Title-only summary**: read only the section titles top-to-bottom. Do they form a coherent argument? If titles are topic labels ("Background", "Methodology", "Discussion"), the report is structured as an essay; rewrite titles as findings.
3. **Page-thumbnail legibility**: zoom the page to where text is unreadable. Can you still identify which register this is, where the hero numbers are, and which page is which? If pages look uniformly gray, density variation is missing.
4. **Register coherence**: can a reader name the register from any single page in isolation? If the cover screams "brief" but page 3 looks like a dashboard, recommit and rerun.
5. **Comparison eye-grab**: if the report compares two things, can the reader see the winner of each comparison without reading any label? If not, semantic color is not committed.
6. **Subject check**: state the report's subject in one sentence. Does every section relate to *the subject*, not to its outputs or sources? If a section reads as "about [output of subject]" — e.g., a report about a documentation-generation plugin that ends up narrating the documents the plugin produces — the meta-frame is wrong. Rewrite the section to be about the subject's relationship to those outputs, not the outputs themselves.

A Self-Test failure flagged at Stage 5 that was not caught earlier means the failing stage's verification gate needs strengthening — loop back to that stage, not full re-render.

## Implementation Notes (cross-cutting rules — apply in any stage)

- **Determinism-split (Stage 0/1).** The setup axes split into two kinds and are handled differently. **Mechanical axes** — the 7 register-default + 2 kit-default axes — are table/kit-derived and recorded *silently*: same input → same value. **Judgment** — the register pick (and Subject/Hero/Outline in later stages) — gets investigate→recommend→gate. The new analysis layer attaches ONLY to judgment; turning a mechanical axis into a per-report pros/cons decision re-improvises the layer the pinned kit exists to make deterministic. "Confident → auto-decide" means *table-derivable*, not gut.
- **register↔kit invariant.** Picking a register MUST NOT alter any kit token (palette, type, spacing). A register-keyed accent ("audit = ochre") is invention, not capture — the kit is fixed regardless of register. Token derivation is a kit-registration concern (`foundations/REGISTER.md`), never a per-report or per-register tweak.
- **Assemble, don't improvise.** Pages are built from `references/components/` fragments + `references/foundations/<kit>.css` tokens. No Tailwind, no UI-library shell. Never restyle a fragment per report; never introduce non-token colors, spacing, or type sizes. If no fragment fits a section's anchor, flag the gap to the user instead of hand-building — the generic "AI internal-doc" look lives in improvised CSS, and the kit exists so none gets written.
- **Spec-lock is hook-enforced.** A PreToolUse hook (`hooks/hooks.json` → `scripts/hook-validate-spec.sh` → `validate-spec.sh`) denies a write of an incomplete `spec.md` and denies building `cover.html`/`report.html` against an unlocked spec. The gates below are not honor-system at the spec boundary — they fail closed by construction. (The hook enforces record-completeness, not that the user was consulted; the human gate still matters.)
- Hand-author SVG for any diagram *content*. Never Mermaid in this context. `components/diagram.html` carries the stroke / label / annotation conventions; `references/craft/diagrams.md` is the canon source.
- Charts assemble from `components/chart-{bar,line,stacked}.html` — CSS bars + inline SVG, no charting library. The section's message type picks the fragment (RANKING → bar, CHANGE-OVER-TIME → line, PART-TO-WHOLE → stacked; each fragment's header comment says so). Axis / annotation judgment: `references/craft/charts.md`.
- Typography is pinned by the kit — use `var(--sans)` / `var(--mono)` / `var(--serif)`, never a raw `font-family` value. **Inter is FORBIDDEN anywhere in a chain** and chains must end in a generic family — both lint-enforced (`scripts/lint-foundation.sh`, `scripts/lint-components.sh`).
- Color comes from kit tokens, already split into three layers (chrome / semantic / accent) in `foundations/<kit>.css`. Never raw hex/rgb/hsl in a report. Comparison pairs bind to the kit's accent tokens consistently across every surface — semantic-assignment judgment: `references/craft/color.md`.
- Spacing uses kit tokens `--space-1..8`, never one-off values. Section gap must exceed paragraph gap by at least 2 tiers. Per-register margins + density rhythm judgment: `references/craft/spacing.md`.
- Code blocks (audit / incident registers): start from `components/code-block.html`.
- Color mode is a kit declaration (`@kit-color-mode`, read at Stage 1 as axis #4). A kit declaring `light` has no dark toggle — dark is a separate kit file, not a per-report variant.
- **Verify named entities against source.** Every command name, file path, agent name, class, API, version number, or count you cite must be confirmed by reading or grepping the actual source before printing. Memory and inference are not verification — they invent confidence the artifact does not earn. If you are not sure of a name, omit the citation or mark it explicitly as uncertain rather than fabricate one.

## References

`stages/` holds the workflow protocol. `references/foundations/` + `references/components/` hold the kit assets reports assemble from. `references/craft/` holds the craft canon, consumed at kit-registration / fragment-authoring time.

**`stages/`** — workflow steps. Open each stage file when entering that stage.
- `stages/0-intake.md` — brief investigation → 3 framings (subject material / audience / publication); spec.md born with the Intake block
- `stages/1-pick-kit.md` — deeper read, register pick (judgment), 11 axes derived deterministically, register-identity seed render, receipt gate; overwrites spec.md with Intake + Preflight
- `stages/2-argument.md` — argument lock: subject + hero finding (inline checkpoint) → outline derived from the hero → combined gate; appends Subject+Hero + Outline blocks + `tmp-draft` rename
- `stages/3-build-cover.md` — inherit the Stage-1 seed cover.html, complete with locked Subject/Hero + screenshot gate
- `stages/4-build-section.md` — per-section fragment-assembly loop with per-section gate
- `stages/5-assemble.md` — final assembly + Self-Test + user OK

**`references/spec-schema.md`** — the spec.md template. Born at `stages/0-intake.md` (Intake block), filled by `stages/1-pick-kit.md` (Preflight), re-read by every later stage (drift control). The Intake block holds 3 framings; each of the 12 Preflight axes carries a provenance tag (`kit-default` / `register-default` / `user`). It is the contract source for `scripts/validate-spec.sh`.

**`references/foundations/`** — one CSS file per kit; the only place design-system values live.
- `foundations/_schema.md` — the token contract every kit must satisfy (55 required tokens, oklch-only, kit declarations)
- `foundations/geist.css` — the v1 kit (Geist / Geist Mono / Source Serif 4)
- `foundations/REGISTER.md` — procedure for registering a new kit from a DESIGN capture; the only place design-system judgment happens

**`references/components/`** — 15 token-driven HTML fragments + `_base.css`. Reports copy a fragment and pour content; fragments are never restyled per report.
- `components/spec-sheet.html` — generated catalog of every fragment (`scripts/build-spec-sheet.sh <kit>`); regenerate, never hand-edit

**`scripts/`** — mechanical contract checks.
- `scripts/lint-foundation.sh <kit.css>` — token contract + kit declarations
- `scripts/lint-components.sh` — fragment token purity + class drift
- `scripts/build-spec-sheet.sh <kit>` — spec-sheet generator; reused to verify a kit swap renders cleanly
- `scripts/validate-spec.sh [--require=intake,preflight] [<spec.md>]` — spec completeness gate (present-blocks-only; stage self-check + backs the PreToolUse hook). The hook wrapper `hook-validate-spec.sh` lives at the plugin root (`${CLAUDE_PLUGIN_ROOT}/scripts/`), wired by `hooks/hooks.json`.

**`references/craft/`** — craft canon. NOT read during report builds, except for the judgment scopes named in each file's `read_when` frontmatter.
- `craft/typography.md` / `craft/color.md` / `craft/spacing.md` — normalization rule sources for kit registration (`foundations/REGISTER.md` Step 2). Build-time judgment scopes: semantic-color assignment (color.md), per-register margins + density rhythm (spacing.md); typography.md has none (fully baked into kit chains)
- `craft/cover.md` / `craft/kpi-tiles.md` / `craft/tables.md` / `craft/charts.md` / `craft/diagrams.md` / `craft/callouts.md` / `craft/code-blocks.md` — baked into the matching fragment's code + comments at authoring time. Build-time judgment scopes: 1/3 scale rule + tagline craft (cover.md, Stage 3); density / per-register choice (the rest, Stage 4)

**`references/fixtures/{source}/`** — captured aesthetic systems. Currently `fixtures/figma/` (marketing-site applicability — usually NOT applied to data reports; v5 isolation test confirmed subagents correctly skip it for analytic registers). Each sub-file declares `applicability` in frontmatter; skip sub-files whose applicability does not match your register. **Mine, never clone.** (Not staged in this variant directory — capture sources feed `foundations/REGISTER.md`, not report builds.)

Remember: a report's quality is measured by what the reader takes away in 30 seconds of flipping. Optimize for *that*, not for completeness, not for polish, not for word count. A short, severe, legible report beats a thorough, polished, unscanned one.
