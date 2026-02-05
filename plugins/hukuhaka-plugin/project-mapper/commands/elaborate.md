---
name: elaborate
description: "Elaborate requirements into detailed implementation plans"
disable-model-invocation: true
---

# /project-mapper:elaborate

Convert requirements into detailed, actionable tasks for `.claude/implementation.md`.

## Usage

```
/project-mapper:elaborate [requirement] [options]
```

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `--model` | opus | Override agent model |

## Examples

```bash
# Feature request
/project-mapper:elaborate Add OAuth2 authentication

# Bug fix
/project-mapper:elaborate Fix memory leak in event listener

# Refactoring
/project-mapper:elaborate Refactor test files to use fixtures
```

## Output

Returns structured JSON with:
- Tasks (title, description, acceptance criteria)
- Affected files
- Architecture impact
- Prerequisites

After confirmation, tasks are added to `.claude/implementation.md` Planned section.
