# hukuhaka-claude

Claude Code plugins for **spec-first development** — keep a codebase's documentation in sync with the code through deterministic scripts plus targeted LLM analysis, with long-term memory accumulated across sessions.

## Who this is for

- You write code with Claude Code daily and the model wastes context re-discovering the codebase every session.
- You want a small, persistent `.claude/` doc set that Claude reads first — and that stays accurate without manual upkeep.
- You want a separate place for the *narrative* (decisions, philosophy, abandoned approaches) that doesn't belong in current-state docs but you don't want to lose.

## What's in the bundle

| Component | Version | What it gives you |
|-----------|---------|-------------------|
| **hukuhaka-project-mapper** | `1.0.2` | Commands + agents that generate and maintain `.claude/{map,design,backlog,changelog,spec}.md` from your codebase. Init, scan, sync, summarize, compact, clean. |
| **hukuhaka-ltm** | `0.5.0` | Long-term memory plugin with three-tier storage (L1 pinned, L2 indexed cards, L3 raw log). Autonomous L3 append via `<ltm-record>` markers parsed by the Stop hook; batch L2 distillation via `/hukuhaka-ltm:ltm-distill`. |
| **hukuhaka-team** | — | Team lead orchestrator skill. Coordinates 3-5 teammates with distinct file ownership; lead reviews and decides without implementing. |
| **hukuhaka-report-builder** | — | Staged-workflow generator for long-form editorial HTML reports — masthead, numbered article, hand-built inline-SVG figures, sources. A preflight locks the design axes before drafting so the visual identity stays fixed. |
| **CLAUDE.md template** | — | Spec-first router for `~/.claude/CLAUDE.md`: *Approach* / *Rules* / *Reference* structure with explicit decision-proposal format. |

Optional third-party extras (rtk, ccstatusline, agent-teams flag) ride along with the installer.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/hukuhaka/hukuhaka-claude/main/scripts/install.sh | bash
```

The installer is interactive by default (component selector → dependency preflight → optional extras). Re-running is safe — it detects existing state and applies the delta. Non-interactive variants:

```bash
curl -fsSL .../install.sh | bash -s -- --all
curl -fsSL .../install.sh | bash -s -- --components hukuhaka-project-mapper,claude-md
curl -fsSL .../install.sh | bash -s -- --uninstall
```

## First-run workflow

After install, in any project:

```text
You:    /hukuhaka-project-mapper:map-init
Claude: [scaffolds .claude/{map,design,backlog,changelog}.md]

You:    /hukuhaka-project-mapper:map-scan
Claude: [writes .claude/scan.md — per-directory CLAUDE.md placement decisions]

You:    /hukuhaka-project-mapper:map-sync
Claude: [scatter → analyzer reads codebase → writer emits docs → validator checks links]
```

For long-term memory:

```text
You:    /hukuhaka-ltm:ltm-init
Claude: [bootstraps .claude/ltm/ — pinned.md + index/ + log/ + CLAUDE.md rules]

You:    "we decided to ditch X because of Y"
Claude: [Stop hook captures this via <ltm-record> autonomous marker]

You:    /hukuhaka-ltm:ltm-distill
Claude: [batch-reviews auto-recorded entries, promotes into L2 cards]
```

The `.claude/` files are small enough to load in full into the LLM context window at the start of every session. Skills read them first; the model stops re-discovering layout every time.

## Design principles

- **Spec-first, not retroactive.** `.claude/{map,design,backlog,changelog,spec}.md` is the source of truth. Code drift triggers doc updates, not the other way around.
- **Deterministic where possible, LLM where necessary.** Scripts handle file I/O, formatting, validation, deduplication. Agents handle analysis and synthesis.
- **Hot/warm/cold memory tiers.** L1 always-loaded principles, L2 on-demand cards, L3 raw timeline. Autonomous L3 append for closure moments (decided, abandoned, lesson named) without per-turn user assent.
- **Idempotent install.** Detect state → install/skip/remove the delta. Re-runs are safe.

## Dependencies

| | Required | Optional |
|--|----------|----------|
| **Base** | `git`, `python3` (or `jq`), `curl`, `tar` | — |
| **Extras** | — | `brew` (rtk on macOS), `node`/`npx` (ccstatusline) |

The installer's preflight check enumerates these per selected component and offers to auto-install via the detected package manager.

## License

MIT. See [LICENSE](LICENSE).
