---
name: query
description: "Ask questions about the project"
disable-model-invocation: true
---

# /project-mapper:query

Answer project questions using documentation and code search.

## Usage

```
/project-mapper:query [question]
```

## Examples

```bash
/project-mapper:query How does authentication work?
/project-mapper:query Where is the database connection handled?
/project-mapper:query Why do we use factory pattern?
/project-mapper:query What is the data flow for API requests?
```

## Question Types

| Type | Keywords | Source |
|------|----------|--------|
| How | "how", "works" | map.md + code |
| Where | "where", "find" | map.md + Glob |
| Why | "why", "reason" | design.md Decisions |
| What | "what is" | design.md + map.md |

## Output

```markdown
## Answer

Direct answer in 2-3 sentences

### Details
Supporting information

### References
- [Component](path/file.py): description
- design.md: relevant decision

### Related
- Related topics to explore
```
