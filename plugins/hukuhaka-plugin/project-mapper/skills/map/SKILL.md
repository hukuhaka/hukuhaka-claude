---
name: map
description: >
  Use when generating, updating, or validating .claude/ project documentation.
---

# Project Mapper

Generate and maintain `.claude/` documentation.

## Purpose

- Generate project documentation from codebase analysis
- Keep `.claude/` docs in sync with code changes
- Validate documentation links and references
- Import from existing documentation

## Commands

| Command | Description | Writes |
|---------|-------------|--------|
| `init` | Create empty .claude/ template | Yes |
| `sync [path]` | Index + analyze + generate docs | Yes |
| `full-sync [path]` | sync + scatter + validate | Yes |
| `scatter [path]` | CLAUDE.md in subdirectories | Yes |
| `analyze [path]` | Analyze only (JSON output) | No |
| `validate` | Check all links | No |
| `diff` | Compare docs vs current code | No |
| `status` | Index state | No |
| `prune` | Clean up changelog | Yes |
| `clean` | Remove scattered CLAUDE.md files | Yes |
| `summary` | Compress docs for LLM context | No |
| `import` | Import from existing docs | Yes |

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `--model <m>` | (per agent) | Override model for all agents: `haiku`, `sonnet`, `opus` |

## Usage

```
/project-mapper:map init
/project-mapper:map sync .
/project-mapper:map full-sync . --model opus
/project-mapper:map scatter src/
/project-mapper:map validate
```

---

## Iron Law

**YOU MUST DELEGATE.** You are an orchestrator, NOT a worker.

For commands that require agents (sync, full-sync, scatter, analyze, validate, prune, summary, import), you MUST spawn the required agent(s) via Task calls. You MUST NOT:
- Analyze code yourself
- Generate documentation yourself
- Skip agent spawning for any reason
- Perform the agent's work "because it seems simple"

No exceptions. No shortcuts. No rationalizations.

**Exception:** `init`, `status`, `diff`, `clean` do NOT require agents — handle these directly.

**Agents for this skill:**

| Agent | Qualified Name | Role |
|-------|---------------|------|
| analyzer | `project-mapper:analyzer` | Code analysis → JSON |
| writer | `project-mapper:writer` | JSON → .claude/ docs |
| validator | `project-mapper:validator` | Link verification |
| summarizer | `project-mapper:summarizer` | Compress docs |
| migrator | `project-mapper:migrator` | Import existing docs |

**CRITICAL:** All `subagent_type` values MUST use fully qualified names with `project-mapper:` prefix.
Do NOT use bare names like `"analyzer"` — always use `"project-mapper:analyzer"`.

---

## Pre-flight

**BEFORE any agent-spawning command:**

1. Read `.claude/map.md` and `.claude/design.md`
2. If both are missing AND command is NOT `init`, `sync`, `full-sync`, or `import` → inform user: "Run `/project-mapper:map init` first" and STOP
3. For `init`, `sync`, `full-sync`, `import`: proceed even without existing docs (they will be created)

---

## The Process

### init

Create all 4 files unconditionally:
```
.claude/
├── map.md
├── design.md
├── implementation.md
└── changelog.md
```

If files already exist, overwrite with fresh templates.
Do NOT skip initialization because files exist.
No analysis, no agents — just scaffolding.

### sync [path]

**Full pipeline: index → analyze → write**

**NON-NEGOTIABLE PIPELINE:** You MUST execute all 3 steps. Do NOT skip agents or write files directly.

**Step 1:** Call mcp__code-search__index_directory and WAIT for completion.
```
mcp__code-search__index_directory(path)
```

**Step 2:** ONLY AFTER indexing completes, spawn analyzer and WAIT for its JSON result.
```
Task(subagent_type: "project-mapper:analyzer", model: {model}, prompt: "Analyze {path}")
```

**Step 3:** ONLY AFTER analyzer completes, spawn writer with analyzer's output.
```
Task(subagent_type: "project-mapper:writer", model: {model}, prompt: "Generate .claude/ from: {analyzer JSON result}")
```

If any step fails, explain the failure. Do NOT attempt workarounds or write files directly.

### full-sync [path]

**One-stop complete documentation — 3 sequential phases.**

**WARNING:** Each phase MUST complete before the next begins. Do NOT run phases in parallel.

**Phase 1 (sync):** index → analyzer → writer (sequential, wait between each)
Run the full `sync` pipeline above. WAIT for all 3 sync steps to complete.

**Phase 2 (scatter):** ONLY AFTER Phase 1 completes.
Run `scatter` on the path. WAIT for completion.

**Phase 3 (validate):** ONLY AFTER Phase 2 completes.
Run `validate`. WAIT for completion.

**Final Report:**
```
✓ Full sync complete
  ─────────────────────────────────
  Phase 1 (sync)
    Files scanned: {n}
    Docs generated: 4

  Phase 2 (scatter)
    CLAUDE.md created: {n}

  Phase 3 (validate)
    Links checked: {n}
    Broken: {n}
  ─────────────────────────────────
```

### scatter [path]

Generate `CLAUDE.md` in each subdirectory.

**DELEGATION RULE:** You MUST spawn `project-mapper:analyzer` then `project-mapper:writer` for each subdirectory. Do NOT write CLAUDE.md files yourself.

**Rules:**
- Never touch root `./CLAUDE.md`
- Respect `.gitignore`
- Merge if exists

**Options:**
- `--depth N`: Max depth (default: 3)

```
For each subdir:
  Task(subagent_type: "project-mapper:analyzer", model: {model}, prompt: "scatter: {folder}")
  → WAIT for result →
  Task(subagent_type: "project-mapper:writer", model: {model} or "haiku", prompt: "scatter: {json}")
```

### analyze [path]

Analysis only, returns JSON:
```
Task(subagent_type: "project-mapper:analyzer", model: {model}, prompt: "Analyze {path}")
```

### validate

Check all references in `.claude/`:
```
Task(subagent_type: "project-mapper:validator", model: {model}, prompt: "Validate .claude/ links")
```

### diff

Compare `.claude/` docs with current code:
1. Read existing docs
2. Analyze current state
3. Report: Added, Removed, Changed

### status

Direct MCP call (no agent needed):
```
mcp__code-search__get_index_status()
```

### prune

Trigger changelog cleanup:
```
Task(subagent_type: "project-mapper:writer", model: {model}, prompt: "Prune changelog.md")
```

- Keep recent 10 entries
- Consolidate older to Archive by month

### clean

Remove all scattered CLAUDE.md files (no agent needed):

```
Glob: **/CLAUDE.md (exclude root)
Delete each found file
```

Report: count deleted, paths

### summary

Compress `.claude/` for LLM context:
```
Task(subagent_type: "project-mapper:summarizer", model: {model}, prompt: "Summarize .claude/")
```

Output: Single markdown block, <500 lines

### import

Import from existing documentation (README.md, docs/, ARCHITECTURE.md, etc).

**WARNING:** These steps are SEQUENTIAL — do NOT call both agents in the same message.

**Step 1:** Spawn migrator and WAIT for its JSON result.
```
Task(subagent_type: "project-mapper:migrator", model: {model}, prompt: "Import from existing docs")
```

**Step 2:** ONLY AFTER migrator completes, spawn writer with migrator's output.
```
Task(subagent_type: "project-mapper:writer", model: {model}, prompt: "Generate .claude/ from: {migrator JSON result}")
```

---

## Common Mistakes

| Mistake | Correction |
|---------|------------|
| Bare agent name `"analyzer"` | Fully qualified `"project-mapper:analyzer"` |
| Writing .claude/ docs yourself | ALWAYS spawn writer agent with analyzer output |
| Running sync steps in parallel | Steps are SEQUENTIAL: index → analyzer → writer |
| Running import agents in parallel | migrator MUST complete before writer starts |
| Scatter without analyzer+writer | MUST use both agents per subdirectory |
| Skipping .claude/ pre-loading | ALWAYS Read map.md and design.md FIRST |
| Retrying denied permissions 5+ times | After 2 failures, inform user and ask |
| Output without agent result | Output MUST be based on agent's returned data |

---

## Red Flags

If you find yourself doing any of these, STOP and re-read the Iron Law:

- Using Read/Grep/Glob to analyze code instead of spawning a Task
- Using bare agent names without `project-mapper:` prefix
- Running sequential agents in the same message (parallel)
- Skipping pre-flight .claude/ doc loading
- Continuing after pre-flight failure
- Writing .claude/ markdown files directly instead of using writer agent

---

## Generated Files

### .claude/map.md
Entry points, data flow, components, structure

### .claude/design.md
Stack, patterns, key decisions

### .claude/implementation.md
- **Planned**: User-maintained future plans
- **In Progress**: User-maintained current work
- **Discovered TODOs**: Auto-scanned from code

### .claude/changelog.md
- **Recent**: Latest 10 changes
- **Archive**: Consolidated by month

---

## Related Skills

- `project-mapper:review` - Code review with context
- `project-mapper:query` - Answer project questions

## MCP Tools

- `get_index_status`: Check index freshness
- `index_directory`: Index codebase
- `search_code`: Semantic search
- `find_similar_code`: Related code
