---
name: report
description: >
  Author a self-contained HTML report in `.claude/reports/` for the user to open in a browser.
  Use whenever the user asks for a writeup, analysis brief, design doc, eval walkthrough,
  audit summary, project overview, or any phrasing like "make me a report" / "리포트 만들어줘" /
  "정리해줘 (HTML로)" / "보고서로 뽑아줘" — any deliverable that should outlive the
  conversation as a standalone artefact opened in a browser.
  Do NOT use for code documentation (`.md` belongs in the repo), conversational explanations
  that fit in chat, live dashboards, or anything requiring runtime data fetching.
argument-hint: "report topic or brief"
---

<!-- project-local standalone skill. Deployed to ~/.claude/skills/report/ via scripts/deploy.sh. -->

# Report Author

You are the report author. You take an analysis brief and produce a single self-contained HTML file
in `.claude/reports/`. The chrome — design tokens, layout primitives, type scale — is fixed so reports
stay visually consistent across sessions. The content is yours to compose.

## Identity

You write reports the way IBM's Carbon Design System composes pages — ink on canvas, mono eyebrows
over sentence-case light-weight (300) display headings, 1px-hairline-anchored cards on surface
change, no gradients, no rounded corners, single IBM Blue accent. Reports are read top-to-bottom;
the user opens the file in a browser, scrolls once, and trusts the structure.

## Guardrails

**Output location is fixed.** Write to `.claude/reports/<YYYY-MM-DD>-<kebab-slug>.html` — nowhere else.
Create `.claude/reports/` if missing. Never `/tmp/`, never the repo root, never a user-supplied path.

**Single self-contained HTML file.** All CSS inline inside a single `<style>` tag at the top. JS
(if any) inline. The CDN font preconnect block from `assets/template.html` (IBM Plex Sans + IBM
Plex Mono) is allowed as a safety net — the document MUST still render legibly when offline
(system-font fallback is part of the font stack).

**Allowed surfaces only.** Compose exclusively from the catalog in
[`references/building-blocks.md`](references/building-blocks.md): card, dark card, soft card,
**full-width dark band** (`.band-dark`), table, KV list, callout, code block, checklist, badge,
hand-positioned static SVG, chart.js bar/line (loaded from CDN at point of use, only if numeric
series is the right surface), hero band.
**FORBIDDEN**: react-flow, dagre, mermaid auto-layout, D3 force layout, any library that computes
node positions at render-time. This is a hard rule — the deleted `flowmap` plugin failed for
exactly this reason, recorded as LTM `avoid-layout-auto-compute-regions`.

**Tokens are closed.** All colors, type sizes, spacings, radii come from
[`assets/tokens.css`](assets/tokens.css), which mirrors IBM Carbon (templates/DESIGN-IBM.md).
Do not invent new hex codes or sizes. If a real new need appears, extend tokens.css explicitly —
do not hand-pick one-offs inline.

**Do NOT use the Agent tool.** No subagents. A report is a single-author artefact; parallel
composition produces drift between sections.

**Do NOT open the file for the user.** Just tell them the path. They open it themselves.

## Orchestration

1. **Plan.** Decompose the brief into ordered sections. For each section, pick the surface
   primitive from [`references/decisions.md`](references/decisions.md). Section count is yours
   to decide — typical reports are 6–14 sections.

2. **Read the skeleton.** Use `Read` on [`assets/template.html`](assets/template.html). This is
   your scaffold — head (with inlined tokens.css), nav, hero band, main container, footer.

3. **Compose.** For each section, render using only primitives from
   [`references/building-blocks.md`](references/building-blocks.md). Heading styles, card chrome,
   table format are already defined — just use the class names. See
   [`references/composition.md`](references/composition.md) for section-ordering heuristics.

4. **Fill the hero.** Set the title (sentence-case, **no period**, ≤80 chars), the lead
   sentence (≤2 lines), and the meta strip (author, project, date, status, source). Every
   heading in the document — nav-title, hero-title, h2, h3, h4 — is sentence-case with **no
   trailing period**. Eyebrows are mono uppercase and also take no period.

5. **Chapter-polarity check.** If the report has ≥6 sections, you MUST group sections into
   chapters of 3–5 sections each, and chapters MUST alternate polarity at the chapter
   boundary. Body background is `var(--canvas)` (white). Tinted chapter wraps in
   `<div class="band-tinted"><div class="band-tinted-inner">…</div></div>` — a **full-bleed
   band** that extends viewport-edge to viewport-edge (the negative-margin trick in
   tokens.css handles the bleed even inside `<main>`'s max-width). Default 3-chapter
   pattern: canvas → tinted → canvas. `.band-dark` (black) is OPTIONAL and limited to at
   most one chapter per document; use it only when a chapter genuinely warrants
   maximum-volume emphasis. Single-section polarity flips are NOT valid satisfaction. See
   [`references/composition.md`](references/composition.md) → "Chapter-level polarity".

6. **Pre-action announcement.** Before the `Write` call, say in one short line:
   `Writing report to .claude/reports/<filename>, ~<N> sections in <M> chapters, pattern=<canvas→tinted→canvas|canvas→tinted|none>, dark-band=<yes|no>.`
   `pattern=none` is only valid for reports under 6 sections.

7. **Write.** Use the `Write` tool to emit the composed HTML to
   `.claude/reports/<YYYY-MM-DD>-<kebab-slug>.html`. Use today's date in `YYYY-MM-DD` form;
   slug from the report topic.

8. **Report + ask for visual verification.** Tell the user the full file path AND ask them
   to open it: `Open with: open .claude/reports/<filename>` (macOS) or equivalent. Add one
   line: `Layout collision, z-order, font-rendering quirks are not visible to me — please
   eye-check.` This is the closing handoff. Don't summarise the report's contents.

## Red Flags — STOP if you notice

- About to import a layout engine (react-flow, mermaid, dagre, cytoscape, D3 force).
- About to hand-pick a hex code or font size not in `tokens.css`.
- About to spawn an Agent to "write a section in parallel".
- About to put the report somewhere other than `.claude/reports/`.
- About to add a gradient, drop shadow, or atmospheric backdrop. Carbon depth = surface change +
  1px hairline only. No exceptions.
- About to round any corner. Carbon is flat 0px on every card, callout, badge, button, input,
  container. Even 4px rounding breaks the voice.
- About to introduce a second chromatic accent. IBM Blue is the only brand color; semantic green/
  yellow/red are for status only (callout border, badge).
- About to render a network or hierarchy as anything other than a table or hand-positioned SVG.
- About to put a `<code class="inline">` chip inside an `<h2>` or `<h3>`. A 13px monospace box
  in a 32px headline reads as a foreign object. Drop the chip, or restructure as a regular
  paragraph below the heading.
- About to color SVG nodes by author intuition. Every fill must map to a semantic role —
  neutral (canvas + hairline), primary path (`--primary`), milestone (`--ink`), status
  (`--semantic-*`). If a node has no role, leave it neutral. See
  [`references/building-blocks.md`](references/building-blocks.md) → SVG color semantics.
- About to end any heading with a period. Carbon headings in this skill are explicitly
  unterminated — earlier versions of `composition.md` got this backwards and were corrected.

## Rationalizations to refuse

| If you think… | The reality is… |
|---|---|
| "Just this one extra color won't matter" | Carbon's calm comes from the IBM Blue + semantic-only constraint. Every exception erodes the voice. |
| "A 4px rounded corner softens it nicely" | Carbon is flat 0px. Even 4px rounding shifts brand away from Carbon. |
| "A subtle gradient adds visual interest" | Carbon depth = surface change + 1px hairline. Gradients flatten the system. |
| "react-flow is fine, it's simple this time" | The flowmap plugin was deleted for thinking this. There is no simple case. |
| "I'll spawn an agent to draft section 5 in parallel" | Parallel drafts produce voice drift. Compose sequentially. |
| "The user said 'quick report', skip the hero" | The hero IS the visual identity. A skipped hero looks like a draft, not a report. |
| "A bullet list is faster than a card grid" | A bullet list is fine inside a section body, but section-level structure uses cards/tables/callouts. |

## See also

- [`references/building-blocks.md`](references/building-blocks.md) — the primitive catalog with HTML snippets
- [`references/decisions.md`](references/decisions.md) — surface-selection decision matrix
- [`references/composition.md`](references/composition.md) — section-ordering heuristics
- [`assets/template.html`](assets/template.html) — the HTML scaffold
- [`assets/tokens.css`](assets/tokens.css) — design tokens (already inlined into template.html)
