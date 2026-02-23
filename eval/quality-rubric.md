# Quality Rubric

Scoring rubric for .claude/ documentation quality. Each dimension scored 1-5.

## Dimensions

### Completeness (weight: 0.30)
Coverage of entry points, modules, data flow, and directory structure.
- 5: All entry points, key modules, data flow, and directory structure documented
- 4: Most components covered, minor gaps (e.g., missing one utility module)
- 3: Core modules documented but significant gaps in coverage
- 2: Only top-level entry points documented, missing depth
- 1: Barely any components documented

### Accuracy (weight: 0.25)
Correctness of file paths, symbol references, and descriptions.
- 5: All paths valid, descriptions match actual code behavior
- 4: 1-2 minor inaccuracies (e.g., slightly outdated description)
- 3: Some paths broken or descriptions misleading
- 2: Multiple broken references, several wrong descriptions
- 1: Mostly incorrect or fabricated references

### Depth (weight: 0.20)
Capture of architecture patterns, design decisions, and technical rationale.
- 5: Architecture patterns, key decisions, and rationale clearly captured
- 4: Main patterns documented, some decisions lack rationale
- 3: Surface-level architecture, missing design rationale
- 2: Only lists files/modules without architectural insight
- 1: No meaningful technical depth

### Format (weight: 0.15)
Adherence to format-rules.md conventions (line limits, reference style, sections).
- 5: Perfect adherence to all format rules
- 4: Minor violations (e.g., slightly over line limit)
- 3: Some format issues (missing sections, wrong reference style)
- 2: Significant format violations throughout
- 1: Ignores format rules entirely

### Coherence (weight: 0.10)
Consistency across documents, valid cross-references between map/design/implementation.
- 5: All documents consistent, cross-references valid and meaningful
- 4: Minor inconsistencies between documents
- 3: Some contradictions or orphaned references
- 2: Documents feel disconnected, inconsistent terminology
- 1: No coherence between documents
