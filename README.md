# hukuhaka-claude

Claude Code plugins, skills, and agents for codebase analysis and documentation.

## Install

### GitHub Marketplace (Recommended)

Add `project-mapper` from the Claude Code plugin marketplace:

```bash
claude /install project-mapper
```

### Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/hukuhaka/hukuhaka-claude/main/scripts/install.sh | bash
```

Install a specific version:

```bash
curl -fsSL https://raw.githubusercontent.com/hukuhaka/hukuhaka-claude/main/scripts/install.sh | bash -s -- --version 0.0.2
```

### Local Install (Development)

```bash
git clone https://github.com/hukuhaka/hukuhaka-claude.git
cd hukuhaka-claude
scripts/deploy.sh
```

## Plugin: project-mapper

Codebase analysis and `.claude/` documentation generation.

### Skills

| Skill | Description |
|-------|-------------|
| `/project-mapper:map-setup` | Create/teardown `.claude/` documentation scaffolding |
| `/project-mapper:map-sync` | Full sync pipeline: analyze, write, scatter, validate |
| `/project-mapper:map-maintain` | Validate, compact, and summarize `.claude/` docs |
| `/project-mapper:map-spec` | Generate and verify `.claude/spec.md` conventions |
| `/project-mapper:audit` | Codebase audit — find dead code, duplicates, anti-patterns → backlog |
| `/project-mapper:backlog` | Capture ideas and deferred tasks to backlog.md with research |
| `/project-mapper:trace` | Trace code flow to diagnose bugs, data paths, or error origins |

## Standalone Skills

| Skill | Description |
|-------|-------------|
| `/codex-coworker` | Collaborative problem-solving with OpenAI Codex |
| `/skill-creator` | Step-by-step skill creation guide |
| `/mcp-builder` | MCP server builder and tester |

## Deploy Options

```bash
# Deploy plugin + standalone skills
scripts/deploy.sh

# Preview changes
scripts/deploy.sh --dry-run

# Remove all deployed files
scripts/deploy.sh --uninstall

# Remove without confirmation
scripts/deploy.sh --uninstall --force
```

### Uninstall

```bash
# If installed via curl
curl -fsSL https://raw.githubusercontent.com/hukuhaka/hukuhaka-claude/main/scripts/install.sh | bash -s -- --uninstall

# If installed via git clone
scripts/deploy.sh --uninstall
```

## Dependencies

- **Required**: git, python3 or jq
- **Optional**: [codex CLI](https://github.com/openai/codex) (for codex-coworker)

## License

MIT
