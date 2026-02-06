---
name: improve
description: "Analyze codebase for improvement opportunities"
disable-model-invocation: true
---

# /project-mapper:improve

Analyze codebase for improvement opportunities and add selected findings to `.claude/implementation.md`.

## Usage

```
/project-mapper:improve [focus-area] [options]
```

## Focus Areas

| Area | Description |
|------|-------------|
| `large-files` | Files exceeding line threshold |
| `dead-code` | Exported symbols with no references |
| `duplicates` | Semantically similar code blocks |
| `refactoring` | Long functions, large classes |
| `health` | Anti-patterns from design.md context |

Omit focus area to run all categories.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `--model` | opus | Override agent model |
| `--threshold` | 500 | Line count threshold for large files |

## Examples

```bash
# Full analysis
/project-mapper:improve

# Specific focus
/project-mapper:improve large-files
/project-mapper:improve dead-code --threshold 300

# Custom model
/project-mapper:improve duplicates --model sonnet
```

## Output

Returns structured JSON with findings by category. After selective confirmation, chosen findings are added to `.claude/implementation.md` Planned section.
