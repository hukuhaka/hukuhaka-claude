# hukuhaka-claude

Claude Code plugins, skills, and agents for codebase analysis and documentation.

## Features

### Plugin: project-mapper

Codebase analysis and `.claude/` documentation generation using semantic code search.

| Command | Description |
|---------|-------------|
| `/project-mapper:map init` | Create empty `.claude/` template |
| `/project-mapper:map sync .` | Index + analyze + generate docs |
| `/project-mapper:map full-sync .` | sync + scatter + validate |
| `/project-mapper:query [question]` | Ask about project architecture |
| `/project-mapper:review pr [n]` | Code review with project context |
| `/project-mapper:elaborate [req]` | Convert requirements to implementation tasks |
| `/project-mapper:flow-tracer trace [feature]` | Trace code flow and call chains |

### Standalone Skills

| Skill | Description |
|-------|-------------|
| `/codex-coworker` | Collaborative problem-solving with OpenAI Codex |
| `/bug-finder` | Find bug locations (identification only, no fixes) |
| `/summarize` | Execute commands with token-efficient summarized output |
| `/skill-creator`* | Step-by-step guide for creating new skills |
| `/mcp-builder`* | Build and test MCP servers |

*From Anthropic (Apache 2.0)

### Standalone Agents

| Agent | Description |
|-------|-------------|
| `result-runner` | Execute commands and analyze results in isolation |

## Installation

### Quick Install (curl)

```bash
curl -fsSL https://raw.githubusercontent.com/hukuhaka/hukuhaka-claude/main/install.sh | bash
```

### Manual Install

```bash
git clone https://github.com/hukuhaka/hukuhaka-claude.git
cd hukuhaka-claude
./deploy.sh
```

## Update

```bash
# If installed via curl
huku-update

# If installed manually
cd /path/to/hukuhaka-claude
git pull && ./deploy.sh
```

## Dependencies

### Required

- **git** - For cloning and updates
- **jq** or **python3** - For JSON manipulation

### Optional

- **rsync** - For efficient file syncing (falls back to cp)
- **[codex CLI](https://github.com/openai/codex)** - For `/codex-coworker` skill
  ```bash
  npm install -g @openai/codex
  ```

### MCP code-search

The deploy script automatically installs [claude-context-local](https://github.com/FarhanAliRaza/claude-context-local) for semantic code search.

Requires HuggingFace token for model access:
1. Get token at https://huggingface.co/settings/tokens
2. Approve model access at https://huggingface.co/google/embeddinggemma-300m
3. Token will be prompted during first install, or set `HF_TOKEN` env var

## Deploy Options

```bash
# Standard deploy
./deploy.sh

# Dry run (preview changes)
./deploy.sh --dry-run

# Clean install (remove all and reinstall)
./deploy.sh --clean

# Skip confirmations
./deploy.sh --yes
```

## File Structure

```
~/.claude/
├── CLAUDE.md           # Global instructions
├── skills/             # Standalone skills
├── agents/             # Standalone agents
├── plugins/
│   └── hukuhaka-plugin/
│       └── project-mapper/
│           ├── skills/
│           ├── agents/
│           └── commands/
└── settings.json       # Plugin configuration
```

## Resources

- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [Claude Code GitHub](https://github.com/anthropics/claude-code)

## Credits

The following skills are from [Anthropic's official Claude Code](https://github.com/anthropics/claude-code):

| Skill | License |
|-------|---------|
| `/mcp-builder` | Apache 2.0 |
| `/skill-creator` | Apache 2.0 |

## License

MIT (except for Apache 2.0 licensed Anthropic skills above)
