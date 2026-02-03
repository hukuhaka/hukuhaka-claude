# Skills Writing Rules

Rules for creating and maintaining skills in this repository.

## Core Principle

Claude is already smart. Only add context Claude doesn't already have. Challenge each piece: "Does this justify its token cost?"

## Structure

### Frontmatter (Required)

```yaml
---
name: skill-name
description: What it does AND when to trigger it
---
```

- `name`: lowercase, hyphens for spaces
- `description`: Include trigger conditions here, not in body (body loads after trigger)

### Body Guidelines

- Keep under 500 lines
- Split large content into `references/` files
- Use imperative/infinitive form

## Formatting

| Element | Usage |
|---------|-------|
| **Bold** | Only for strong rules: **NEVER**, **IMPORTANT**, **MUST**, **DO NOT** |
| Code blocks | Only for API/CLI command examples |
| Inline code | File paths, command names, function names |

## Prohibited

- Code blocks for document templates or output formats
- Excessive bold for emphasis that isn't a critical rule
- Long tables when lists suffice
- ASCII art or diagrams
- Verbose explanations when concise text works
- Unnecessary files: README.md, CHANGELOG.md, INSTALLATION_GUIDE.md

## Style

- Bullet lists over numbered steps (unless order matters)
- One concept per line
- Active voice
- Check full scope across all skills before style changes

## Example: Good vs Bad

Bad (verbose with unnecessary code block):
```
### Output Format

Present your findings in the following format:

\`\`\`
## Summary
- Finding 1
- Finding 2
\`\`\`
```

Good (concise):
```
### Output Format

Present summary as bullet list with key findings.
```
