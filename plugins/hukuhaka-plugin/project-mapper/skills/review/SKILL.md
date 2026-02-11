---
name: review
description: >
  Use when reviewing code changes against project patterns, conventions, and architectural decisions.
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

## Usage

```
/project-mapper:review pr 42
/project-mapper:review changes src/
/project-mapper:review file src/auth.ts
```

---

## Iron Law

**You MUST NOT spawn Task agents.** Handle all analysis directly using Read, Grep, Glob, and Bash tools.

---

## Pre-flight

**BEFORE any other action:**

1. Read `.claude/design.md`, `.claude/map.md`, `.claude/implementation.md`
2. Do NOT skip this step. Do NOT proceed to analyzing changes without reading these files first
3. If any file is missing, note it but continue with available context

---

## The Process

### Step 1: Parse Input

Identify command type and target:
- `pr [number]` → GitHub PR review
- `changes [path]` → Local uncommitted changes
- `file [path]` → Specific file review

### Step 2: Analyze Changes

**For PR:**
**CORRECT:** `gh pr diff {number}` — shows actual code changes
**WRONG:** `gh pr view {number}` — shows metadata, NOT code changes

```bash
gh pr diff {number}
```

**For local changes:**
```bash
git diff [path]
```

**For file:**
```
Read file + Grep for related code
```

### Step 3: Review Against Context

Check each change against `.claude/` documentation:

| Check | Source |
|-------|--------|
| Pattern compliance | design.md Patterns |
| Naming conventions | map.md Components |
| Architecture fit | design.md Decisions |
| TODO alignment | implementation.md Planned |

### Step 4: Format Output

**MUST include all of the following sections:**

```markdown
## Review: {target}

### Summary
{1-2 sentence overview}

### Findings

#### Good
- {positive observations}

#### Suggestions
- {improvements, not blocking}

#### Issues
- {problems that should be fixed}

### Context Used
- Pattern: {referenced pattern from design.md}
- Decision: {relevant decision}
```

---

## Common Mistakes

| Mistake | Correction |
|---------|------------|
| Using `gh pr view` for code changes | Use `gh pr diff {number}` for actual diffs |
| Skipping .claude/ doc loading | ALWAYS read design.md, map.md, implementation.md FIRST |
| Spawning Task agents | Handle ALL analysis directly — no delegation |
| Missing output sections | MUST include: Summary, Good, Suggestions, Issues, Context Used |
| Retrying denied permissions 5+ times | After 2 failures, inform user and ask for alternatives |
| Reviewing without architectural context | Pre-flight docs give patterns and decisions to check against |

---

## Quality Rules

1. **Cite sources** — reference specific design.md patterns or decisions
2. **Be specific** — point to exact lines, not general observations
3. **Prioritize** — issues before suggestions before praise
4. **Stay scoped** — review what was changed, don't critique unrelated code

## MCP Tools

- `mcp__code-search__search_code`: Find related code
- `mcp__code-search__find_similar_code`: Check for similar patterns
