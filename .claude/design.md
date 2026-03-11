# Design
> v2.0.0 — monorepo restructure

## Tech Stack

- **Bash**: deploy.sh, validate.sh, run_eval.sh - deployment, validation, evaluation pipeline
- **Python 3**: eval judges (eval_logic.py, eval_quality.py, eval_audit_quality.py) + extractors
- **Markdown + YAML frontmatter**: SKILL.md definitions, agent .md files, command .md files
- **JSON**: plugin.json, eval specs/scenarios
- **Claude Code Plugin System**: GitHub Marketplace distribution
- **GitHub Actions**: validate.yml (PR), release.yml (tag push)

## Architecture

- Plugin system: `marketplace/project-mapper/` registered via `.claude-plugin/plugin.json`
- Standalone skills: `skills/` deployed directly to `~/.claude/skills/`
- Deploy pipeline: `scripts/deploy.sh` manifest-based deploy to `~/.claude/` (tracks files in `.hukuhaka-manifest.json`)
- Install: `scripts/install.sh` curl one-liner (downloads tarball, runs deploy.sh)
- Marketplace: primary distribution, GitHub Release via tag push
- CI/CD: `scripts/validate.sh` runs JSON lint + frontmatter check + deploy dry-run

## Patterns

- Dual entry points: skill path (`/project-mapper:map-sync sync .`) for headless/eval, command path (`/project-mapper:map-sync .`) for interactive
- 4-skill map split: map-sync (pipeline), map-setup (init/clean, no agents), map-spec (spec.md generate/verify), map-maintain (validate/compact/summary)
- Skill = router + references: SKILL.md routes subcommands, references/ hold detailed behavior
- Command = interactive workflow: each map- prefixed command file defines a complete workflow
- Agents: lightweight personas with role, tools, and output schema — referenced by `subagent_type` in Task tool
- Agent pipeline: analyzer (read-only) → writer (edit) → validator (read-only) — structured JSON interface
- Mode-aware analysis: analyzer supports default, `scatter:` (folder scan), `improve:` (audit) modes; verifier supports `analyze:` (facts only) and default verify mode
- Model stratification: haiku (validator/summarizer), sonnet (analyzer/writer/auditor/verifier)
- Skills inject format knowledge into agents via `skills:` frontmatter field

## Key Decisions

- Monorepo: plugin + standalone skills + eval in single repo
- Marketplace as primary distribution path; local deploy for dev/test
- plugin.json version as single source of truth; tags must match
- PR-only workflow for main branch; feature branches with prefix convention
- Eval location promoted to top-level `eval/` (no redesign, just move)
- Standalone skills kept outside plugin (general-purpose vs project-mapper specific)
- v2.0.0 starting version (breaking restructure from v1.x)
- Dual entry point architecture: skill path for eval/headless, command path for interactive
- Commands use map- prefix for grouping (e.g., map-sync, map-init, map-validate)
- 4-skill map split: map-sync, map-setup, map-spec, map-maintain — clear responsibility per skill
- 3 additional skills: audit, backlog, trace — non-map operations
- SKILL.md as lightweight router with references/ for detailed behavior

## Dependencies

- **Required**: git, jq or python3
- **Optional**: [codex CLI](https://github.com/openai/codex) (for codex-coworker)

## License

- MIT
