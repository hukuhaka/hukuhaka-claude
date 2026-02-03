---
name: elaborate
description: >
  Elaborate requirements into detailed implementation plans.
  Converts user requirements into .claude/implementation.md tasks.
---

# Elaborate

Convert requirements into detailed, actionable tasks for `.claude/implementation.md`.

## Purpose

- Break down high-level requirements into concrete tasks
- Identify affected files and architecture impact
- Generate structured plans ready for implementation

## Usage

```
/project-mapper:elaborate Add email verification to signup
/project-mapper:elaborate Fix memory leak in event listener
/project-mapper:elaborate Refactor test files to use fixtures
```

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `--dry-run` | false | Show JSON only, don't modify implementation.md |
| `--model <m>` | opus | Override agent model |

## Output

1. Display JSON result:
   - Tasks (title, description, acceptance criteria)
   - Affected files
   - Architecture impact
   - Prerequisites

2. After confirmation, add to implementation.md Planned section

<workflow>

### Step 1: Parse Input

Extract requirement from input. Parse options:
- `--dry-run`: Boolean flag
- `--model`: Override model (default: opus)

If no requirement provided, ask user for requirement.

### Step 2: Context Loading

Read `.claude/map.md` and `.claude/design.md` for project context.

If files don't exist, inform user to run `/project-mapper:map init` first.

### Step 3: Elaborate

Launch elaborator agent:

```
Task(
  subagent_type: "project-mapper:elaborator",
  model: {model},
  prompt: "
    Requirement: {requirement}

    Context from map.md:
    {map.md contents}

    Context from design.md:
    {design.md contents}

    Return JSON with tasks, affected files, and architecture impact.
  "
)
```

### Step 4: Display Result

Show the JSON result to user in formatted output:

```markdown
## Elaboration Result

**Requirement:** {requirement}
**Type:** {type}

### Tasks

1. **{task.title}**
   - {task.description}
   - Files: {task.files_affected}
   - Criteria: {task.acceptance_criteria}

### Architecture Impact

- Scope: {scope}
- Decisions affected: {decisions_affected}
- New patterns: {new_patterns}

### Prerequisites

- {prerequisites}
```

### Step 5: Confirm (unless --dry-run)

If `--dry-run` flag is set, exit after displaying result.

Otherwise, ask user:

```
AskUserQuestion: "Add these tasks to implementation.md?"
Options:
- Yes: Proceed to Step 6
- No: Exit without changes
- Edit: Allow user to modify, then re-confirm
```

### Step 6: Merge to implementation.md

1. Read existing `.claude/implementation.md`
2. Parse the `## Planned` section
3. For each new task:
   - Check for duplicate titles (skip if exists)
   - Add to Planned section with format:
     ```
     - **{title}**: {description}
       - Files: {files}
       - Criteria: {criteria}
     ```
4. Write updated implementation.md
5. Confirm: "Added {n} tasks to implementation.md"

</workflow>

## Examples

**Input:**
```
/project-mapper:elaborate Add OAuth2 authentication
```

**Output:**
```json
{
  "requirement": "Add OAuth2 authentication",
  "type": "feature",
  "tasks": [
    {
      "id": 1,
      "title": "Add OAuth2 provider configuration",
      "description": "Create config module for OAuth2 providers (Google, GitHub)",
      "acceptance_criteria": [
        "Config supports multiple providers",
        "Secrets read from environment"
      ],
      "files_affected": ["src/config/oauth.py"]
    },
    {
      "id": 2,
      "title": "Implement OAuth2 callback handler",
      "description": "Handle OAuth2 redirect and token exchange",
      "acceptance_criteria": [
        "Token exchange works for all providers",
        "User session created on success"
      ],
      "files_affected": ["src/auth/oauth.py", "src/routes/auth.py"]
    }
  ],
  "architecture_impact": {
    "decisions_affected": ["Authentication strategy"],
    "new_patterns": ["OAuth2 flow"],
    "scope": "medium"
  },
  "prerequisites": ["Environment variables for OAuth secrets"]
}
```

**After confirmation, added to implementation.md:**
```markdown
## Planned

- **Add OAuth2 provider configuration**: Create config module for OAuth2 providers
  - Files: src/config/oauth.py
  - Criteria: Config supports multiple providers, Secrets read from environment

- **Implement OAuth2 callback handler**: Handle OAuth2 redirect and token exchange
  - Files: src/auth/oauth.py, src/routes/auth.py
  - Criteria: Token exchange works, User session created on success
```
