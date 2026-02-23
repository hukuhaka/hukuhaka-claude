# Skills

> SKILL.md format, frontmatter fields, patterns, bundled resources.

Official source: [skills.md](../officials/build_with_claude_code/skills.md)

## SKILL.md Format

Every skill is a directory containing a required `SKILL.md` file:

```
skill-name/
├── SKILL.md              # Required: frontmatter + instructions
├── scripts/              # Optional: executable code
├── references/           # Optional: loaded into context on demand
└── assets/               # Optional: files used in output (templates, images)
```

SKILL.md = YAML frontmatter (between `---` markers) + Markdown body.

Frontmatter: tells Claude **when** to use the skill (always in context as metadata ~100 words).
Body: tells Claude **how** to use the skill (loaded only when triggered, target <500 lines).

## Frontmatter Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | string | directory name | Display name, lowercase/hyphens only, max 64 chars |
| `description` | string | first paragraph | **Primary trigger** — Claude uses this to decide when to invoke. Include both what and when |
| `argument-hint` | string | — | Hint shown in autocomplete, e.g. `[issue-number]` |
| `disable-model-invocation` | boolean | `false` | `true` = only user can invoke via `/name` |
| `user-invocable` | boolean | `true` | `false` = hidden from `/` menu, only Claude invokes |
| `allowed-tools` | string | — | Tools permitted without asking, e.g. `Read, Grep, Glob` |
| `model` | string | — | Model when skill is active |
| `context` | string | — | `fork` = run in isolated subagent context |
| `agent` | string | — | Subagent type when `context: fork`, e.g. `Explore`, `Plan`, custom name |
| `hooks` | object | — | Lifecycle hooks scoped to this skill. Same format as settings.json hooks |

All fields are optional. Only `description` is recommended.

## String Substitutions

| Variable | Description |
|----------|-------------|
| `$ARGUMENTS` | All arguments passed when invoking. If absent in content, appended as `ARGUMENTS: <value>` |
| `$ARGUMENTS[N]` | Specific argument by 0-based index |
| `$N` | Shorthand for `$ARGUMENTS[N]` — `$0` = first, `$1` = second |
| `${CLAUDE_SESSION_ID}` | Current session ID for logging/correlation |

Example: `/migrate-component SearchBar React Vue` → `$0`=SearchBar, `$1`=React, `$2`=Vue.

## Dynamic Context Injection

The `` !`command` `` syntax runs shell commands **before** Claude sees the skill content (preprocessing). Output replaces the placeholder.

```yaml
---
name: pr-summary
context: fork
agent: Explore
---

- PR diff: !`gh pr diff`
- Changed files: !`gh pr diff --name-only`

Summarize this pull request.
```

Claude receives the rendered output, not the commands.

## Content Patterns

### Reference (knowledge)

Background knowledge Claude applies to current work. Runs inline in main context.

```yaml
---
name: api-conventions
description: API design patterns for this codebase
---

When writing API endpoints:
- Use RESTful naming
- Return consistent error formats
```

### Task (execution)

Step-by-step instructions for specific actions. Typically `disable-model-invocation: true`.

```yaml
---
name: deploy
description: Deploy the application to production
disable-model-invocation: true
context: fork
---

Deploy the application:
1. Run test suite
2. Build
3. Push to deployment target
```

### Router (router + references)

Routes subcommands to different behaviors. References hold detailed instructions.

Example: [map-sync SKILL.md](../../marketplace/project-mapper/skills/map-sync/SKILL.md) routes to [sync-pipeline.md](../../marketplace/project-mapper/skills/map-sync/references/sync-pipeline.md) and [format-rules.md](../../marketplace/project-mapper/skills/map-sync/references/format-rules.md).

## Invocation Control Matrix

| Frontmatter | User can invoke | Claude can invoke | Context loading |
|-------------|:-:|:-:|---|
| (default) | Yes | Yes | Description always in context; body loads when invoked |
| `disable-model-invocation: true` | Yes | No | Description NOT in context; body loads on user invoke |
| `user-invocable: false` | No | Yes | Description always in context; body loads when invoked |

Note: `user-invocable` only controls menu visibility, NOT Skill tool access. Use `disable-model-invocation: true` to block programmatic invocation.

## Subagent Execution

Add `context: fork` to run in isolation. Skill content becomes the subagent's task prompt. No access to conversation history.

| Approach | System prompt | Task |
|----------|---------------|------|
| Skill + `context: fork` | From `agent` type (Explore, Plan, etc.) | SKILL.md content |
| Agent + `skills` field | Agent's markdown body | Claude's delegation message |

`agent` field options: built-in (`Explore`, `Plan`, `general-purpose`) or custom from `.claude/agents/`. Default: `general-purpose`.

## Bundled Resources

### scripts/

Executable code for deterministic/repeated tasks. Token-efficient — can be executed without loading into context.

- When: same code repeatedly rewritten, deterministic reliability needed
- Test added scripts before shipping

### references/

Documentation loaded on demand into context.

- When: detailed schemas, API docs, domain knowledge
- Keep `SKILL.md` lean — reference with links: `See [reference.md](reference.md)`
- For large files (>10K words): include grep patterns in SKILL.md
- Avoid duplication between SKILL.md and reference files

### assets/

Files used in output, not loaded into context.

- When: templates, images, boilerplate code
- Examples: `assets/logo.png`, `assets/template.html`

## Progressive Disclosure

Three-level loading system:

1. **Metadata** (name + description) — always in context (~100 words)
2. **SKILL.md body** — when skill triggers (<5K words, target <500 lines)
3. **Bundled resources** — as needed (unlimited; scripts can execute without reading)

Split patterns:
- **High-level guide + references**: SKILL.md overview → reference files for details
- **Domain-specific**: organize by domain (e.g., `references/finance.md`, `references/sales.md`)
- **Conditional details**: basic in SKILL.md, advanced in separate files

Keep references one level deep from SKILL.md. Include TOC in files >100 lines.

## Skill Location & Priority

| Location | Path | Applies to |
|----------|------|------------|
| Enterprise | Managed settings | All org users |
| Personal | `~/.claude/skills/<name>/SKILL.md` | All your projects |
| Project | `.claude/skills/<name>/SKILL.md` | Current project |
| Plugin | `<plugin>/skills/<name>/SKILL.md` | Where plugin enabled |

Priority: enterprise > personal > project. Plugin skills use `plugin-name:skill-name` namespace (no conflicts).

Nested discovery: `.claude/skills/` in subdirectories auto-discovered (monorepo support).

Additional directories: skills from `--add-dir` paths are loaded and live-reloaded.

## Skill Access Control

Three levels:
- **Deny Skill tool** in `/permissions`: blocks all skills
- **Per-skill rules**: `Skill(commit)` allow, `Skill(deploy *)` deny
- **Per-skill frontmatter**: `disable-model-invocation: true` removes from Claude's context

Permission syntax: `Skill(name)` exact match, `Skill(name *)` prefix match with arguments.

## Context Budget

Skill descriptions share a budget of ~2% of context window (fallback: 16,000 chars). Many skills may exceed this — check with `/context`. Override: `SLASH_COMMAND_TOOL_CHAR_BUDGET` env variable.

## Real Examples

### Router skill: map-sync

```yaml
---
name: map-sync
description: >
  Generate .claude/ project documentation via sync pipeline.
  Use when user asks to map or sync .claude/ docs.
  Do NOT use for init/clean/status (map-setup) or validate/compact/summary (map-maintain).
---
```

Body: routes to agents (analyzer → writer → validator), references detailed pipeline in `references/sync-pipeline.md`.

### Direct execution: map-setup

```yaml
---
name: map-setup
description: >
  Setup and teardown for .claude/ project docs.
  Use when user asks to init or clean .claude/ docs.
---
```

Body: handles `init` and `clean` subcommands directly. Explicitly states "Do NOT spawn any Task agents."

### Standalone skill: skill-creator

```yaml
---
name: skill-creator
description: Guide for creating effective skills. Use when users want to create
  a new skill that extends Claude's capabilities.
license: Complete terms in LICENSE.txt
---
```

Body: 6-step creation process with scripts (`init_skill.py`, `package_skill.py`).

## Best Practices

- **Target <500 lines** for SKILL.md body; split into references when approaching limit
- **Description is the trigger** — include what + when; be comprehensive
- **Imperative/infinitive form** for instructions
- **Match freedom to fragility**: high (guidelines), medium (pseudocode), low (scripts with exact sequences)
- **Challenge each token**: "Does Claude really need this?" Default assumption: Claude is smart
- **No extra docs**: no README.md, INSTALLATION_GUIDE.md, CHANGELOG.md in skill directory
- **One source of truth**: info lives in SKILL.md OR reference files, not both
