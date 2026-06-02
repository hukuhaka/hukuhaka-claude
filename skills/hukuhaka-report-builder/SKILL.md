---
name: hukuhaka-report-builder
description: "Build visual-first reports — artifacts read by SCANNING page-by-page, not top-to-bottom. Hero numbers, KPI tiles, charts, tables, and annotated diagrams carry the page; prose is reference, not narrative. Generates intentional standalone HTML — never blog-essays inside report wrappers, never PPT-as-HTML, never generic Tailwind-card internal-doc look. Triggers — ANY of: report, writeup, summary, audit, benchmark, comparison, analysis, brief, deck, dashboard, slides, presentation, poster, memo, postmortem, retrospective, scorecard, dossier, recap, overview, findings, evaluation, review, walkthrough, technical writeup, executive summary, status update, incident report. Registers (pick one per artifact, never blend): analytic dashboard, executive brief, technical audit, IR-style earnings deck, academic conference poster, status update, forensic incident report, research recap, customer-facing release notes. New registers extend by adding a craft lock under references/craft/. Subjects: code / architecture audit, ML benchmark, model comparison, research finding, system performance, capacity report, A/B test result, financial metrics, ops postmortem, security incident, product launch recap, regulatory submission, infra inventory. Audiences: executive, engineering peer, researcher, regulator, customer, board, investor, oncall. Outputs HTML with hand-built CSS (no Tailwind, no UI library shell, no Mermaid). Locked typography defaults to Geist + Geist Mono; register-specific deviations under references/craft/. Skip when: long-form essay, blog post, marketing copy, API reference, changelog list, chat-style transcript, pure narrative documentation."
---

This skill guides creation of visual-first reports through a **staged workflow with user verification at each step**. A report's job is to deliver findings at the speed of *flipping pages*: the reader scans, the eye lands on hero numbers and charts, and prose is consulted only to look up a detail after the scan has already delivered the takeaway.

The skill operates in **6 stages**, each producing a single small deliverable and surfacing it for user verification before the next stage begins. This replaces the "generate the whole report and hand it over" pattern that loses 3-5 decisions per render to LLM convergence — instead, decisions are made one at a time with the user in the loop, and any decision can be revised without invalidating the others.

The user provides report material: data, findings, code analysis, benchmark results, audit notes, research output. They may include audience (executive, engineering peer, customer, regulator) and the publication context (internal doc, customer-facing PDF, embedded artifact).

## Workflow

Run the stages in order. Do NOT batch stages. The verification gate at the end of each stage is non-optional — it catches the failure modes that compound across pages when skipped.

| # | File | Purpose | Verification gate |
|---|---|---|---|
| 1 | `stages/1-preflight.md` | Lock the 12-axis format spec (6 required + 6 recommended), create `.claude/reports/<short-name>/spec.md` | User confirms each axis (or accepts defaults) |
| 2 | `stages/2-lock-subject.md` | Subject (1 sentence) + Hero finding (1 sentence) + finalize short-name | User confirms all three |
| 3 | `stages/3-outline-sections.md` | Section titles + per-section anchor, appended to spec.md | User confirms titles form an argument |
| 4 | `stages/4-build-cover.md` | Render cover-only HTML to `.claude/reports/<short-name>/cover.html`, screenshot | User confirms 3-second register identity |
| 5 | `stages/5-build-section.md` | Build one section, append to report.html, screenshot, verify, loop | Per-section user confirmation (no batching) |
| 6 | `stages/6-assemble.md` | Finalize directory + Self-Test + screenshots | User final OK after Self-Test |

**Open the stage file BEFORE executing that stage.** Do not work from memory. Each stage file has its own prereq / deliverable / process / failure-modes that the skill body cannot replicate without going stale.

**When a later stage uncovers a decision that should have been made earlier, loop back to the failing stage** — do not patch the symptom in the current stage. Example: if Stage 5 keeps producing prose-shaped sections, the failure is Stage 3 (outline titles weren't claim-shaped). Fix Stage 3, then re-walk forward. The cost of replaying 1-2 cheap stages beats the cost of fighting symptoms downstream.

The workflow is the skill. Skipping the gates — "I'll generate the whole thing and show you the result" — is the failure mode this skill exists to prevent.

## Output directory

Each report is built into its own directory. Locks and the artifact live together so a future session can pick up cleanly.

```
.claude/reports/<short-name>/
  ├── spec.md           ← Preflight + Subject+Hero + Outline + Build log (grows stage-by-stage)
  ├── report.html       ← final assembled artifact (Stage 6)
  ├── cover.html        ← Stage 4 standalone (kept for reference)
  └── screenshots/
      ├── fullpage.png
      └── p1.png ... pN.png
```

`<short-name>` is derived from SUBJECT in Stage 2 (kebab-case, ≤24 chars, no register suffix). Stage 1 uses a `tmp-<register>` placeholder; Stage 2 renames the directory on user confirm.

`spec.md` is the lock record — every stage's first action is to re-read it. See `references/spec-schema.md` for the full template.

## Report Thinking (primitives the stages consume)

Stages 1-3 commit these primitives; Stages 4-6 honor them.

- **Subject** (locked Stage 2): what the report is *about* in a single sentence. A report about HPM is not a report about HPM's outputs; a report about ViT is not a report about ML benchmarking in general. Confusing the subject with its inputs, outputs, or surrounding domain produces drift by page 2 — the surest sign is a section narrating "what X produces" when the report should be describing X itself.
- **Register** (locked Stage 1): one of *analytic-dashboard / executive-brief / technical-audit / IR-deck / academic-poster / forensic-incident*, or one of the deferred-lock registers (status-update / research-recap / customer-facing-release-notes). Each has its own scan rhythm, density, chart-vs-prose ratio, and tonal authority. Blending registers is the default failure mode — pick one and execute it with conviction.
- **Hero finding** (locked Stage 2): the ONE takeaway someone gets after 30 seconds of flipping, in one declarative sentence. If it does not survive the "what does this look like as a 116px hero number" test, it is not yet a hero finding.
- **Data shape**: what numbers, charts, comparisons, or diagrams actually carry each finding. Where does prose end and visual begin? In a real report the honest answer is "prose ends almost immediately."
- **Audience contract**: who flips, in what context, for what decision. An executive flipping pre-meeting reads different from an engineer auditing post-incident.

CRITICAL: a well-executed *brief* beats a half-blended brief-dashboard. The default LLM failure is to produce a "report-shaped wrapper with paragraph content" — cover page + TOC + numbered sections, but every section is essay prose. Refuse this. The register must show on every page, not only in the chrome.

## Visual-First Craft (principles, applied across Stages 4-5)

The stages reference these principles when building cover and sections. Each principle points to its craft lock file for the concrete decisions.

- **Cover is identity, not summary.** The cover answers "what is this?" at a glance — name + brief tagline. A reader should identify the project in 3 seconds. See `references/craft/cover.md` for scale (the 1/3 rule), forbidden patterns, and tagline craft.

- **Section titles are findings, not topics.** Section headers must read as *claims*. "ViT surpasses ResNet at JFT-300M scale" earns a section; "Empirical behavior" is a placeholder. If you cannot phrase the title as a finding, the section should not exist — fold it into a more meaningful neighbor. The set of section titles read in sequence should form the argument of the report. Within sections that contain both figure and prose, the figure leads (top of section), prose follows as brief support — prose-then-figure is essay-shaped.

- **Hero numbers carry the page.** Every section, ideally every page, has at least one number large enough to be legible from across a room. KPI tiles, oversized headline numbers, large stat-cards. Use `font-variant-numeric: tabular-nums` for every metric. Decoration on a hero number weakens it; let weight, scale, and contrast do the work. See `references/craft/kpi-tiles.md` for the size ladder, tile structure, and unit placement.

- **Charts and tables are content, not garnish.** A chart that could be replaced by one sentence is chart-junk. Every chart answers a question prose cannot answer as efficiently. Annotate the inflection point or the bar that matters; don't make the reader hunt. Strip defaults — no 3D, no gradients on bars, no chart-junk borders, no legend if direct labels work. See `references/craft/charts.md` and `references/craft/tables.md`.

- **Comparisons need committed semantic color.** When the report compares two things (before/after, A/B, baseline/proposed), assign each a fixed color and use it everywhere — chart bars, table cells, callout borders, badges, legend chips. The eye must grab the *winner* without reading labels. See `references/craft/color.md` for the three-layer palette and per-register guidance.

- **Scan rhythm comes from density variation.** A scan-read artifact needs *pace*: alternate dense (data table, chart cluster, KPI strip) with breathable (single hero number on a near-empty band). All-equal-density pages look identical — the eye has no anchor and skips. Vary deliberately, not randomly. See `references/craft/spacing.md`.

- **Prose is reference, not narrative.** When prose appears, treat it like a caption or sidebar: short, dense, factual. Long paragraphs in a report are read by no one. Findings that need explanation should structure as *bullet → expansion → callout*, not as essay paragraphs. If you find yourself writing transitional sentences ("First, we examined... Then we considered..."), you have drifted into blog mode — stop and restructure. See `references/craft/callouts.md`.

NEVER produce: blog-essay rhetorical structure (intro / body / conclusion paragraphs). Report-shape *wrappers* (cover page + TOC + numbered sections) wrapped around essay-prose content. Cliché chart styling (rainbow palettes, 3D pie, drop-shadowed bars, gradient fills on data). Centered hero with marketing-tagline subtitle. Mermaid diagrams or auto-generated icons — hand-author SVG instead (see `references/craft/diagrams.md`). Equal-weight section/subsection/sub-subsection — flat hierarchy gives the eye no scan path. The generic Tailwind-card "internal-doc" look — slate-200 borders, rounded-2xl, gray-500 muted text.

**IMPORTANT**: match implementation complexity to the register. A *brief* is short, dense, and severe — minimal chrome, three pages, every word earns space. A *dashboard* is grid-heavy with many small data units. An *audit* threads diagrams between findings. A *poster* is one dense surface, no scroll. Picking the register is picking the implementation effort.

## Self-Test (Stage 6 applies these)

After rendering, open the HTML and apply these tests yourself. Failing any one means rework — do not deliver.

1. **30-second scan**: flip page-by-page at ~3 seconds per page without reading. Can you state every key finding from visual alone? If findings live inside paragraphs, restructure them as hero numbers, KPI tiles, or annotated charts.
2. **Title-only summary**: read only the section titles top-to-bottom. Do they form a coherent argument? If titles are topic labels ("Background", "Methodology", "Discussion"), the report is structured as an essay; rewrite titles as findings.
3. **Page-thumbnail legibility**: zoom the page to where text is unreadable. Can you still identify which register this is, where the hero numbers are, and which page is which? If pages look uniformly gray, density variation is missing.
4. **Register coherence**: can a reader name the register from any single page in isolation? If the cover screams "brief" but page 3 looks like a dashboard, recommit and rerun.
5. **Comparison eye-grab**: if the report compares two things, can the reader see the winner of each comparison without reading any label? If not, semantic color is not committed.
6. **Subject check**: state the report's subject in one sentence. Does every section relate to *the subject*, not to its outputs or sources? If a section reads as "about [output of subject]" — e.g., a report about a documentation-generation plugin that ends up narrating the documents the plugin produces — the meta-frame is wrong. Rewrite the section to be about the subject's relationship to those outputs, not the outputs themselves.

A Self-Test failure flagged at Stage 6 that was not caught earlier means the failing stage's verification gate needs strengthening — loop back to that stage, not full re-render.

## Implementation Notes (cross-cutting rules — apply in any stage)

- Hand-build CSS. No Tailwind, no UI-library shell. Inline `<style>` or a single linked stylesheet, written from scratch for this report. Convergence to the generic "AI internal-doc" look lives in library defaults — escape it by not loading them.
- Hand-author SVG for any diagram. Never Mermaid in this context. See `references/craft/diagrams.md` for stroke / label / annotation discipline.
- Charts: Chart.js *with explicit styling overrides* (no defaults), or hand-built SVG. Either works; both require intentional palette, axis, label, and annotation choices. See `references/craft/charts.md`.
- Typography: default to **Geist + Geist Mono** for clean report registers. See `references/craft/typography.md` for the lock, weight mappings, deviation rules, and fallback alternates. **Inter is FORBIDDEN as a fallback**; CSS `font-family` chains must never end with `-apple-system / sans-serif` alone (silent failure path — see typography.md CSS chain rule).
- Color: build a palette per register. Reserve semantic colors (comparison pair, success/warning, callout types) separate from chrome colors. Avoid pure `#ffffff` paper and pure `#000000` ink. See `references/craft/color.md`.
- Spacing: use the 8-tier scale, never one-off values. Section gap must exceed paragraph gap by at least 2 tiers. See `references/craft/spacing.md`.
- Code blocks (audit / incident registers): see `references/craft/code-blocks.md` for typography, subdued highlighting, and density rules.
- Light/dark mode is optional. If you ship it, both modes must look intentional — not one designed and one derived.
- **Verify named entities against source.** Every command name, file path, agent name, class, API, version number, or count you cite must be confirmed by reading or grepping the actual source before printing. Memory and inference are not verification — they invent confidence the artifact does not earn. If you are not sure of a name, omit the citation or mark it explicitly as uncertain rather than fabricate one.

## References

`stages/` holds the workflow protocol. `references/craft/` holds the craft locks. Open each at the right time:

**`stages/`** — workflow steps. Open each stage file when entering that stage.
- `stages/1-preflight.md` — 12-axis format spec lock + spec.md creation
- `stages/2-lock-subject.md` — subject + hero finding lock + short-name derive
- `stages/3-outline-sections.md` — section titles + page anchors
- `stages/4-build-cover.md` — cover-only render + screenshot gate
- `stages/5-build-section.md` — per-section build loop with per-section gate
- `stages/6-assemble.md` — final assembly + Self-Test + user OK

**`references/spec-schema.md`** — the spec.md template. Every stage appends a block per this schema. Always referenced by `stages/1-preflight.md` (creator) and re-read by every later stage (drift control).

**`references/craft/`** — craft locks applied across stages. These are constraints, not catalogs to mine.
- `craft/typography.md` — font lock (Geist + Geist Mono), weight mappings, CSS fallback chain rule (Inter forbidden)
- `craft/color.md` — three-layer palette (chrome / semantic / accent), per-register guidance, print/PDF contrast
- `craft/spacing.md` — 8-tier scale, per-register page margins, scan-rhythm rules
- `craft/cover.md` — cover scale discipline (1/3 rule), forbidden patterns, tagline craft
- `craft/tables.md` — table density, alignment, color, typography
- `craft/charts.md` — axes, palette, annotation, strip-defaults
- `craft/kpi-tiles.md` — hero number scale, tile structure, tabular-nums
- `craft/diagrams.md` — hand-built SVG conventions, stroke discipline, labels
- `craft/callouts.md` — sidebar / margin note / highlight box / pull-quote patterns
- `craft/code-blocks.md` — code typography, subdued highlighting, density

**`references/fixtures/{source}/`** — captured aesthetic systems. Currently `fixtures/figma/` (marketing-site applicability — usually NOT applied to data reports; v5 isolation test confirmed subagents correctly skip it for analytic registers). Each sub-file declares `applicability` in frontmatter; skip sub-files whose applicability does not match your register. **Mine, never clone.**

Remember: a report's quality is measured by what the reader takes away in 30 seconds of flipping. Optimize for *that*, not for completeness, not for polish, not for word count. A short, severe, legible report beats a thorough, polished, unscanned one.
