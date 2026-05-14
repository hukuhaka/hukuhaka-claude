# hukuhaka-claude

A bundle of Claude Code plugins, skills, and templates for **spec-first development** — keeping a codebase's documentation in sync with the code through deterministic scripts plus targeted LLM analysis, with an eval framework that gates every change.

## Who this is for

- You write code with Claude Code daily and the model wastes context re-discovering the codebase every session.
- You want a small, persistent `.claude/` doc set that Claude reads first — and that stays accurate without manual upkeep.
- You're willing to trade a bit of bootstrap time for repeatable, eval-verified skills instead of one-shot prompts.

## What's in the bundle

| Component | What it gives you |
|-----------|-------------------|
| **[project-mapper](docs/PROJECT-MAPPER.md)** | 7 skills + 6 agents that generate and maintain `.claude/{map,design,backlog,changelog,spec}.md` from your codebase. Sync, audit, validate, summarize, trace. |
| **hukuhaka-ltm** | Long-term memory harness for accumulated knowledge (decisions, philosophy, abandoned approaches) that doesn't belong in code or current-state docs. Bootstrap via `/ltm:init`. |
| **team** | Team lead orchestrator skill. Coordinates 3-5 teammates with distinct file ownership; lead reviews and decides without implementing. |
| **codex-coworker** | Collaborative problem-solving with OpenAI Codex (deprecated, default-off). |
| **CLAUDE.md template** | Spec-first router for `~/.claude/CLAUDE.md`: *Approach* / *Rules* / *Reference* structure with explicit decision-proposal format. |

Plus optional extras managed separately (see [docs/EXTRAS.md](docs/EXTRAS.md)):

| Extra | What it does |
|-------|-------------|
| **rtk** | PreToolUse Bash hook that compresses verbose tool calls. Real savings ~40% on hukuhaka workflows. |
| **ccstatusline** | npx-based statusline TUI from [pcvelz/ccstatusline-usage](https://github.com/pcvelz/ccstatusline-usage). |
| **agent-teams** | Enables `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. |

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/hukuhaka/hukuhaka-claude/main/scripts/install.sh | bash
```

Three phases: arrow-key component selector → dependency preflight → optional extras prompt. All idempotent — re-running drives partial install or removal. For non-interactive flags, version pinning, and full reference, see [docs/INSTALL.md](docs/INSTALL.md).

```bash
# Quick non-interactive variants
curl -fsSL .../install.sh | bash -s -- --all
curl -fsSL .../install.sh | bash -s -- --components project-mapper,claude-md
curl -fsSL .../install.sh | bash -s -- --uninstall
```

## First-run workflow

After install, in any project:

```text
You:    /project-mapper:map-init
Claude: [scaffolds .claude/{map,design,backlog,changelog}.md]

You:    /project-mapper:map-sync
Claude: [analyzer agent reads codebase → writer agent emits docs → validator]

You:    /project-mapper:map-validate
Claude: [checks every file:symbol link, reports drift]
```

The `.claude/` files are small enough to load in full into the LLM context window at the start of every session. Skills read them first; the model stops re-discovering layout every time.

See [docs/PROJECT-MAPPER.md](docs/PROJECT-MAPPER.md) for the full skill reference and workflow.

## Documentation

- [docs/INSTALL.md](docs/INSTALL.md) — installer reference, all flags, manifest format, idempotency
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — repo layout, plugin vs skill, install pipeline, quality bar
- [docs/PROJECT-MAPPER.md](docs/PROJECT-MAPPER.md) — flagship plugin, 7 skills + 6 agents detailed
- [docs/EXTRAS.md](docs/EXTRAS.md) — rtk, ccstatusline, agent-teams, standalone helper invocation
- [docs/EVAL.md](docs/EVAL.md) — eval framework: 5 types, pipeline, scenario authoring
- [CHANGELOG.md](CHANGELOG.md) — release notes

## Design principles

- **Spec-first, not retroactive.** `.claude/{map,design,backlog,changelog,spec}.md` is the source of truth. Code drift triggers doc updates, not the other way around.
- **Deterministic where possible, LLM where necessary.** Scripts handle file I/O, formatting, validation, deduplication. Agents handle analysis and synthesis. Hybrid scripts+templates pattern.
- **Eval-gated.** Every skill ships with an eval scenario. No "done" without a verifiable check. Visual outputs require direct human inspection — judge scores ≠ task complete.
- **Idempotent install.** Detect state → install/skip/remove the delta. Re-runs are safe.
- **Orthogonal extras.** Third-party tooling (rtk, ccstatusline) is split into a separate installer so upstream changes there don't touch the core install path.

## Dependencies

| | Required | Optional |
|--|----------|----------|
| **Base** | `git`, `python3` or `jq`, `curl`, `tar` | — |
| **Extras** | — | `brew` (rtk on macOS), `node`/`npx` (ccstatusline), [`codex` CLI](https://github.com/openai/codex) (codex-coworker) |

The installer's preflight check enumerates these per selected component and offers to auto-install via the detected package manager.

## License

MIT. See [LICENSE](LICENSE).
