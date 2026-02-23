# hukuhaka-claude

Claude Code plugins, skills, and agents for codebase analysis and documentation.

## Install

### GitHub Marketplace (Recommended)

Add `project-mapper` from the Claude Code plugin marketplace:

```bash
claude /install project-mapper
```

### Local Install (Development)

```bash
git clone https://github.com/hukuhaka/hukuhaka-claude.git
cd hukuhaka-claude
scripts/deploy.sh
```

## Plugin: project-mapper

Codebase analysis and `.claude/` documentation generation.

| Command | Description |
|---------|-------------|
| `/project-mapper:map-init` | Create empty `.claude/` documentation template |
| `/project-mapper:map-sync .` | Full sync pipeline: analyze, write, scatter, validate |
| `/project-mapper:map-validate` | Check all `.claude/` documentation links |
| `/project-mapper:map-compact` | Clean up changelog and implementation docs |
| `/project-mapper:map-clean` | Remove scattered CLAUDE.md files |
| `/project-mapper:map-summary` | Compress `.claude/` docs for LLM context |

## Standalone Skills

| Skill | Description |
|-------|-------------|
| `/codex-coworker` | Collaborative problem-solving with OpenAI Codex |

## Deploy Options

```bash
# Local deploy (plugin + standalone skills)
scripts/deploy.sh

# Preview changes
scripts/deploy.sh --dry-run
```

## Dependencies

- **Required**: git, jq or python3
- **Optional**: rsync (falls back to cp), [codex CLI](https://github.com/openai/codex) (for codex-coworker)

## License

MIT
