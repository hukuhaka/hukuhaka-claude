# spec.md Generation Guide

Reference for map-spec's generate command. Builds `.claude/spec.md` as a **prescriptive** document — rules the codebase must follow, not a description of what exists.

## Key Principle

spec.md is NOT a mirror of current code. It is a constraint document. Facts detected from code become rules only when the user explicitly promotes them.

- Detected: "Project uses Python 3.11" → Prescriptive: `Rule: Python 3.11+ required`
- Detected: "DepthAnythingV2.forward(x)" → Prescriptive: `> IMMUTABLE — DepthAnythingV2.forward(x: Tensor) → Tensor`
- Detected: "config in YAML files" → Prescriptive: `Rule: All configuration via YAML — no hardcoded paths`

## Section Map

| # | Section | Source | Framing |
|---|---------|--------|---------|
| 1 | Overview & Goals | User input (Round 1 Q3) | Goal statement + non-negotiable design goals |
| 2 | Architecture Decisions | Analyze facts + User selection (Round 1 Q1) | `Rule:` blocks for hard constraints |
| 3 | Directory Structure | Analyze facts | Responsibility annotations + forbidden-content rules |
| 4 | Interface Contracts | Analyze facts + User selection (Round 1 Q2) | `> IMMUTABLE` for selected interfaces |
| 5 | Component Contracts | Analyze facts | Ownership boundaries + `> Rule:` per component |
| 6 | Naming Contracts | User input (Round 2 Q1) | Naming rules or `(To be defined)` |
| 7 | Configuration Rules | Analyze facts + User input (Round 2 Q2) | `Rule:` blocks for config constraints |
| 8 | Contract Tests | Derived from 4+5 | Test expectations or `(To be defined)` |
| 9 | Definition of Done | User input (Round 2 Q3) | Checklist or `(To be defined)` |

## Analyze Mode Output

The verifier agent in analyze mode returns structured facts:

```
{
  "tech_stack": ["Python 3", "PyTorch", ...],
  "directories": ["src/", "tests/", ...],
  "interfaces": [{"name": "ClassName", "file": "path.py", "signature": "method(args)"}],
  "components": [{"name": "module.py", "description": "purpose"}],
  "config_files": ["config.yaml", ...]
}
```

## Prescriptive Transformation

When writing spec.md, transform facts into rules:

### Architecture (Section 2)
- Each hard constraint → `### Why {decision}?` + rationale + `> Rule: {constraint}`
- Non-selected items → omit (they are not constraints)

### Interfaces (Section 4)
- IMMUTABLE selections → `> IMMUTABLE` blockquote with signature
- Non-selected interfaces → listed but not locked

### Directory Structure (Section 3)
- Detected dirs → annotated with responsibility descriptions
- Each dir gets a forbidden-content rule if pattern detected (e.g., "no business logic in utils/")
- If no obvious constraints, describe responsibility only — do not fabricate rules

### Component Contracts (Section 5)
- Detected components → ownership boundary + key method constraints
- Format: component name, path, methods with constraints
- `> Rule:` blockquote for key invariant per component

### Configuration (Section 7)
- Detected config pattern → `Rule:` with scope from user selection

## Output Format

Header: `# Project Spec` + `> Prescriptive — do not modify without explicit approval`

Sections: `## N. Section Title` — prose with Rule/IMMUTABLE markers.

Undefined sections: `(To be defined)` on one line. Keep the section heading.

Line limit: 150 lines max.

## Contract Tests (Section 8)

Derive from Sections 4 and 5:
- Section 4 IMMUTABLE interfaces → structural test expectation (subclass check) + signature test expectation (params list)
- Section 5 components with constraints → behavior test expectation per constraint
- Both Sections 4 and 5 `(To be defined)` → Section 8 = `(To be defined)`
- Do NOT generate actual test code. List test expectations as bullet points.

## Thin Project Rule

If fewer than 5 source files detected: Sections 4, 5, 8 default to `(To be defined)`. Still run all AskUserQuestion rounds — user may have conventions planned.
