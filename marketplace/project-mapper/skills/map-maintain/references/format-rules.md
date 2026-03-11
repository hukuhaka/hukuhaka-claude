# Compact Format Rules

Rules for the compact operation (changelog + backlog cleanup).

## changelog.md

- `## Recent` — latest 10 entries, format: `- [YYYY-MM-DD] description`
- `## Archive` — consolidated by month, format: `- YYYY-MM: summary`
- Keep recent 10. Consolidate older entries into Archive by month

## backlog.md

- `## Planned` — future work
- `## In Progress` — active items
- `## Discovered TODOs` — auto-scanned from codebase
- Move completed items to changelog. Remove empty sections
- Never delete user content in Planned/In Progress sections
- If any section is missing, create it. Do NOT rename or merge these sections
