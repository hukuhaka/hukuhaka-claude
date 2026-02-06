---
name: improve
description: >
  Analyze codebase for improvement opportunities.
  Finds large files, dead code, duplicates, refactoring targets, and code health issues.
---

# Improve

Analyze codebase for improvement opportunities and selectively add findings to `.claude/implementation.md`.

## Purpose

- Identify code quality improvement opportunities across the codebase
- Surface large files, dead code, duplicates, refactoring targets, and anti-patterns
- Let users selectively choose which findings to track as planned work

## Usage

```
/project-mapper:improve
/project-mapper:improve large-files
/project-mapper:improve dead-code --threshold 300
/project-mapper:improve duplicates --model sonnet
```

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `--model <m>` | opus | Override agent model |
| `--threshold <n>` | 500 | Line count threshold for large files |

## Focus Areas

| Area | Description |
|------|-------------|
| `large-files` | Files exceeding line threshold |
| `dead-code` | Exported symbols with no references |
| `duplicates` | Semantically similar code blocks |
| `refactoring` | Long functions, large classes |
| `health` | Anti-patterns from design.md context |

## Output

1. Display numbered findings table by category
2. User selects findings by number, 'all', or 'none'
3. Selected findings merge into implementation.md Planned section

<workflow>

### Step 1: Parse Input

Extract focus area and options from input:
- Focus area: one of `large-files`, `dead-code`, `duplicates`, `refactoring`, `health`, or omit for all
- `--model`: Override model (default: opus)
- `--threshold`: Line count threshold (default: 500)

If focus area is provided but invalid, show available areas and ask user to pick one.

### Step 2: Context Loading

Read `.claude/map.md` and `.claude/design.md` for project context.

If files don't exist, inform user to run `/project-mapper:map init` first.

### Step 3: Analyze

Launch **exactly ONE** Task call. The agent handles all categories internally.

**CRITICAL:** The subagent_type MUST be `"project-mapper:analyzer"` (full qualified name). Do NOT use `"analyzer"` alone. Do NOT split into multiple parallel calls.

```
Task(
  subagent_type: "project-mapper:analyzer",
  model: {model},
  prompt: "
    improve:
    Focus: {focus_area or 'all'}
    Threshold: {threshold}

    Context from map.md:
    {map.md contents}

    Context from design.md:
    {design.md contents}

    Analyze the codebase and return JSON with findings.
  "
)
```

Wait for the single agent to return before proceeding to Step 4.

### Step 4: Display Findings

Show findings as a numbered table grouped by category:

```markdown
## Improvement Findings

**Scanned:** {stats.files_scanned} files | **Categories:** {stats.categories_checked} | **Findings:** {stats.total_findings}

### Large Files

| # | Priority | Title | Evidence |
|---|----------|-------|----------|
| 1 | high | Split src/handlers/api.py | 580 lines (threshold: 500) |
| 2 | medium | Split src/utils/helpers.py | 520 lines (threshold: 500) |

### Dead Code

| # | Priority | Title | Evidence |
|---|----------|-------|----------|
| 3 | medium | Remove unused parse_legacy() | 0 references found |

...
```

If no findings, inform user and STOP.

### Step 5: Select Findings

Ask user which findings to add:

```
AskUserQuestion: "Which findings to add to implementation.md? (enter numbers, 'all', or 'none')"
Options:
- All: Add all findings
- None: Skip, don't add anything
- (User can type specific numbers like "1,3,5" or "1-3,5")
```

If 'none', STOP.

### Step 6: Merge to implementation.md

1. Read existing `.claude/implementation.md`
2. Parse the `## Planned` section
3. For each selected finding:
   - Check for duplicate titles (skip if exists)
   - Add to Planned section with format:
     ```
     - **{category_prefix}: {title}**: {suggestion}
       - Files: {files_affected}
       - Evidence: {evidence}
     ```
   - Category prefixes: `Large file`, `Dead code`, `Duplicate code`, `Refactoring`, `Code health`
4. Write updated implementation.md
5. Confirm: "Added {n} findings to implementation.md"

### Step 7: STOP

**This skill ends here. Do NOT start implementing any findings.**

Wait for user's next instruction.

</workflow>

## Examples

**Input:**
```
/project-mapper:improve large-files --threshold 400
```

**Agent Output:**
```json
{
  "stats": {
    "files_scanned": 42,
    "categories_checked": ["large-files"],
    "total_findings": 3
  },
  "findings": [
    {
      "id": 1,
      "category": "large-files",
      "title": "Split src/handlers/api.py",
      "files_affected": ["src/handlers/api.py"],
      "evidence": "580 lines (threshold: 400)",
      "suggestion": "Split into route handlers and middleware",
      "priority": "high"
    },
    {
      "id": 2,
      "category": "large-files",
      "title": "Split src/utils/helpers.py",
      "files_affected": ["src/utils/helpers.py"],
      "evidence": "520 lines (threshold: 400)",
      "suggestion": "Group helpers by domain (string, file, network)",
      "priority": "medium"
    },
    {
      "id": 3,
      "category": "large-files",
      "title": "Split tests/test_integration.py",
      "files_affected": ["tests/test_integration.py"],
      "evidence": "450 lines (threshold: 400)",
      "suggestion": "Split by feature area into separate test files",
      "priority": "low"
    }
  ]
}
```

**User selects:** "1,2"

**Added to implementation.md:**
```markdown
## Planned

- **Large file: Split src/handlers/api.py**: Split into route handlers and middleware
  - Files: src/handlers/api.py
  - Evidence: 580 lines (threshold: 400)

- **Large file: Split src/utils/helpers.py**: Group helpers by domain (string, file, network)
  - Files: src/utils/helpers.py
  - Evidence: 520 lines (threshold: 400)
```
