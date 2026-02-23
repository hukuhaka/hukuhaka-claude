# Distribution

> Marketplace schema, plugin sources, version management, CI/CD, eval.

Official source: [plugin-marketplaces.md](../officials/administration/plugin-marketplaces.md), [discover-plugins.md](../officials/build_with_claude_code/discover-plugins.md)

## Distribution Options

| Method | How | Best for |
|--------|-----|----------|
| Local path | `claude --plugin-dir ./my-plugin` | Development/testing |
| Direct install | Share repo, user runs `claude plugin install` | Small teams |
| Marketplace | Create marketplace.json, host on GitHub | Teams, community |

## marketplace.json Schema

Place at `.claude-plugin/marketplace.json` in repository root.

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Marketplace identifier (kebab-case). Public-facing: `plugin@your-marketplace` |
| `owner` | object | `{name: string, email?: string}` |
| `plugins` | array | List of plugin entries |

Reserved names: `claude-code-marketplace`, `claude-code-plugins`, `claude-plugins-official`, `anthropic-marketplace`, `anthropic-plugins`, `agent-skills`, `life-sciences`.

### Optional Metadata

| Field | Type | Description |
|-------|------|-------------|
| `metadata.description` | string | Brief marketplace description |
| `metadata.version` | string | Marketplace version |
| `metadata.pluginRoot` | string | Base dir for relative paths (e.g. `"./plugins"`) |

### Plugin Entry Fields

Each entry in `plugins` array:

**Required**: `name` (string), `source` (string or object)

**Standard metadata**: `description`, `version`, `author`, `homepage`, `repository`, `license`, `keywords`

**Marketplace-specific**: `category`, `tags`, `strict` (boolean, default true)

**Component overrides**: `commands`, `agents`, `hooks`, `mcpServers`, `lspServers`

### Complete Example

```json
{
  "name": "company-tools",
  "owner": { "name": "DevTools Team", "email": "dev@example.com" },
  "metadata": { "description": "Internal tooling plugins" },
  "plugins": [
    {
      "name": "code-formatter",
      "source": "./plugins/formatter",
      "description": "Auto-format on save",
      "version": "2.1.0"
    },
    {
      "name": "deploy-tools",
      "source": { "source": "github", "repo": "company/deploy-plugin" },
      "description": "Deployment automation"
    }
  ]
}
```

## Plugin Sources (5 types)

### Relative Path

Local directory within marketplace repo. Must start with `./`.

```json
{ "name": "my-plugin", "source": "./plugins/my-plugin" }
```

Only works with git-based marketplaces (not URL-based).

### GitHub

```json
{
  "name": "github-plugin",
  "source": {
    "source": "github",
    "repo": "owner/plugin-repo",
    "ref": "v2.0.0",
    "sha": "a1b2c3d4e5f6..."
  }
}
```

Fields: `repo` (required), `ref` (branch/tag, optional), `sha` (40-char commit, optional).

### Git URL

```json
{
  "name": "git-plugin",
  "source": {
    "source": "url",
    "url": "https://gitlab.com/team/plugin.git",
    "ref": "main"
  }
}
```

Fields: `url` (required, must end `.git`), `ref` (optional), `sha` (optional).

### npm

```json
{
  "name": "npm-plugin",
  "source": {
    "source": "npm",
    "package": "@company/plugin",
    "version": "^1.0.0",
    "registry": "https://registry.npmjs.org"
  }
}
```

Fields: `package` (required), `version` (optional), `registry` (optional).

### pip

```json
{
  "name": "pip-plugin",
  "source": {
    "source": "pip",
    "package": "my-plugin",
    "version": ">=1.0.0"
  }
}
```

Fields: `package` (required), `version` (optional), `registry` (optional).

**Note**: npm and pip sources are not yet fully implemented. Prefer GitHub or relative path.

### Marketplace Source vs Plugin Source

- **Marketplace source**: where to fetch `marketplace.json` itself. Set via `/plugin marketplace add` or `extraKnownMarketplaces`. Supports `ref` but not `sha`.
- **Plugin source**: where to fetch individual plugin within marketplace. Set in `source` field of plugin entry. Supports `ref` and `sha`.

## Strict Mode

Controls whether `plugin.json` is authority for component definitions.

| Value | Behavior |
|-------|----------|
| `true` (default) | plugin.json is authority. Marketplace supplements (both merged) |
| `false` | Marketplace entry is entire definition. Conflicting plugin.json = load failure |

Use `true` when plugin manages its own components. Use `false` when marketplace operator wants full control.

## Marketplace Hosting

### GitHub (recommended)

1. Create repo with `.claude-plugin/marketplace.json`
2. Users add: `/plugin marketplace add owner/repo`

### Other Git Services

```
/plugin marketplace add https://gitlab.com/company/plugins.git
```

### Private Repositories

Manual install uses existing git credential helpers (`gh auth`, macOS Keychain, etc.).

Background auto-updates need environment tokens:

| Provider | Variables |
|----------|-----------|
| GitHub | `GITHUB_TOKEN` or `GH_TOKEN` |
| GitLab | `GITLAB_TOKEN` or `GL_TOKEN` |
| Bitbucket | `BITBUCKET_TOKEN` |

## Team Configuration

### extraKnownMarketplaces

In `.claude/settings.json` (committed):

```json
{
  "extraKnownMarketplaces": {
    "company-tools": {
      "source": { "source": "github", "repo": "org/claude-plugins" }
    }
  }
}
```

Team members prompted to install when trusting project folder.

### enabledPlugins

```json
{
  "enabledPlugins": {
    "formatter@company-tools": true,
    "deploy@company-tools": true
  }
}
```

## Managed Restrictions (Enterprise)

`strictKnownMarketplaces` in managed settings:

| Value | Behavior |
|-------|----------|
| Undefined | No restrictions |
| `[]` | Complete lockdown — no new marketplaces |
| List of sources | Only matching marketplaces allowed |

Supports exact matching and `hostPattern` regex:

```json
{
  "strictKnownMarketplaces": [
    { "source": "github", "repo": "acme-corp/approved-plugins" },
    { "source": "hostPattern", "hostPattern": "^github\\.example\\.com$" }
  ]
}
```

Cannot be overridden by user/project settings.

## Version Management

Semver in plugin.json: `MAJOR.MINOR.PATCH`

- **MAJOR**: breaking changes
- **MINOR**: new features (backward-compatible)
- **PATCH**: bug fixes

Version determines cache path and update detection. **Must bump version** for users to see changes (caching).

Can set version in plugin.json or marketplace entry — plugin.json always wins when both present. For relative-path plugins, set in marketplace. For external sources, set in plugin.json.

### Release Channels

Two marketplaces pointing to different refs:

```json
// stable-tools marketplace
{ "source": { "source": "github", "repo": "org/plugin", "ref": "stable" } }

// latest-tools marketplace
{ "source": { "source": "github", "repo": "org/plugin", "ref": "latest" } }
```

Assign via managed `extraKnownMarketplaces` to different user groups.

**Important**: plugin.json must declare different `version` at each ref — same version = skip update.

## Validation & Testing

### CLI Validation

```bash
claude plugin validate .          # Validate plugin/marketplace JSON
```

Or from TUI: `/plugin validate .`

### Local Test Workflow

```bash
# 1. Test plugin directly
claude --plugin-dir ./my-plugin

# 2. Test marketplace locally
/plugin marketplace add ./my-marketplace
/plugin install test-plugin@my-marketplace

# 3. Debug loading issues
claude --debug
```

### Validate Script (project-mapper)

[validate.sh](../../scripts/validate.sh) runs:
1. JSON syntax check (plugin.json, eval specs/scenarios)
2. SKILL.md frontmatter validation (name + description required)
3. `deploy.sh --dry-run`

```bash
scripts/validate.sh
```

## Eval Framework

[eval/](../../eval/) provides transcript-based LLM-as-judge evaluation:

| Component | Path | Purpose |
|-----------|------|---------|
| Specs | `eval/specs/*.json` | Expected behavior definitions |
| Scenarios | `eval/scenarios/*.json` | Test cases |
| Runner | `eval/run_eval.sh` | Transcript capture + judge pipeline |
| Judge | `eval/eval_logic.py`, `eval/eval_quality.py` | LLM evaluates transcript compliance |

Workflow: capture transcript via `claude --print` → truncate (150/200/500 char limits) → LLM judge scores compliance.

`--cache` flag: reuse captured transcript, re-run judge only.

## CI/CD

### validate.yml (PR)

Runs `scripts/validate.sh` on every pull request.

### release.yml (tag push)

On tag push matching `v*`: create GitHub Release with tarball. Version in tag must match plugin.json version.

### Deploy Script (project-mapper)

[deploy.sh](../../scripts/deploy.sh) — manifest-based deploy:

```bash
scripts/deploy.sh              # Deploy to ~/.claude/
scripts/deploy.sh --dry-run    # Preview
scripts/deploy.sh --uninstall  # Remove
```

Features:
- Tracks installed files in `~/.claude/.hukuhaka-manifest.json`
- Generates marketplace manifest for plugin discovery
- Registers plugin in settings.json, installed_plugins.json, known_marketplaces.json
- Removes stale files from previous versions
- Handles pre-manifest migration

### Install Script

[install.sh](../../scripts/install.sh) — curl one-liner for end users:

```bash
curl -fsSL https://raw.githubusercontent.com/.../install.sh | bash
```

Downloads tarball from latest GitHub Release, runs deploy.sh.

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Marketplace not loading | Missing/invalid marketplace.json | Check `.claude-plugin/marketplace.json` exists, validate JSON |
| Relative paths fail | URL-based marketplace (not git) | Use GitHub/npm sources or git-based marketplace |
| Files not found after install | Path traversal outside plugin dir | Use symlinks, restructure to keep files in plugin |
| Private repo auth fails | Missing token | Set `GITHUB_TOKEN`/`GITLAB_TOKEN` in environment |
| Update not detected | Same version in plugin.json | Bump version before distributing changes |
| Duplicate plugin name | Two entries share name | Each plugin needs unique `name` |
