# Plugin Guide

> Claude Code plugin/skill comprehensive reference for this project.

Source: [official docs](../officials/build_with_claude_code/) + [project-mapper](../../marketplace/project-mapper/) reference implementation.

## Quick Navigation

| Goal | File |
|------|------|
| Create a skill (SKILL.md) | [skills.md](skills.md) |
| Build a plugin (plugin.json) | [plugins.md](plugins.md) |
| Add agents or hooks | [agents-and-hooks.md](agents-and-hooks.md) |
| Distribute via marketplace | [distribution.md](distribution.md) |

## Component Hierarchy

```
marketplace.json          — catalog of plugins
  └─ plugin               — directory with .claude-plugin/plugin.json
       ├─ skills/          — SKILL.md files (slash commands)
       ├─ agents/          — subagent .md files
       ├─ hooks/           — hooks.json event handlers
       ├─ .mcp.json        — MCP server configs
       ├─ .lsp.json        — LSP server configs
       └─ settings.json    — default settings
```

User invokes: `/plugin-name:skill-name` (namespaced) or `/skill-name` (standalone).

## Terminology

| Term | Description |
|------|-------------|
| **SKILL.md** | Markdown file with YAML frontmatter defining a skill (slash command) |
| **plugin.json** | Plugin manifest in `.claude-plugin/` directory |
| **marketplace.json** | Catalog listing plugins and their sources |
| **Agent** | Subagent `.md` file with role, tools, model |
| **Hook** | Shell command/prompt/agent triggered by lifecycle events |
| **MCP** | Model Context Protocol — external tool servers |
| **LSP** | Language Server Protocol — code intelligence |
| **`$ARGUMENTS`** | String substitution for user input in skills |
| **`${CLAUDE_PLUGIN_ROOT}`** | Absolute path to plugin directory at runtime |

## Standalone vs Plugin

| Criterion | Standalone (`.claude/`) | Plugin |
|-----------|------------------------|--------|
| Scope | Single project or personal | Shareable, versioned |
| Skill names | `/hello` | `/plugin-name:hello` |
| Distribution | Manual copy | Marketplace install |
| Best for | Experiments, personal workflows | Teams, community |

Start standalone in `.claude/`, then [convert to plugin](plugins.md#standalone-to-plugin-migration) when ready to share.

## Scope Priority

Skills: enterprise > personal (`~/.claude/`) > project (`.claude/`) > plugin

Plugin skills use `plugin-name:skill-name` namespace — no conflict with other levels.

## Reference Implementation

[project-mapper](../../marketplace/project-mapper/) demonstrates:
- 8 skills (3 router + 5 utility), 5 agents, 12 commands
- Agent pipeline: analyzer → writer → validator
- Model stratification: haiku (validator) / sonnet (analyzer, writer) / opus (elaborator)
- Dual entry points: skill path (headless) + command path (interactive)
- Manifest-based deploy with [deploy.sh](../../scripts/deploy.sh)

## Official Docs

- [Skills](../officials/build_with_claude_code/skills.md)
- [Plugins](../officials/build_with_claude_code/plugins.md)
- [Sub-agents](../officials/build_with_claude_code/sub-agents.md)
- [Hooks guide](../officials/build_with_claude_code/hooks-guide.md)
- [Hooks reference](../officials/reference/hooks.md)
- [Plugins reference](../officials/reference/plugins-reference.md)
- [Plugin marketplaces](../officials/administration/plugin-marketplaces.md)
- [Discover plugins](../officials/build_with_claude_code/discover-plugins.md)
- Online: `https://code.claude.com/docs/llms.txt`
