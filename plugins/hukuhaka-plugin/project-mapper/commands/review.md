---
name: review
description: "Code review with .claude/ project context"
disable-model-invocation: true
---

# /project-mapper:review

Code review powered by project documentation.

## Usage

```
/project-mapper:review [command] [args]
```

## Commands

| Command | Description |
|---------|-------------|
| `pr [number]` | Review GitHub PR |
| `changes [path]` | Review uncommitted changes |
| `file [path]` | Review specific file |

## Examples

```bash
/project-mapper:review pr 123
/project-mapper:review changes ./src
/project-mapper:review file ./src/api/handler.py
```

## What It Checks

- Pattern compliance (from design.md)
- Naming conventions (from map.md)
- Architecture fit (from design.md Decisions)
- TODO alignment (from implementation.md)

## Output

```markdown
## Review: PR #123

### Summary
Brief overview of changes

### ✓ Good
- Positive observations

### ⚠ Suggestions
- Improvements (not blocking)

### ✗ Issues
- Problems to fix
```
