# Project Map

## Entry Points

- [map-sync](../marketplace/project-mapper/skills/map-sync/SKILL.md): Sync pipeline — analyze, write, scatter, validate. Inline dependency notation (-> dep1, dep2) for shared modules
- [map-setup](../marketplace/project-mapper/skills/map-setup/SKILL.md): Init/teardown .claude/ docs (4 template files, no agents)
- [map-spec](../marketplace/project-mapper/skills/map-spec/SKILL.md): spec.md lifecycle — generate (prescriptive question-based) and verify (drift detection)
- [map-maintain](../marketplace/project-mapper/skills/map-maintain/SKILL.md): Maintain .claude/ doc quality (validate, compact, summary)
- [audit](../marketplace/project-mapper/skills/audit/SKILL.md): Codebase audit — find dead code, duplicates, anti-patterns -> auditor, analyzer
- [backlog](../marketplace/project-mapper/skills/backlog/SKILL.md): Capture items to backlog.md with codebase research (direct, no agents)
- [trace](../marketplace/project-mapper/skills/trace/SKILL.md): Trace code flow for debugging (read-only, no agents)
- [codex-coworker](../skills/codex-coworker/SKILL.md): Collaborative problem-solving with OpenAI Codex
- [team](../skills/team/SKILL.md): Team lead orchestrator — coordinates agent teams without implementing
- [deploy.sh](../scripts/deploy.sh): Manifest-based deploy to ~/.claude/
- [install.sh](../scripts/install.sh): Curl one-liner installer (tarball + deploy.sh)
- [validate.sh](../scripts/validate.sh): JSON lint, frontmatter check, deploy dry-run

## Data Flow

User slash-command -> SKILL.md (router) -> Agent spawn via Task tool -> Analyzer (read-only JSON) -> Writer (.claude/ docs) -> Validator (link check) -> deploy.sh copies to ~/.claude/

Dual entry: skill path (`/project-mapper:map-sync sync .`) for headless/eval, command path (`/project-mapper:map-sync .`) for interactive.

## Components

- [analyzer](../marketplace/project-mapper/agents/analyzer.md): Code analysis (default, scatter, improve modes) -> structured JSON. depends_on field for dependency tracking (sonnet)
- [writer](../marketplace/project-mapper/agents/writer.md): Generate .claude/ docs from analyzer JSON. Supports scatter and compact modes (sonnet)
- [validator](../marketplace/project-mapper/agents/validator.md): Validate documentation links and references (haiku)
- [summarizer](../marketplace/project-mapper/agents/summarizer.md): Compress .claude/ docs into LLM-friendly summary (haiku)
- [auditor](../marketplace/project-mapper/agents/auditor.md): Context gatherer for audit pipeline — reads design.md and project structure (sonnet)
- [verifier](../marketplace/project-mapper/agents/verifier.md): Spec checker — analyze mode (codebase facts) and verify mode (drift detection) (sonnet)
- [sync-pipeline](../marketplace/project-mapper/skills/map-sync/references/sync-pipeline.md): 4-step sync pipeline reference
- [format-rules (sync)](../marketplace/project-mapper/skills/map-sync/references/format-rules.md): .claude/ document format spec with dependency notation
- [format-rules (compact)](../marketplace/project-mapper/skills/map-maintain/references/format-rules.md): Compact-specific changelog/backlog cleanup rules
- [analysis-guide](../marketplace/project-mapper/skills/audit/references/analysis-guide.md): Category-specific audit verification methodology
- [audit-pipeline](../marketplace/project-mapper/skills/audit/references/audit-pipeline.md): 2-agent audit orchestration
- [research-guide](../marketplace/project-mapper/skills/backlog/references/research-guide.md): Codebase investigation for backlog capture
- [spec-guide](../marketplace/project-mapper/skills/map-spec/references/spec-guide.md): spec.md generation guide (prescriptive question-based)
- [trace-guide](../marketplace/project-mapper/skills/trace/references/trace-guide.md): Code flow tracing heuristics
- [eval framework](../eval/): 8 specs, 12 scenarios, 3 judge types (logic, quality, audit-quality)

## Structure

- `marketplace/project-mapper/`: Main plugin — 7 skills, 6 agents, 6 commands, 8 references
- `skills/`: Standalone — codex-coworker, team
- `eval/`: Transcript-based eval (specs, scenarios, 5 Python scripts, run_eval.sh)
- `scripts/`: deploy.sh, validate.sh, install.sh
- `docs/plugin-guide/`: Internal plugin/skill design reference (6 files: skills, skill-design, plugins, agents-and-hooks, distribution, README)
- `.github/workflows/`: CI/CD — validate.yml (PR), release.yml (tag push)
