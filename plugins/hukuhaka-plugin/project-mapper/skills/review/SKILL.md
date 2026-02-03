---
name: review
description: >
  Code review with .claude/ context. Commands:
  pr [number] - review PR with project context,
  changes [path] - review local changes,
  file [path] - review specific file
---

# Review

Code review powered by `.claude/` project documentation.

## Purpose

- Review code with full architectural context
- Check changes against documented patterns and decisions
- Identify violations of project conventions

## Commands

| Command | Description |
|---------|-------------|
| `pr [number]` | Review GitHub PR with context |
| `changes [path]` | Review uncommitted changes |
| `file [path]` | Review specific file |

## Workflow

### 1. Load Context

Read `.claude/` documentation:
- design.md → Patterns, Decisions
- map.md → Components, Structure
- implementation.md → Current plans

### 2. Analyze Changes

For PR:
```
gh pr diff {number}
```

For local changes:
```
git diff [path]
```

For file:
```
Read file + Grep for related code
```

### 3. Review Against Context

Check each change:

| Check | Source |
|-------|--------|
| Pattern compliance | design.md Patterns |
| Naming conventions | map.md Components |
| Architecture fit | design.md Decisions |
| TODO alignment | implementation.md Planned |

### 4. Output

```markdown
## Review: {target}

### Summary
{1-2 sentence overview}

### Findings

#### ✓ Good
- {positive observations}

#### ⚠ Suggestions
- {improvements, not blocking}

#### ✗ Issues
- {problems that should be fixed}

### Context Used
- Pattern: {referenced pattern from design.md}
- Decision: {relevant decision}
```

## Integration

Can be called by other plugins:
```
Task(
  subagent_type: "project-mapper:review",
  prompt: "Review changes in {path} against project patterns"
)
```

## MCP Tools

- `mcp__code-search__search_code`: Find related code
- `mcp__code-search__find_similar_code`: Check for similar patterns
