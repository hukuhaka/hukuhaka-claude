# Plugins

> plugin.json schema, directory structure, components, installation, local development.

Official source: [plugins.md](../officials/build_with_claude_code/plugins.md), [plugins-reference.md](../officials/reference/plugins-reference.md)

## Standalone vs Plugin Decision

| Criterion | Standalone (`.claude/`) | Plugin |
|-----------|------------------------|--------|
| Share with team/community | No | Yes (marketplace) |
| Skill namespace | `/hello` (short) | `/plugin-name:hello` (namespaced) |
| Multi-project reuse | Manual copy | Install once |
| Version control | Per-project | Semver + updates |
| Includes agents/hooks/MCP/LSP | Via settings.json | Bundled together |

**Rule of thumb**: Start standalone for iteration → [convert to plugin](#standalone-to-plugin-migration) when ready to share.

## Directory Structure

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json         # Manifest (optional — only name required)
├── skills/                  # SKILL.md directories
│   └── hello/
│       └── SKILL.md
├── commands/                # Legacy skill markdown files
├── agents/                  # Subagent .md files
├── hooks/
│   └── hooks.json           # Event handlers
├── .mcp.json                # MCP server configs
├── .lsp.json                # LSP server configs
├── settings.json            # Default settings (only `agent` key supported)
└── scripts/                 # Utility scripts for hooks
```

**Critical**: components (`skills/`, `agents/`, `hooks/`, `commands/`) go at plugin **root**, NOT inside `.claude-plugin/`. Only `plugin.json` goes inside `.claude-plugin/`.

## plugin.json Schema

### Required Fields

Only `name` is required if manifest is included. Manifest itself is optional — Claude Code auto-discovers components in default locations.

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `name` | string | Unique identifier (kebab-case, no spaces). Used for skill namespacing | `"project-mapper"` |

### Metadata Fields

| Field | Type | Description |
|-------|------|-------------|
| `version` | string | Semver. If also in marketplace entry, plugin.json wins |
| `description` | string | Brief plugin purpose |
| `author` | object | `{name, email?, url?}` |
| `homepage` | string | Documentation URL |
| `repository` | string | Source code URL |
| `license` | string | SPDX identifier (MIT, Apache-2.0) |
| `keywords` | array | Discovery tags |

### Component Path Fields

| Field | Type | Description |
|-------|------|-------------|
| `commands` | string\|array | Additional command files/directories |
| `agents` | string\|array | Additional agent files |
| `skills` | string\|array | Additional skill directories |
| `hooks` | string\|array\|object | Hook config paths or inline config |
| `mcpServers` | string\|array\|object | MCP config paths or inline config |
| `lspServers` | string\|array\|object | LSP config paths or inline config |
| `outputStyles` | string\|array | Output style files/directories |

**Path rules**:
- Custom paths **supplement** default directories — they don't replace them
- All paths relative to plugin root, starting with `./`
- Multiple paths as arrays for flexibility

### Complete Example

```json
{
  "name": "plugin-name",
  "version": "1.2.0",
  "description": "Brief plugin description",
  "author": { "name": "Author", "email": "a@b.com" },
  "homepage": "https://docs.example.com",
  "repository": "https://github.com/author/plugin",
  "license": "MIT",
  "keywords": ["keyword1", "keyword2"],
  "commands": ["./custom/cmd.md"],
  "agents": "./custom/agents/",
  "skills": "./custom/skills/",
  "hooks": "./config/hooks.json",
  "mcpServers": "./mcp-config.json",
  "lspServers": "./.lsp.json"
}
```

## File Locations Reference

| Component | Default Location | Purpose |
|-----------|-----------------|---------|
| Manifest | `.claude-plugin/plugin.json` | Plugin metadata (optional) |
| Commands | `commands/` | Legacy skill markdown files |
| Skills | `skills/` | Skills with `<name>/SKILL.md` |
| Agents | `agents/` | Subagent markdown files |
| Hooks | `hooks/hooks.json` | Hook configuration |
| MCP servers | `.mcp.json` | MCP server definitions |
| LSP servers | `.lsp.json` | Language server configs |
| Settings | `settings.json` | Default config (`agent` key only) |

## `${CLAUDE_PLUGIN_ROOT}`

Absolute path to plugin directory at runtime. **Must use** in hooks, MCP configs, and scripts to ensure correct paths regardless of installation location.

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Write|Edit",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/scripts/format.sh"
      }]
    }]
  }
}
```

Also available: `$CLAUDE_PROJECT_DIR` for project root.

## Installation Scopes

| Scope | Settings File | Use Case |
|-------|--------------|----------|
| `user` | `~/.claude/settings.json` | Personal, all projects (default) |
| `project` | `.claude/settings.json` | Team, shared via version control |
| `local` | `.claude/settings.local.json` | Project-specific, gitignored |
| `managed` | `managed-settings.json` | Enterprise, read-only |

## Plugin Caching

Marketplace plugins are copied to `~/.claude/plugins/cache/` (not used in-place).

**Path traversal limitation**: installed plugins cannot reference files outside their directory. `../shared-utils` won't work.

**Workaround**: create symlinks inside plugin directory. Symlinks are followed during copy.

```bash
# Inside plugin directory
ln -s /path/to/shared-utils ./shared-utils
```

## Plugin Skills (Namespacing)

Plugin skills are namespaced: `/plugin-name:skill-name`.

```
/project-mapper:map-sync sync .     # skill path
/project-mapper:map-sync .          # command path
```

To change namespace prefix, update `name` in plugin.json.

## Plugin Agents

Place in `agents/` at plugin root. Appear in `/agents` alongside built-in agents.

```markdown
---
name: security-reviewer
description: Reviews code for security vulnerabilities
tools: Read, Grep, Glob
model: sonnet
---

Review code for OWASP top 10 vulnerabilities...
```

Accessed as `plugin-name:agent-name` when used via Task tool.

## Plugin Hooks

Place in `hooks/hooks.json` at plugin root. Same format as settings.json hooks with optional `description` field.

```json
{
  "description": "Auto-format on file changes",
  "hooks": {
    "PostToolUse": [{
      "matcher": "Write|Edit",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/scripts/format.sh"
      }]
    }]
  }
}
```

Plugin hooks merge with user/project hooks when plugin is enabled.

## Plugin MCP Servers

Place in `.mcp.json` at plugin root or inline in plugin.json.

```json
{
  "mcpServers": {
    "plugin-db": {
      "command": "${CLAUDE_PLUGIN_ROOT}/servers/db-server",
      "args": ["--config", "${CLAUDE_PLUGIN_ROOT}/config.json"]
    }
  }
}
```

Servers start automatically when plugin is enabled.

## Plugin LSP Servers

Place in `.lsp.json` at plugin root or inline in plugin.json.

```json
{
  "go": {
    "command": "gopls",
    "args": ["serve"],
    "extensionToLanguage": { ".go": "go" }
  }
}
```

Required fields: `command`, `extensionToLanguage`. Users must install the language server binary separately.

Optional: `args`, `transport` (stdio|socket), `env`, `initializationOptions`, `settings`, `workspaceFolder`, `startupTimeout`, `shutdownTimeout`, `restartOnCrash`, `maxRestarts`.

## Plugin Settings

`settings.json` at plugin root applies defaults when enabled. Currently only `agent` key supported:

```json
{ "agent": "security-reviewer" }
```

Activates the named agent as main thread (its system prompt, tools, model).

## Standalone to Plugin Migration

1. Create plugin structure:
   ```bash
   mkdir -p my-plugin/.claude-plugin
   ```

2. Create `my-plugin/.claude-plugin/plugin.json`:
   ```json
   { "name": "my-plugin", "version": "1.0.0" }
   ```

3. Copy existing files:
   ```bash
   cp -r .claude/commands my-plugin/
   cp -r .claude/agents my-plugin/
   cp -r .claude/skills my-plugin/
   ```

4. Migrate hooks: extract `hooks` from settings.json → `my-plugin/hooks/hooks.json`

5. Test: `claude --plugin-dir ./my-plugin`

| Standalone | Plugin |
|-----------|--------|
| `.claude/commands/` | `plugin-name/commands/` |
| `.claude/agents/` | `plugin-name/agents/` |
| Hooks in settings.json | `hooks/hooks.json` |
| Manual copy to share | Marketplace install |

## Local Development

### Test with --plugin-dir

```bash
claude --plugin-dir ./my-plugin
```

Multiple plugins:
```bash
claude --plugin-dir ./plugin-one --plugin-dir ./plugin-two
```

Changes require restart. Test each component:
- Skills: `/plugin-name:skill-name`
- Agents: check `/agents`
- Hooks: verify trigger events

### Debug

```bash
claude --debug
```

Shows: plugin loading, manifest errors, command/agent/hook registration, MCP initialization.

## CLI Commands

| Command | Description |
|---------|-------------|
| `claude plugin install <plugin> [-s scope]` | Install from marketplace |
| `claude plugin uninstall <plugin> [-s scope]` | Remove (aliases: `remove`, `rm`) |
| `claude plugin enable <plugin> [-s scope]` | Enable disabled plugin |
| `claude plugin disable <plugin> [-s scope]` | Disable without removing |
| `claude plugin update <plugin> [-s scope]` | Update to latest version |
| `claude plugin validate .` | Validate plugin/marketplace JSON |

`<plugin>` = name or `plugin-name@marketplace-name`. Scope: `user` (default), `project`, `local`, `managed`.

## Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Plugin not loading | Invalid plugin.json | `claude plugin validate .` |
| Components missing | Wrong directory structure | Components at root, NOT inside `.claude-plugin/` |
| Hooks not firing | Script not executable | `chmod +x script.sh` |
| MCP server fails | Missing `${CLAUDE_PLUGIN_ROOT}` | Use variable for all plugin paths |
| Path errors | Absolute paths used | All paths relative, starting with `./` |
| LSP not found | Binary not installed | Install language server first |

## Real Example: project-mapper

```
marketplace/project-mapper/
├── .claude-plugin/
│   └── plugin.json          # name: "project-mapper", version: "0.0.1"
├── skills/
│   ├── map-sync/SKILL.md    # Router → agent pipeline
│   ├── map-setup/SKILL.md   # Direct execution (no agents)
│   ├── map-maintain/SKILL.md # Delegates to agents
│   ├── query/SKILL.md
│   ├── review/SKILL.md
│   ├── elaborate/SKILL.md
│   ├── improve/SKILL.md
│   └── flow-tracer/SKILL.md
├── agents/
│   ├── analyzer.md           # sonnet, read-only, returns JSON
│   ├── writer.md             # sonnet, acceptEdits, writes docs
│   ├── validator.md          # haiku, read-only, checks links
│   └── summarizer.md         # haiku, compresses docs
├── commands/                  # 12 interactive workflow commands
└── references/                # Shared reference docs
```

8 skills, 5 agents, 12 commands. Deployed to `~/.claude/plugins/hukuhaka-plugin/project-mapper/` via `scripts/deploy.sh`.
