# Audit Analysis Guide

Category-specific analysis methodology. The analyzer agent references this via `skills: [project-mapper:audit]`.

## Step-by-Step per Category

### dead-code

1. `Grep(pattern: "export|module\\.exports", path: "<file>")` — identify exported symbols
2. For each exported symbol: `Grep(pattern: "<symbol>", path: ".")` excluding the defining file. Zero matches = candidate
3. `Grep(pattern: "import\\(|require\\(.*\\$|getattr|\\[.*\\]", path: "<file>")` — check dynamic usage patterns. If found, downgrade confidence

Confidence: `high` = 0 references + no dynamic patterns, `medium` = 0 static but dynamic usage possible, `low` = heuristic only

Evidence: `symbol: N references found, dynamic: yes/no`
Suggestion: "Remove `symbol` from `file` (0 references)" or "Verify `symbol` — possible dynamic usage via `pattern`"

### duplicates

1. `Grep(pattern: "<distinctive_signature>", output_mode: "files_with_matches")` — find files sharing similar patterns
2. `Read(file_path: "<candidate_a>")` + `Read(file_path: "<candidate_b>")` — compare actual code blocks, count duplicate lines
3. Identify shared module location based on project directory structure

Confidence: `high` = 10+ identical lines, `medium` = 5-10 lines or similar not identical, `low` = structural similarity only

Evidence: `N duplicate lines between file_a:lines and file_b:lines`
Suggestion: "Extract to `path/shared.ext` — N lines deduped"

### large-files

1. `Read(file_path: "<file>")` — understand internal organization (sections, classes, functions)
2. Identify distinct responsibilities (e.g., parsing vs rendering vs IO)
3. Propose concrete split points with suggested file names

Confidence: `high` = clear responsibility boundaries with minimal coupling, `medium` = identifiable sections but shared state, `low` = tightly coupled

Evidence: `file: N lines, M distinct responsibilities identified`
Suggestion: "Split into `file_a` (responsibility_1, ~N lines) and `file_b` (responsibility_2, ~N lines)"

### refactoring

Detect via `Read` then measure:

- **Deep nesting** (>3 levels): `Read` function body, count indent levels. Suggest early return or extract function
- **Long parameter lists** (>4 params): `Grep(pattern: "def |function ", path: "<file>")`, count params. Suggest parameter object
- **God class** (>8 public methods): `Grep(pattern: "def |public ", path: "<file>")`, count methods. Suggest SRP split
- **Mixed abstraction**: `Read` function, identify high-level orchestration mixed with low-level details

Confidence: `high` = measurable metric violation, `medium` = subjective but strong signal, `low` = style preference

Evidence: `function: N levels deep` or `class: N public methods` or `function: N params`
Suggestion: specific refactoring technique with target structure

### health

- `Grep(pattern: "http://|https://|\\d{4,}", path: ".")` — hardcoded config (magic numbers, URLs in source)
- `Grep(pattern: "except:|catch\\s*\\(", path: ".")` then `Read` — bare except/catch without logging
- `Read(file_path: ".claude/design.md")` — check if patterns in design.md are followed
- `Grep(pattern: "^import |^from ", path: "<file>")` — unused imports, circular risk

Confidence: `high` = definitive anti-pattern, `medium` = context-dependent, `low` = minor style issue

Evidence: `file:line — pattern description`
Suggestion: specific fix with rationale

## General Rules

- Every finding MUST have at least 1 Grep or Read verification. File name/size alone is NOT evidence
- Maximum 15 findings total (across all categories)
- Sort by confidence (high first), then priority
- Effort: `small` = <30 min single file, `medium` = 1-3 files, `large` = cross-cutting
