# Agents and Hooks

> Subagent configuration, pipeline patterns, hook events, matchers, and decision control.

Official source: [sub-agents.md](../officials/build_with_claude_code/sub-agents.md), [hooks.md](../officials/reference/hooks.md), [hooks-guide.md](../officials/build_with_claude_code/hooks-guide.md)

---

## Part 1: Agents (Subagents)

Subagents are specialized AI assistants running in isolated contexts with custom system prompts, tool access, and permissions. Claude delegates tasks based on the agent's `description`.

### Built-in Agents

| Agent | Model | Tools | Purpose |
|-------|-------|-------|---------|
| **Explore** | haiku | Read-only | Codebase search, file discovery. Thoroughness: quick/medium/very thorough |
| **Plan** | inherit | Read-only | Research for plan mode (no nesting) |
| **general-purpose** | inherit | All | Complex multi-step tasks requiring exploration + action |
| **Bash** | inherit | Terminal | Running commands in separate context |
| **Claude Code Guide** | haiku | — | Questions about Claude Code features |

### Agent File Format

Markdown with YAML frontmatter. Body = system prompt.

```markdown
---
name: code-reviewer
description: Reviews code for quality and best practices
tools: Read, Glob, Grep
model: sonnet
---

You are a code reviewer. Analyze code and provide specific,
actionable feedback on quality, security, and best practices.
```

### Frontmatter Fields

| Field | Required | Type | Description |
|-------|:--------:|------|-------------|
| `name` | Yes | string | Unique identifier (lowercase, hyphens) |
| `description` | Yes | string | When Claude should delegate. Include "use proactively" for eager delegation |
| `tools` | No | string | Allowlist of tools. Inherits all if omitted. See [available tools](#tool-control) |
| `disallowedTools` | No | string | Denylist — removed from inherited/specified tools |
| `model` | No | string | `sonnet`, `opus`, `haiku`, or `inherit` (default) |
| `permissionMode` | No | string | `default`, `acceptEdits`, `dontAsk`, `bypassPermissions`, `plan` |
| `maxTurns` | No | number | Max agentic turns before stopping |
| `skills` | No | array | Skills preloaded at startup (full content injected, not just available) |
| `mcpServers` | No | object | MCP servers: name references or inline definitions |
| `hooks` | No | object | Lifecycle hooks scoped to this agent |
| `memory` | No | string | Persistent memory scope: `user`, `project`, or `local` |
| `background` | No | boolean | `true` = always run as background task |
| `isolation` | No | string | `worktree` = run in temporary git worktree |

### Agent Scope & Priority

| Location | Scope | Priority |
|----------|-------|:--------:|
| `--agents` CLI flag | Current session | 1 (highest) |
| `.claude/agents/` | Project | 2 |
| `~/.claude/agents/` | User (all projects) | 3 |
| Plugin `agents/` | Where enabled | 4 (lowest) |

Same name → higher priority wins.

### Model Selection

| Value | Behavior |
|-------|----------|
| `inherit` | Same model as main conversation (default) |
| `sonnet` | Pin to Sonnet |
| `opus` | Pin to Opus |
| `haiku` | Pin to Haiku (fast, cheap) |

project-mapper stratification: haiku (validator, summarizer) / sonnet (analyzer, writer) / opus (elaborator).

### Tool Control

**Allowlist**: `tools: Read, Grep, Glob, Bash` — only these tools available.

**Denylist**: `disallowedTools: Write, Edit` — removed from inherited tools.

**Restrict subagent spawning** (main thread agents only): `tools: Task(worker, researcher), Read` — only these subagent types allowed.

**No Task in tools** = agent cannot spawn subagents. Subagents cannot spawn other subagents.

### Permission Modes

| Mode | Behavior |
|------|----------|
| `default` | Standard permission checking with prompts |
| `acceptEdits` | Auto-accept file edits |
| `dontAsk` | Auto-deny prompts (explicitly allowed tools still work) |
| `bypassPermissions` | Skip all checks (caution!) |
| `plan` | Read-only exploration |

Parent `bypassPermissions` takes precedence and cannot be overridden.

### Skill Preloading

`skills` field injects **full skill content** at startup — not just makes available for invocation.

```yaml
---
name: api-developer
skills:
  - api-conventions
  - error-handling-patterns
---
```

Subagents don't inherit skills from parent. Must list explicitly.

Inverse of `context: fork` in skills: agent controls system prompt, skill provides knowledge.

### Persistent Memory

`memory` field gives agent a persistent directory surviving across conversations.

| Scope | Location | Use case |
|-------|----------|----------|
| `user` | `~/.claude/agent-memory/<name>/` | Learnings across all projects (recommended default) |
| `project` | `.claude/agent-memory/<name>/` | Project-specific, shareable via VCS |
| `local` | `.claude/agent-memory-local/<name>/` | Project-specific, not committed |

When enabled: system prompt includes memory instructions + first 200 lines of `MEMORY.md`. Read/Write/Edit tools auto-enabled.

### Agent Pipeline Pattern

Chain agents for multi-step workflows. Each agent's output feeds the next.

project-mapper pipeline:

```
analyzer (sonnet, read-only) → returns JSON
  ↓
writer (sonnet, acceptEdits) → writes .claude/ docs from JSON
  ↓
validator (haiku, read-only) → checks links in docs
```

Key design:
- **JSON interface** between agents (structured, parseable)
- **Read-only** stages (analyzer, validator) use `permissionMode: plan`
- **Write** stage uses `permissionMode: acceptEdits`
- Each agent has `skills:` preloading format rules

### Agent Definition via CLI

Temporary, session-only agents:

```bash
claude --agents '{
  "code-reviewer": {
    "description": "Expert code reviewer",
    "prompt": "You are a senior reviewer...",
    "tools": ["Read", "Grep", "Glob"],
    "model": "sonnet"
  }
}'
```

Same fields as frontmatter. `prompt` = markdown body equivalent.

### Disable Specific Agents

In settings.json `permissions.deny`:

```json
{ "permissions": { "deny": ["Task(Explore)", "Task(my-agent)"] } }
```

Or: `claude --disallowedTools "Task(Explore)"`

### Foreground vs Background

- **Foreground**: blocks main conversation. Permission prompts pass through.
- **Background**: concurrent. Pre-approves permissions before launch. Auto-denies unapproved tools. MCP tools unavailable. Failed permission → resume in foreground.

`background: true` in frontmatter or ask Claude to "run in the background". Press Ctrl+B to background a running task.

Disable: `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`.

### Resuming Agents

Each invocation creates fresh context. Ask Claude to "continue that work" to resume with full history. Agent IDs in transcripts at `~/.claude/projects/{project}/{sessionId}/subagents/agent-{agentId}.jsonl`.

Subagent transcripts persist independently of main conversation compaction.

---

## Part 2: Hooks

Hooks are shell commands, LLM prompts, or agents that execute at specific lifecycle points.

### Hook Events (15)

| Event | When | Can Block? | Matcher |
|-------|------|:----------:|---------|
| `SessionStart` | Session begins/resumes | No | `startup`, `resume`, `clear`, `compact` |
| `UserPromptSubmit` | User submits prompt | Yes | (none) |
| `PreToolUse` | Before tool call | Yes | Tool name |
| `PermissionRequest` | Permission dialog shown | Yes | Tool name |
| `PostToolUse` | After tool succeeds | No | Tool name |
| `PostToolUseFailure` | After tool fails | No | Tool name |
| `Notification` | Notification sent | No | `permission_prompt`, `idle_prompt`, `auth_success`, `elicitation_dialog` |
| `SubagentStart` | Subagent spawned | No | Agent type name |
| `SubagentStop` | Subagent finishes | Yes | Agent type name |
| `Stop` | Claude finishes responding | Yes | (none) |
| `TeammateIdle` | Team member about to idle | Yes | (none) |
| `TaskCompleted` | Task marked complete | Yes | (none) |
| `PreCompact` | Before compaction | No | `manual`, `auto` |
| `ConfigChange` | Config file changes | Yes | `user_settings`, `project_settings`, `local_settings`, `policy_settings`, `skills` |
| `SessionEnd` | Session terminates | No | `clear`, `logout`, `prompt_input_exit`, `bypass_permissions_disabled`, `other` |

### Handler Types (3)

| Type | Description | Key Fields |
|------|-------------|------------|
| `command` | Execute shell command. Receives JSON on stdin | `command`, `async`, `timeout` (default 600s) |
| `prompt` | Single-turn LLM evaluation | `prompt`, `model`, `timeout` (default 30s) |
| `agent` | Multi-turn subagent with tools (Read, Grep, Glob) | `prompt`, `model`, `timeout` (default 60s) |

Common fields: `type` (required), `timeout`, `statusMessage`, `once` (skills only).

### Configuration Format

```json
{
  "hooks": {
    "EventName": [
      {
        "matcher": "regex pattern",
        "hooks": [
          {
            "type": "command",
            "command": "path/to/script.sh"
          }
        ]
      }
    ]
  }
}
```

### Hook Locations

| Location | Scope | Shareable |
|----------|-------|-----------|
| `~/.claude/settings.json` | All projects | No |
| `.claude/settings.json` | Single project | Yes (committed) |
| `.claude/settings.local.json` | Single project | No (gitignored) |
| Managed policy settings | Organization | Yes (admin) |
| Plugin `hooks/hooks.json` | When plugin enabled | Yes (bundled) |
| Skill/agent frontmatter | While component active | Yes (inline) |

Enterprise `allowManagedHooksOnly` can block user/project/plugin hooks.

### Matcher Patterns

Regex string filtering when hooks fire. Omit, use `"*"`, or `""` to match all.

| Event Group | Matches On | Examples |
|-------------|-----------|----------|
| Tool events (Pre/Post/Failure/Permission) | Tool name | `Bash`, `Edit\|Write`, `mcp__.*` |
| SessionStart | Start source | `startup`, `resume` |
| SessionEnd | Exit reason | `clear`, `logout` |
| Notification | Type | `permission_prompt` |
| Subagent events | Agent type | `Explore`, custom names |
| ConfigChange | Config source | `user_settings`, `skills` |
| PreCompact | Trigger | `manual`, `auto` |

MCP tool pattern: `mcp__<server>__<tool>`, e.g. `mcp__memory__create_entities`.

### Exit Codes

| Code | Meaning | Behavior |
|------|---------|----------|
| **0** | Success | Parse stdout for JSON. Proceed normally |
| **2** | Blocking error | Block action (for blocking events). stderr → error message |
| **Other** | Non-blocking error | stderr shown in verbose mode. Continue |

Exit code 2 blocking behavior varies by event — see [Can Block? column](#hook-events-15).

### JSON Output

On exit 0, stdout JSON controls behavior:

| Field | Default | Description |
|-------|---------|-------------|
| `continue` | `true` | `false` = stop Claude entirely |
| `stopReason` | — | Message to user when `continue: false` |
| `suppressOutput` | `false` | Hide stdout from verbose mode |
| `systemMessage` | — | Warning shown to user |

### Decision Control Patterns

**Top-level decision** (UserPromptSubmit, PostToolUse, PostToolUseFailure, Stop, SubagentStop, ConfigChange):

```json
{ "decision": "block", "reason": "Explanation" }
```

**PreToolUse** — hookSpecificOutput with 3 outcomes:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow|deny|ask",
    "permissionDecisionReason": "reason",
    "updatedInput": { "field": "new value" },
    "additionalContext": "extra info for Claude"
  }
}
```

**PermissionRequest** — hookSpecificOutput with allow/deny:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "allow|deny",
      "updatedInput": {},
      "updatedPermissions": {},
      "message": "for deny",
      "interrupt": false
    }
  }
}
```

**TeammateIdle, TaskCompleted** — exit code only (no JSON decision).

### Common Input Fields (stdin JSON)

All events receive:

| Field | Description |
|-------|-------------|
| `session_id` | Current session ID |
| `transcript_path` | Path to conversation JSON |
| `cwd` | Current working directory |
| `permission_mode` | Current permission mode |
| `hook_event_name` | Event that fired |

Plus event-specific fields (tool_name, tool_input, prompt, agent_type, etc.).

### PreToolUse Input (tool_input by tool)

| Tool | Key Fields |
|------|------------|
| **Bash** | `command`, `description`, `timeout`, `run_in_background` |
| **Write** | `file_path`, `content` |
| **Edit** | `file_path`, `old_string`, `new_string`, `replace_all` |
| **Read** | `file_path`, `offset`, `limit` |
| **Glob** | `pattern`, `path` |
| **Grep** | `pattern`, `path`, `glob`, `output_mode`, `-i`, `multiline` |
| **Task** | `prompt`, `description`, `subagent_type`, `model` |
| **WebFetch** | `url`, `prompt` |
| **WebSearch** | `query`, `allowed_domains`, `blocked_domains` |

### Hooks in Skills and Agents

Define hooks in frontmatter — scoped to component lifecycle, cleaned up on finish.

```yaml
---
name: secure-ops
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/security-check.sh"
---
```

For agents, `Stop` hooks auto-convert to `SubagentStop`.

`once: true` — run only once per session (skills only, not agents).

### Async Hooks

`async: true` on command hooks — run in background without blocking. Only `type: "command"`.

```json
{
  "type": "command",
  "command": "/path/to/run-tests.sh",
  "async": true,
  "timeout": 120
}
```

Cannot block or return decisions. Output delivered on next conversation turn via `systemMessage` or `additionalContext`.

### Prompt-Based Hooks

LLM evaluates whether to allow/block. Response: `{ "ok": true }` or `{ "ok": false, "reason": "..." }`.

```json
{
  "type": "prompt",
  "prompt": "Evaluate if Claude should stop: $ARGUMENTS. Check if tasks are complete.",
  "timeout": 30
}
```

`$ARGUMENTS` placeholder → hook input JSON. Supported events: PreToolUse, PostToolUse, PostToolUseFailure, PermissionRequest, UserPromptSubmit, Stop, SubagentStop, TaskCompleted.

### Agent-Based Hooks

Like prompt hooks but multi-turn with tool access (Read, Grep, Glob). Up to 50 turns.

```json
{
  "type": "agent",
  "prompt": "Verify all unit tests pass. Run the test suite. $ARGUMENTS",
  "timeout": 120
}
```

Same `{ "ok": true/false }` response. Useful when verification requires inspecting files or test output.

### SessionStart Special Features

**Additional context**: stdout text or `additionalContext` field added to Claude's context.

**Environment persistence**: write `export VAR=value` to `$CLAUDE_ENV_FILE` — persists for all session Bash commands. Only available in SessionStart.

### Stop Hook Safety

`stop_hook_active` field is `true` when already continuing from a stop hook. Check this to prevent infinite loops.

`last_assistant_message` — text of Claude's final response (avoids parsing transcript).

### Disabling Hooks

- Delete from settings or use `/hooks` menu
- `disableAllHooks: true` in settings (managed settings hierarchy applies)
- Hooks snapshot at startup — mid-session changes need review in `/hooks`

### Hook Debugging

```bash
claude --debug
```

Toggle verbose mode: Ctrl+O. Shows: matched hooks, exit codes, output.

### Security

Hooks run with full user permissions. Best practices:
- Validate/sanitize inputs
- Quote shell variables (`"$VAR"`)
- Block path traversal (check for `..`)
- Use absolute paths (`"$CLAUDE_PROJECT_DIR"`)
- Skip sensitive files (`.env`, `.git/`, keys)

## Real Examples

### project-mapper: Agent pipeline with tool restrictions

**analyzer.md** — read-only, returns JSON:
```yaml
tools: Read, Grep, Glob
model: sonnet
permissionMode: plan
skills:
  - project-mapper:map-sync
```

**writer.md** — edit permissions, writes docs:
```yaml
tools: Read, Write, Edit
model: sonnet
permissionMode: acceptEdits
skills:
  - project-mapper:map-sync
```

**validator.md** — cheap model, link checking:
```yaml
tools: Read, Grep, Glob
model: haiku
permissionMode: plan
```

Pattern: read-only stages use `plan`, write stage uses `acceptEdits`. Skills inject shared format knowledge. Model cost scales with task complexity.
