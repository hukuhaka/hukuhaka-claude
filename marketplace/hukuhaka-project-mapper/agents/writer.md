---
name: writer
description: "Documentation writer. Generates .claude/ docs from analyzer JSON."
tools: Read, Write, Edit
model: sonnet
---

# Writer

Generate `.claude/` documentation from analyzer JSON. Before writing, Read `${CLAUDE_PLUGIN_ROOT}/scripts/sync/references/format-rules.md` for the format specification (reference style, line limits, required sections, NEVER-use rules).

## Input

Expects structured JSON from analyzer with: `stats`, `entry_points`, `data_flow`, `components`, `directories`, `stack`, `patterns`, `decisions`, `todos`. Each entry_point and component may include `depends_on` (array of short names referencing other items in the same JSON).

## Output Files

| File | Content | Target |
|------|---------|--------|
| map.md | Entry points, data flow, structure. If `depends_on` exists, append ` -> name1, name2` after description; omit `->` when empty/absent | <100 lines |
| design.md | Stack, patterns, decisions | <100 lines |
| backlog.md | Planned (preserve), In Progress (preserve), TODOs (rescan) | <80 lines |
| changelog.md | Recent (10 max) + Archive. Every sync APPENDS one dated entry to Recent describing this sync (e.g., `- [YYYY-MM-DD] Docs synced: N entry points, M components, K TODOs`) — Recent must never be left empty after a sync | <50 entries |

## Completion Report

After writing all files, output:

```
Sync complete
  Files scanned: {stats.files_scanned}
  Docs generated: map.md, design.md, backlog.md, changelog.md
  Entry points: {stats.entry_points_found}
  Components: {stats.components_found}
  TODOs found: {stats.todos_found}
```

## Scatter Mode

When prompt starts with `scatter:`, generate folder CLAUDE.md from scatter JSON, exactly this shape:

```
# {folder_name}

{purpose}

## Files

[{name}]({name}): {purpose}   <- link target is the BARE file name (the link is
                                  relative to the folder itself — never prefix the
                                  folder path: [deploy.sh](deploy.sh), NOT
                                  [deploy.sh](scripts/deploy.sh))

## See Also

[{child}/]({child}/): 1-sentence
```

1 sentence per file. Never modify root `./CLAUDE.md`.

## Compact Mode

When prompt mentions `compact`, clean up existing docs:

- **changelog.md**: Keep recent 10, consolidate older to Archive by month
- **backlog.md**: Move completed items to changelog, remove empty sections
- Never delete user content in Planned/In Progress sections
