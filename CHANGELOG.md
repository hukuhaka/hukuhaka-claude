# Changelog

All notable changes to hukuhaka-claude are documented here. The project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Plugin versions (`marketplace/<plugin>/.claude-plugin/plugin.json`) are
independent — see those files for their own history.

## [1.0.1] — 2026-05-19

### Changed

- `skills/report/`: hero display token bumped 54px → 60px. One step
  above Carbon `display-04`, calibrated for the 1200 max-width report
  hero container so it carries more typographic weight without
  inheriting the marketing-hero scale of `fluid-display-05` (76px).

## [1.0.0] — 2026-05-14

Fresh start. The pre-1.0 git history was discarded as part of a repository
architecture migration. The public repository was reinitialized to host only
the publish artifacts (`marketplace/`, `skills/`, `templates/`, `scripts/`,
plus `README`, `LICENSE`, `CHANGELOG`, `VERSION`). Internal development
artifacts (the eval framework, project documentation, `.claude/` workspace,
LTM history) now live in a separate private repository and never reach this
repo.

### Plugins at 1.0.0

- **project-mapper** `1.0.0` — codebase analysis and `.claude/` documentation
  generation. Skills: `map-setup`, `map-sync`, `map-maintain`, `map-spec`,
  `audit`, `trace`, `backlog`.
- **hukuhaka-ltm** `0.1.0` — long-term memory plugin with three-tier
  storage (L1 pinned, L2 indexed cards, L3 raw log), autonomous L3 append
  via `<ltm-record>` markers parsed by the Stop hook, batch L2 distillation
  via `/hukuhaka-ltm:ltm-distill`.

### Notes

- Pre-1.0 development tracked plugin features, the eval framework, install
  flow, and documentation. That history is preserved in the private
  development repository but is not relevant to public consumers of the
  marketplace plugins.
- The split between development repository and public repository is the
  governance change that motivated 1.0.0 — see internal documentation.
