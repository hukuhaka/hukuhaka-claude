---
name: query
description: >
  Use when answering questions about project architecture, patterns, or implementation using .claude/ docs.
---

# Query

Answer project questions using `.claude/` documentation and semantic code search.

## Purpose

- "How does X work in this project?"
- "Where is Y implemented?"
- "Why was Z designed this way?"
- Bridge documentation and code for quick answers

## Usage

```
/project-mapper:query How does authentication work?
/project-mapper:query Where is the database connection handled?
/project-mapper:query Why do we use factory pattern here?
```

---

## Iron Law

**You MUST NOT spawn Task agents.** Handle all analysis directly using Read, Grep, Glob, and Bash tools.

---

## Pre-flight

**BEFORE any other action:**

1. Read `.claude/design.md`, `.claude/map.md`, `.claude/implementation.md`
2. If files are missing, note it but continue with available context

---

## The Process

### Step 1: Parse Question

Identify question type:

| Type | Keywords | Primary Source |
|------|----------|----------------|
| How | "how", "works", "process" | map.md + code search |
| Where | "where", "located", "find" | map.md + Glob |
| Why | "why", "reason", "decision" | design.md Decisions |
| What | "what is", "explain" | design.md + map.md |

### Step 2: Search and Analyze

**For "How" questions:**
1. Search map.md for component/entry point
2. Code search for implementation
3. Trace data flow

**For "Where" questions:**
1. Glob for file patterns
2. Grep for symbol definitions
3. Return file:line references

**For "Why" questions:**
1. Search design.md Decisions
2. Look for comments with "why", "reason", "because"
3. Check commit messages if available

**For "What" questions:**
1. Search all .claude/ docs
2. Summarize relevant sections

### Step 3: Format Answer

```markdown
## Answer

{Direct answer in 2-3 sentences}

### Details

{Supporting information}

### References
- [Component](path/file.py:Symbol): description
- design.md: {relevant decision}

### Related
- {related topics user might want to explore}
```

---

## Common Mistakes

| Mistake | Correction |
|---------|------------|
| Spawning Task agents | Handle ALL analysis directly — no delegation |
| Skipping .claude/ doc loading | ALWAYS read design.md, map.md, implementation.md FIRST |
| Answering without citing sources | ALWAYS link to files or docs |
| Over-explaining beyond the question | Stay scoped — answer the question, suggest follow-ups |

---

## Quality Rules

1. **Always cite sources** — link to files or docs
2. **Admit uncertainty** — "Based on docs..." or "Code suggests..."
3. **Stay scoped** — answer the question, don't over-explain
4. **Suggest follow-ups** — related questions user might have

## MCP Tools

- `mcp__code-search__search_code`: Semantic search for concepts
- `mcp__code-search__find_similar_code`: Related implementations
