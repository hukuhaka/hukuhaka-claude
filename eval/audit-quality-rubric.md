# Audit Quality Rubric

Scoring rubric for audit findings quality. Each dimension scored 1-5.

## Dimensions

### Evidence Quality (weight: 0.30)
Whether findings are backed by concrete Grep/Read results with specific line numbers and counts.
- 5: Every finding cites specific line numbers, match counts, or code snippets from tool results
- 4: Most findings cite concrete evidence, 1-2 rely on file-level observations only
- 3: Mix of concrete evidence and vague references (e.g., "appears to be duplicated")
- 2: Most findings lack tool-verified evidence, rely on file names or assumptions
- 1: No evidence from actual tool calls; findings are speculative

### Suggestion Actionability (weight: 0.25)
Whether suggestions include target file names, specific refactoring techniques, and extraction points.
- 5: Every suggestion names target files, technique (extract, merge, split, remove), and what to move where
- 4: Most suggestions are concrete; 1-2 are vague ("should be refactored")
- 3: Some suggestions actionable, others lack file names or specific techniques
- 2: Suggestions are mostly generic advice without concrete targets
- 1: No actionable suggestions; only observations

### Confidence Calibration (weight: 0.20)
Whether confidence levels (high/medium/low) match the actual strength of evidence.
- 5: Confidence levels precisely match evidence strength per analysis-guide criteria
- 4: Minor miscalibration on 1-2 findings (e.g., medium when evidence supports high)
- 3: Several findings over- or under-confident relative to evidence
- 2: Confidence levels seem arbitrary, disconnected from evidence
- 1: No confidence levels or all set to same value regardless of evidence

### Coverage Prioritization (weight: 0.15)
Category breadth and correct priority ordering (bugs > duplicates > style).
- 5: Multiple categories covered, bugs/correctness issues ranked highest, clear priority tiers
- 4: Good category coverage, priority mostly correct with minor ordering issues
- 3: Some categories covered, priority ordering has notable errors
- 2: Narrow category focus (1-2 only), priority ordering unclear
- 1: Single category or no meaningful prioritization

### Presentation Fidelity (weight: 0.10)
Consistency between analyzer JSON, formatted output, and backlog entries.
- 5: All three artifacts are consistent — same findings, same details, proper formatting
- 4: Minor discrepancies (e.g., truncated descriptions in backlog)
- 3: Some findings differ between artifacts or formatting inconsistent
- 2: Significant mismatches between artifacts
- 1: Artifacts are disconnected or missing
