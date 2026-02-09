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
/project-mapper:improve --model opus
/project-mapper:improve --single
```

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `--model <m>` | sonnet | Override agent model |
| `--threshold <n>` | 500 | Line count threshold for large files |
| `--single` | false | Use single agent instead of 3-group parallel |

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
- `--model`: Override model (default: sonnet)
- `--threshold`: Line count threshold (default: 500)
- `--single`: Force single-agent mode

If focus area is provided but invalid, show available areas and ask user to pick one.

**Mode selection:**
- If `--single` is set → single agent mode (Step 3A)
- If a specific focus area is given → single agent mode (Step 3A)
- Otherwise (all categories) → 3-group parallel mode (Step 3B)

### Step 2: Context Loading

Read `.claude/map.md` and `.claude/design.md` for project context.

If files don't exist, inform user to run `/project-mapper:map init` first.

### Step 3A: Single Agent Analysis

Used when `--single` or a specific focus area is given.

Launch **exactly ONE** Task call.

**CRITICAL:** The subagent_type MUST be `"project-mapper:analyzer"` (full qualified name). Do NOT use `"analyzer"` alone.

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

Wait for the agent to return before proceeding to Step 4.

### Step 3B: 3-Group Parallel Analysis (Default)

Launch **exactly THREE** Task calls in parallel. Each agent gets a focused prompt with specific analysis strategies.

**CRITICAL:** The subagent_type MUST be `"project-mapper:analyzer"` (full qualified name) for all three.

**Group 1: Redundancy** (dead-code + duplicates)
```
Task(
  subagent_type: "project-mapper:analyzer",
  model: {model},
  prompt: "
    improve:
    Focus: dead-code, duplicates
    Threshold: {threshold}

    Context from map.md:
    {map.md contents}

    Context from design.md:
    {design.md contents}

    ANALYSIS STRATEGY for dead-code + duplicates (analyze together for cross-category insight):

    **Dead Code:**
    1. Use Grep to find all class/function definitions (def, class keywords)
    2. For each exported symbol, Grep for references across the entire project
    3. Check: is it imported elsewhere? Called? Used as a base class?
    4. Module-level check: are there entire files/directories that nothing imports from?
    5. Look for: unused parameters, unreachable branches, commented-out code blocks

    **Duplicates:**
    1. Compare directories that look like copies of each other
    2. Look for repeated code patterns: similar function bodies, copy-pasted logic
    3. Check config/constant definitions repeated across files
    4. Find similar utility functions that could be consolidated

    **Cross-category:** When you find duplicated code, check if the original became dead after the copy was made. When you find dead code, check if it was superseded by a duplicate elsewhere.

    Return JSON with findings.
  "
)
```

**Group 2: Structure** (large-files + refactoring)
```
Task(
  subagent_type: "project-mapper:analyzer",
  model: {model},
  prompt: "
    improve:
    Focus: large-files, refactoring
    Threshold: {threshold}

    Context from map.md:
    {map.md contents}

    Context from design.md:
    {design.md contents}

    ANALYSIS STRATEGY for large-files + refactoring (analyze together):

    **Large Files:**
    1. Check line counts of ALL source files
    2. Report files with {threshold}+ lines. Include exact line count.
    3. CRITICAL: Do NOT report files under {threshold} lines.

    **Refactoring:**
    1. Inside large files AND normal files, look for:
       - Functions/methods longer than 50 lines
       - Classes with too many methods (>10) or parameters (>10 in __init__)
       - Deeply nested code (3+ levels of if/for/try)
    2. Long functions inside large files are especially important

    **Cross-category:** Large files often contain the longest functions. When you find a large file, dig into it to find specific refactoring targets.

    Return JSON with findings.
  "
)
```

**Group 3: Quality** (health)
```
Task(
  subagent_type: "project-mapper:analyzer",
  model: {model},
  prompt: "
    improve:
    Focus: health
    Threshold: {threshold}

    Context from map.md:
    {map.md contents}

    Context from design.md:
    {design.md contents}

    ANALYSIS STRATEGY for health (bugs, security, anti-patterns):

    **Bugs:**
    1. Look for variable name mismatches (defined as X, used as Y)
    2. Check for uninitialized variables in conditional branches
    3. Look for FIXME/TODO/BUG comments - they often mark known issues
    4. Check division operations for zero-division risk

    **Security:**
    1. torch.load() without weights_only=True
    2. eval() or exec() calls on external input
    3. os.system() with string formatting (shell injection)
    4. yaml.full_load() instead of yaml.safe_load()
    5. Unsafe pickle deserialization
    6. Missing input validation

    **Anti-patterns:**
    1. Bare except clauses (swallowing all exceptions)
    2. Mutable default arguments
    3. Magic numbers without named constants
    4. print() instead of logging
    5. sys.path.insert hacks

    Read actual source files to verify each finding. Don't guess.

    Return JSON with findings.
  "
)
```

Wait for **all three** agents to return. Merge their findings into a single list with sequential IDs before proceeding to Step 4.

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
