---
name: map-spec
description: >
  Generate and verify .claude/spec.md — prescriptive project conventions.
  Use when user asks to create spec.md or verify it against codebase.
  Do NOT use for sync (map-sync), init (map-setup), or validate/compact (map-maintain).
---

# Map Spec

Generate and verify `.claude/spec.md` as a prescriptive document. spec.md defines constraints and contracts — what code MUST follow — not what code currently does.

## Rules

- generate: spawns verifier agent in analyze mode, then uses AskUserQuestion to build prescriptive rules
- verify: spawns verifier agent in verify mode, then offers drift resolution via AskUserQuestion

## generate

Create `.claude/spec.md` via prescriptive question-based flow. Follow [spec-guide.md](references/spec-guide.md).

### Phase 1: Pre-flight

1. Check `.claude/` exists. If not → "Run `/project-mapper:map-init` first" and STOP
2. If `.claude/spec.md` exists → AskUserQuestion "spec.md already exists. Overwrite or keep?"
   - Keep → STOP with message "Keeping existing spec.md"

### Phase 2: Analyze codebase

Spawn verifier agent in analyze mode:

```
Task(subagent_type: "project-mapper:verifier", prompt: "analyze: Scan the codebase at {cwd} and return structured facts about tech stack, directories, interfaces, components, and config files.")
```

Wait for verifier to return structured facts JSON. Do NOT proceed until you have the JSON.

Expected output: `{tech_stack, directories, interfaces, components, config_files}` — see verifier.md analyze mode for full schema.

### Phase 3: Round 1 — Rule Selection (AskUserQuestion)

Present detected facts and ask user to classify them as constraints:

- Q1: "Detected tech stack: {list}. Which are hard constraints (must not change)?" (multiSelect) (→ Section 2)
- Q2: "Detected interfaces: {list}. Which should be IMMUTABLE?" (multiSelect) (→ Section 4)
- Q3: "Project's core goal?" options: [Web app, CLI tool, Library/SDK, Data pipeline] (single + Other) (→ Section 1)

### Phase 4: Round 2 — User-Defined Sections (AskUserQuestion)

- Q1: "Naming conventions?" options: [Language standard only, I have rules, Decide later] (→ Section 6)
- Q2: "Configuration rules? No-hardcode scope?" options: [All paths, Paths + secrets, Decide later] (→ Section 7)
- Q3: "Definition of done?" options: [Tests pass, Tests + docs, Custom, Decide later] (→ Section 9)

If Q1 = "I have rules": additional AskUserQuestion to capture naming rules. Q: "Describe your naming conventions:" options: [snake_case everywhere, camelCase for JS / snake_case for Python, PascalCase for classes / camelCase for functions, Other]

### Phase 5: Write

Write `.claude/spec.md` using prescriptive framing. Follow [spec-guide.md](references/spec-guide.md) output format.

- Detected facts → `Rule:` / `> IMMUTABLE` form
- User-selected constraints → hard rules
- "Decide later" items → `(To be defined)` placeholder
- Header: `# Project Spec` + `> Prescriptive — do not modify without explicit approval`
- Line limit: 150 lines max

Report: "spec.md generated with {N} rules defined, {M} sections pending."

## verify

Verify `.claude/spec.md` against actual codebase. Detects drift between documented conventions and code reality.

### Phase 1: Pre-flight

Read `.claude/spec.md`. If missing → "Run `/project-mapper:map-spec generate` first" and STOP.

### Phase 2: Agent Verification

Spawn verifier agent in verify mode:

```
Task(subagent_type: "project-mapper:verifier", prompt: "Verify spec.md content against the actual codebase. Read .claude/spec.md, run analysis protocol, compare results, and report drift.")
```

### Phase 3: Display Results

Show verifier report: sections checked, accurate, drifted, skipped counts. List drift details if any.

### Phase 4: Drift Resolution (only if drift found)

Combine all drifts into a summary, then AskUserQuestion:
- "Found {N} drifted sections: {summary list}. How to resolve?" options: [Update spec.md for all, Review one-by-one, Skip all]
- If "Update spec.md for all" → Edit each drifted section in `.claude/spec.md`
- If "Review one-by-one" → For each drift, AskUserQuestion: "Section {N}: {description}. Resolve?" options: [Update spec.md, Flag for code fix, Skip]. Max 4 questions per call; if more than 4 drifts, split into 2 calls.
- If "Skip all" → Report drifts and take no action
- "Flag for code fix" (from one-by-one) → Append to `.claude/backlog.md` under `## Planned`
