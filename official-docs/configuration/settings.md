# Claude Code Settings Documentation

## Configuration Index

Claude Code offers hierarchical settings across multiple scopes to configure behavior for personal use, team collaboration, or enterprise deployment.

## Configuration Scopes

Claude Code uses a **scope system** to determine where configurations apply:

| Scope | Location | Who it affects | Shared with team? |
|-------|----------|----------------|-------------------|
| **Managed** | System-level `managed-settings.json` | All users on the machine | Yes (deployed by IT) |
| **User** | `~/.claude/` directory | You, across all projects | No |
| **Project** | `.claude/` in repository | All collaborators on this repository | Yes (committed to git) |
| **Local** | `.claude/*.local.*` files | You, in this repository only | No (gitignored) |

### Scope Precedence

When the same setting is configured in multiple scopes, more specific scopes take precedence:

1. **Managed** (highest) - can't be overridden
2. **Command line arguments** - temporary session overrides
3. **Local** - overrides project and user settings
4. **Project** - overrides user settings
5. **User** (lowest) - applies when nothing else specifies the setting

### When to Use Each Scope

- **Managed scope**: Security policies, compliance requirements, standardized configurations
- **User scope**: Personal preferences, tools/plugins, API keys
- **Project scope**: Team-shared settings, plugins, standardized tooling
- **Local scope**: Personal project overrides, testing configurations, machine-specific settings

## Settings Files

### File Locations

| Feature | User location | Project location | Local location |
|---------|---------------|------------------|----------------|
| **Settings** | `~/.claude/settings.json` | `.claude/settings.json` | `.claude/settings.local.json` |
| **Subagents** | `~/.claude/agents/` | `.claude/agents/` | — |
| **MCP servers** | `~/.claude.json` | `.mcp.json` | `~/.claude.json` |
| **Plugins** | `~/.claude/settings.json` | `.claude/settings.json` | `.claude/settings.local.json` |
| **CLAUDE.md** | `~/.claude/CLAUDE.md` | `CLAUDE.md` or `.claude/CLAUDE.md` | `CLAUDE.local.md` |

### Managed Settings Paths

- **macOS**: `/Library/Application Support/ClaudeCode/`
- **Linux and WSL**: `/etc/claude-code/`
- **Windows**: `C:\Program Files\ClaudeCode\`

## Example settings.json

```json
{
  "permissions": {
    "allow": [
      "Bash(npm run lint)",
      "Bash(npm run test *)",
      "Read(~/.zshrc)"
    ],
    "deny": [
      "Bash(curl *)",
      "Read(./.env)",
      "Read(./.env.*)",
      "Read(./secrets/**)"
    ]
  },
  "env": {
    "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
    "OTEL_METRICS_EXPORTER": "otlp"
  },
  "companyAnnouncements": [
    "Welcome to Acme Corp! Review our code guidelines at docs.acme.com",
    "Reminder: Code reviews required for all PRs",
    "New security policy in effect"
  ]
}
```

## Available Settings

### Core Settings

| Key | Description | Example |
|-----|-------------|---------|
| `apiKeyHelper` | Custom script to generate auth value for requests | `/bin/generate_temp_api_key.sh` |
| `cleanupPeriodDays` | Sessions inactive longer than this period are deleted (default: 30) | `20` |
| `companyAnnouncements` | Announcements to display to users at startup | `["Welcome..."]` |
| `env` | Environment variables applied to every session | `{"FOO": "bar"}` |
| `attribution` | Customize attribution for git commits and PRs | `{"commit": "🤖 Generated with Claude Code", "pr": ""}` |
| `permissions` | Allow/deny/ask rules for tool access | See Permission Settings section |
| `hooks` | Custom commands to run before/after tool executions | `{"PreToolUse": {"Bash": "echo '...'"}` |
| `disableAllHooks` | Disable all hooks | `true` |
| `allowManagedHooksOnly` | (Managed only) Prevent loading of user/project/plugin hooks | `true` |
| `model` | Override default model for Claude Code | `"claude-sonnet-4-5-20250929"` |
| `otelHeadersHelper` | Script to generate dynamic OpenTelemetry headers | `/bin/generate_otel_headers.sh` |
| `statusLine` | Configure custom status line | `{"type": "command", "command": "~/.claude/statusline.sh"}` |
| `fileSuggestion` | Configure custom script for `@` file autocomplete | `{"type": "command", "command": "~/.claude/file-suggestion.sh"}` |
| `respectGitignore` | Control whether `@` picker respects `.gitignore` | `false` |
| `outputStyle` | Configure output style to adjust system prompt | `"Explanatory"` |
| `forceLoginMethod` | Restrict login to `claudeai` or `console` | `claudeai` |
| `forceLoginOrgUUID` | Specify organization UUID for auto-selection | `"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"` |
| `enableAllProjectMcpServers` | Auto-approve all MCP servers in project `.mcp.json` | `true` |
| `enabledMcpjsonServers` | List of specific MCP servers to approve | `["memory", "github"]` |
| `disabledMcpjsonServers` | List of specific MCP servers to reject | `["filesystem"]` |
| `allowedMcpServers` | (Managed) Allowlist of MCP servers | `[{ "serverName": "github" }]` |
| `deniedMcpServers` | (Managed) Denylist of MCP servers | `[{ "serverName": "filesystem" }]` |
| `strictKnownMarketplaces` | (Managed) Allowlist of plugin marketplaces | `[{ "source": "github", "repo": "..." }]` |
| `awsAuthRefresh` | Custom script to modify `.aws` directory | `aws sso login --profile myprofile` |
| `awsCredentialExport` | Custom script outputting JSON with AWS credentials | `/bin/generate_aws_grant.sh` |
| `alwaysThinkingEnabled` | Enable extended thinking by default | `true` |
| `plansDirectory` | Where plan files are stored | `"./plans"` |
| `showTurnDuration` | Show turn duration messages | `true` |
| `language` | Configure Claude's preferred response language | `"japanese"` |
| `autoUpdatesChannel` | Release channel (`"stable"` or `"latest"`) | `"stable"` |
| `spinnerTipsEnabled` | Show tips in spinner | `false` |
| `terminalProgressBarEnabled` | Enable terminal progress bar | `false` |

## Permission Settings

### Permission Rules Structure

```json
{
  "permissions": {
    "allow": ["Bash(git diff *)", "Read(~/.zshrc)"],
    "ask": ["Bash(git push *)"],
    "deny": ["WebFetch", "Bash(curl *)", "Read(./.env)"],
    "additionalDirectories": ["../docs/"],
    "defaultMode": "acceptEdits",
    "disableBypassPermissionsMode": "disable"
  }
}
```

### Permission Rule Syntax

Rules follow the format: `Tool` or `Tool(specifier)`

#### Rule Evaluation Order
1. **Deny** rules (checked first)
2. **Ask** rules
3. **Allow** rules (checked last)

The first matching rule determines behavior. Deny rules always take precedence.

#### Matching Examples

| Rule | Effect |
|------|--------|
| `Bash` | Matches all Bash commands |
| `Bash(npm run build)` | Matches exact command |
| `Read(./.env)` | Matches reading `.env` file |
| `WebFetch(domain:example.com)` | Matches fetch requests to example.com |
| `Bash(npm run *)` | Matches npm run commands with wildcards |
| `Bash(git commit *)` | Matches git commit commands |
| `Bash(* --version)` | Matches any command with --version flag |

#### Wildcard Patterns Example

```json
{
  "permissions": {
    "allow": [
      "Bash(npm run *)",
      "Bash(git commit *)",
      "Bash(git * main)",
      "Bash(* --version)",
      "Bash(* --help *)"
    ],
    "deny": [
      "Bash(git push *)"
    ]
  }
}
```

### Permission Keys

| Key | Description |
|-----|-------------|
| `allow` | Array of permission rules to allow tool use |
| `ask` | Array of permission rules requiring confirmation |
| `deny` | Array of permission rules to deny tool use |
| `additionalDirectories` | Additional working directories Claude can access |
| `defaultMode` | Default permission mode (`"acceptEdits"`) |
| `disableBypassPermissionsMode` | Set to `"disable"` to prevent bypassing permissions |

## Sandbox Settings

```json
{
  "sandbox": {
    "enabled": true,
    "autoAllowBashIfSandboxed": true,
    "excludedCommands": ["docker"],
    "network": {
      "allowUnixSockets": ["/var/run/docker.sock"],
      "allowLocalBinding": true,
      "httpProxyPort": 8080,
      "socksProxyPort": 8081
    },
    "enableWeakerNestedSandbox": false
  }
}
```

### Sandbox Keys

| Key | Description |
|-----|-------------|
| `enabled` | Enable bash sandboxing (macOS, Linux, WSL2) |
| `autoAllowBashIfSandboxed` | Auto-approve bash commands when sandboxed |
| `excludedCommands` | Commands to run outside sandbox |
| `allowUnsandboxedCommands` | Allow commands via `dangerouslyDisableSandbox` parameter |
| `network.allowUnixSockets` | Unix socket paths accessible in sandbox |
| `network.allowLocalBinding` | Allow binding to localhost ports (macOS only) |
| `network.httpProxyPort` | HTTP proxy port |
| `network.socksProxyPort` | SOCKS5 proxy port |
| `enableWeakerNestedSandbox` | Enable weaker sandbox for unprivileged Docker (Linux/WSL2) |

## Attribution Settings

```json
{
  "attribution": {
    "commit": "Generated with AI\n\nCo-Authored-By: AI <ai@example.com>",
    "pr": ""
  }
}
```

### Default Attribution

**Commits:**
```
🤖 Generated with [Claude Code](https://claude.com/claude-code)

   Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

**Pull Requests:**
```
🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## File Suggestion Settings

```json
{
  "fileSuggestion": {
    "type": "command",
    "command": "~/.claude/file-suggestion.sh"
  }
}
```

The command receives JSON via stdin with `query` field and outputs newline-separated file paths.

**Example script:**
```bash
#!/bin/bash
query=$(cat | jq -r '.query')
your-repo-file-index --query "$query" | head -20
```

## Plugin Configuration

```json
{
  "enabledPlugins": {
    "formatter@acme-tools": true,
    "deployer@acme-tools": true,
    "analyzer@security-plugins": false
  },
  "extraKnownMarketplaces": {
    "acme-tools": {
      "source": {
        "source": "github",
        "repo": "acme-corp/claude-plugins"
      }
    }
  }
}
```

### Marketplace Source Types

- **github**: `{ "source": "github", "repo": "owner/repo", "ref": "branch", "path": "subdir" }`
- **git**: `{ "source": "git", "url": "https://...", "ref": "branch", "path": "subdir" }`
- **url**: `{ "source": "url", "url": "https://...", "headers": {...} }`
- **npm**: `{ "source": "npm", "package": "@scope/package" }`
- **file**: `{ "source": "file", "path": "/absolute/path" }`
- **directory**: `{ "source": "directory", "path": "/absolute/path" }`
- **hostPattern**: `{ "source": "hostPattern", "hostPattern": "^regex$" }`

## Managed Marketplace Restrictions

```json
{
  "strictKnownMarketplaces": [
    {
      "source": "github",
      "repo": "acme-corp/approved-plugins"
    },
    {
      "source": "github",
      "repo": "acme-corp/security-tools",
      "ref": "v2.0"
    },
    {
      "source": "hostPattern",
      "hostPattern": "^github\\.example\\.com$"
    }
  ]
}
```

**Behavior:**
- `undefined` (default): No restrictions
- Empty array `[]`: Complete lockdown
- List of sources: Only allow specified sources

**Note:** Exact matching required for all fields including optional `ref` and `path`.

## Excluding Sensitive Files

```json
{
  "permissions": {
    "deny": [
      "Read(./.env)",
      "Read(./.env.*)",
      "Read(./secrets/**)",
      "Read(./config/credentials.json)",
      "Read(./build)"
    ]
  }
}
```

## Environment Variables

### Core API Variables

| Variable | Purpose |
|----------|---------|
| `ANTHROPIC_API_KEY` | API key for Claude SDK |
| `ANTHROPIC_AUTH_TOKEN` | Custom Authorization header value |
| `ANTHROPIC_CUSTOM_HEADERS` | Custom headers in `Name: Value` format |
| `ANTHROPIC_MODEL` | Name of model to use |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | Haiku-class model |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | Sonnet-class model |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | Opus-class model |

### Cloud Provider Variables

| Variable | Purpose |
|----------|---------|
| `ANTHROPIC_FOUNDRY_API_KEY` | Microsoft Foundry authentication |
| `ANTHROPIC_FOUNDRY_BASE_URL` | Full base URL for Foundry resource |
| `ANTHROPIC_FOUNDRY_RESOURCE` | Foundry resource name |
| `CLAUDE_CODE_USE_BEDROCK` | Use AWS Bedrock |
| `AWS_BEARER_TOKEN_BEDROCK` | Bedrock API key |
| `CLAUDE_CODE_USE_FOUNDRY` | Use Microsoft Foundry |
| `CLAUDE_CODE_USE_VERTEX` | Use Google Vertex AI |
| `VERTEX_REGION_CLAUDE_4_0_SONNET` | Override Vertex region |

### Bash & Command Variables

| Variable | Purpose |
|----------|---------|
| `BASH_DEFAULT_TIMEOUT_MS` | Default timeout for bash commands |
| `BASH_MAX_OUTPUT_LENGTH` | Max characters in bash output |
| `BASH_MAX_TIMEOUT_MS` | Maximum timeout for bash commands |
| `CLAUDE_CODE_SHELL` | Override automatic shell detection |
| `CLAUDE_CODE_SHELL_PREFIX` | Command prefix to wrap all bash commands |
| `CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR` | Return to original directory after each command |

### Configuration & Context Variables

| Variable | Purpose |
|----------|---------|
| `CLAUDE_CONFIG_DIR` | Customize where Claude Code stores configuration |
| `CLAUDE_CODE_TMPDIR` | Override temp directory |
| `CLAUDE_CODE_TASK_LIST_ID` | Share task list across sessions |
| `CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS` | Override token limit for file reads |
| `CLAUDE_CODE_MAX_OUTPUT_TOKENS` | Max output tokens (default: 32,000; max: 64,000) |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | Context capacity percentage for auto-compaction |

### Monitoring & Telemetry Variables

| Variable | Purpose |
|----------|---------|
| `CLAUDE_CODE_ENABLE_TELEMETRY` | Enable OpenTelemetry data collection |
| `CLAUDE_CODE_OTEL_HEADERS_HELPER_DEBOUNCE_MS` | Interval for refreshing OTel headers |
| `DISABLE_TELEMETRY` | Opt out of Statsig telemetry |
| `DISABLE_ERROR_REPORTING` | Opt out of Sentry error reporting |
| `DISABLE_BUG_COMMAND` | Disable `/bug` command |

### Advanced Variables

| Variable | Purpose |
|----------|---------|
| `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS` | Disable background task functionality |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | Disable auto-updater, telemetry, error reporting |
| `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS` | Disable anthropic-beta headers |
| `CLAUDE_CODE_HIDE_ACCOUNT_INFO` | Hide email and organization from UI |
| `MAX_THINKING_TOKENS` | Override extended thinking token budget |
| `DISABLE_PROMPT_CACHING` | Disable prompt caching for all models |
| `ENABLE_TOOL_SEARCH` | Control MCP tool search (`auto`, `true`, `false`) |

## Subagent Configuration

Subagents are stored as Markdown files with YAML frontmatter:

- **User subagents**: `~/.claude/agents/` - Available across all projects
- **Project subagents**: `.claude/agents/` - Project-specific, can be shared with team

See [subagents documentation](/en/sub-agents) for details.

## Tools Available to Claude

| Tool | Description | Permission Required |
|------|-------------|---------------------|
| **AskUserQuestion** | Ask multiple-choice questions | No |
| **Bash** | Execute shell commands | Yes |
| **TaskOutput** | Retrieve output from background task | No |
| **Edit** | Make targeted file edits | Yes |
| **ExitPlanMode** | Prompt to exit plan mode | Yes |
| **Glob** | Find files by pattern | No |
| **Grep** | Search patterns in files | No |
| **KillShell** | Kill running background bash shell | No |
| **MCPSearch** | Search and load MCP tools | No |
| **NotebookEdit** | Modify Jupyter notebook cells | Yes |
| **Read** | Read file contents | No |
| **Skill** | Execute a skill | Yes |
| **Task** | Run a sub-agent | No |
| **TaskCreate** | Create new task | No |
| **TaskGet** | Retrieve task details | No |
| **TaskList** | List tasks | No |

---

*Claude Code automatically creates timestamped backups of configuration files, retaining the five most recent backups to prevent data loss.*
