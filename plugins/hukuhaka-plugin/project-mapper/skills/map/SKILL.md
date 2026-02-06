---
name: map
description: >
  Codebase documentation generator. Commands:
  init, sync, full-sync, scatter, analyze, validate, diff, status, prune, clean, summary, import
---

# Project Mapper

Generate and maintain `.claude/` documentation.

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

---

## Agents

| Agent | Model | Role |
|-------|-------|------|
| analyzer | sonnet | Code analysis → JSON |
| writer | sonnet | JSON → .claude/ docs |
| validator | haiku | Link verification |
| summarizer | haiku | Compress docs |
| migrator | sonnet | Import existing docs |

---

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `--model <m>` | (per agent) | Override model for all agents: `haiku`, `sonnet`, `opus` |

**Usage:**
```
/project-mapper:map sync . --model opus
/project-mapper:map full-sync . --model sonnet
```

When `--model` specified, ALL spawned agents use that model instead of their defaults.

---

## Command Details

### init

Create empty `.claude/` folder with templates:
```
.claude/
├── map.md            # Empty template
├── design.md         # Empty template
├── implementation.md # With Planned/In Progress sections
└── changelog.md      # Empty Recent/Archive
```

No analysis, just scaffolding for manual editing.

### sync [path]

**Full pipeline: index → analyze → write**

1. Refresh code search index
2. Spawn analyzer
3. Spawn writer with results

```
mcp__code-search__index_directory(path)
Task(subagent_type: "analyzer", model: {model}, prompt: "Analyze {path}")
Task(subagent_type: "writer", model: {model}, prompt: "Generate .claude/ from: {json}")
```

Note: `{model}` = user-specified or omit for agent default.

### full-sync [path]

**One-stop complete documentation:**

1. Run `sync`
2. Run `scatter`
3. Run `validate`

**Final Report:**
```
✓ Full sync complete
  ─────────────────────────────────
  Phase 1 (sync)
    Files scanned: 42
    Queries run: 5
    Docs generated: 4 (map.md, design.md, implementation.md, changelog.md)
    Entry points: 3
    Components: 8
    TODOs: 12

  Phase 2 (scatter)
    Folders processed: 6
    CLAUDE.md created: 6

  Phase 3 (validate)
    Links checked: 23
    Valid: 23
    Broken: 0
  ─────────────────────────────────
```

### scatter [path]

Generate `CLAUDE.md` in each subdirectory.

**Rules:**
- Never touch root `./CLAUDE.md`
- Respect `.gitignore`
- Merge if exists

**Options:**
- `--depth N`: Max depth (default: 3)

```
For each subdir:
  Task(subagent_type: "analyzer", model: {model}, prompt: "scatter: {folder}")
  Task(subagent_type: "writer", model: {model} or "haiku", prompt: "scatter: {json}")
```

### analyze [path]

Analysis only, returns JSON:
```
Task(subagent_type: "analyzer", model: {model}, prompt: "Analyze {path}")
```

### validate

Check all references in `.claude/`:
```
Task(subagent_type: "validator", model: {model}, prompt: "Validate .claude/ links")
```

### diff

Compare `.claude/` docs with current code:
1. Read existing docs
2. Analyze current state
3. Report: Added, Removed, Changed

### status

Direct MCP call:
```
mcp__code-search__get_index_status()
```

### prune

Trigger changelog cleanup:
```
Task(subagent_type: "writer", model: {model}, prompt: "Prune changelog.md")
```

- Keep recent 10 entries
- Consolidate older to Archive by month

### clean

Remove all scattered CLAUDE.md files:

```
Glob: **/CLAUDE.md (exclude root)
Delete each found file
```

Report: count deleted, paths

### summary

Compress `.claude/` for LLM context:
```
Task(subagent_type: "summarizer", model: {model}, prompt: "Summarize .claude/")
```

Output: Single markdown block, <500 lines

### import

Import from existing documentation:
```
Task(subagent_type: "migrator", model: {model}, prompt: "Import from existing docs")
Task(subagent_type: "writer", model: {model}, prompt: "Generate .claude/ from: {migrator_json}")
```

Sources: README.md, docs/, ARCHITECTURE.md, etc.

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

---

## MCP Tools

- `get_index_status`: Check index freshness
- `index_directory`: Index codebase
- `search_code`: Semantic search
- `find_similar_code`: Related code
