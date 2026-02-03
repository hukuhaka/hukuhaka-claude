---
name: query
description: >
  Answer questions about the project using .claude/ docs and code search.
  Natural language queries about architecture, patterns, and implementation.
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

## Workflow

### 1. Parse Question

Identify question type:

| Type | Keywords | Primary Source |
|------|----------|----------------|
| How | "how", "works", "process" | map.md + code search |
| Where | "where", "located", "find" | map.md + Glob |
| Why | "why", "reason", "decision" | design.md Decisions |
| What | "what is", "explain" | design.md + map.md |

### 2. Search Strategy

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

### 3. Answer Format

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

## Quality Rules

1. **Always cite sources** - link to files or docs
2. **Admit uncertainty** - "Based on docs..." or "Code suggests..."
3. **Stay scoped** - answer the question, don't over-explain
4. **Suggest follow-ups** - related questions user might have

## MCP Tools

- `mcp__code-search__search_code`: Semantic search for concepts
- `mcp__code-search__find_similar_code`: Related implementations

## Examples

**Q: "How does the API handle errors?"**
```markdown
## Answer
Errors are handled through a centralized ErrorHandler middleware that catches exceptions and formats them as JSON responses.

### Details
The middleware in `src/middleware/error.py` wraps all routes...

### References
- [ErrorHandler](src/middleware/error.py:ErrorHandler): Central error handling
- design.md: "Centralized error handling for consistent API responses"
```

**Q: "Why do we use Redis for caching?"**
```markdown
## Answer
Redis was chosen for its pub/sub capability needed for real-time features, per ADR-003.

### References
- design.md Decision: "Redis over Memcached for pub/sub support"
```
