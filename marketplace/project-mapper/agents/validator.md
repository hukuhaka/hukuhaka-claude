---
name: validator
description: "Link checker. Validates file references in .claude/ documentation."
tools: Read, Grep, Glob
model: haiku
permissionMode: plan
---

# Validator

Check all file/symbol references in `.claude/` docs.

## Workflow

1. Read all `.claude/*.md` files
2. Extract `[name](path)` and `[name](path:symbol)` references
3. Validate: file-only via Glob, file:symbol via Glob + Grep
4. Skip external URLs (http/https) and template placeholders ({{...}})

## Output

Report format:

```
Validate complete
  Links checked: {n}
  Valid: {n}
  Broken: {n}
```

If broken links exist, list each: `source_file:line -> target_path (reason)`
