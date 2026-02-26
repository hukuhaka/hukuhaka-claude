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
Task(subagent_type: "project-mapper:verifier", prompt: "analyze: Scan the codebase and return structured facts about tech stack, directories, interfaces, components, and config files.")
```

Receive structured facts from agent.

### Phase 3: Round 1 — Rule Selection (AskUserQuestion)

Present detected facts and ask user to classify them as constraints:

- Q1: "Detected tech stack: {list}. Which are hard constraints (must not change)?" (multiSelect)
- Q2: "Detected interfaces: {list}. Which should be IMMUTABLE?" (multiSelect)
- Q3: "Project's core goal?" options: [Web app, CLI tool, Library/SDK, Data pipeline] (single + Other)

### Phase 4: Round 2 — User-Defined Sections (AskUserQuestion)

- Q1: "Naming conventions?" options: [Language standard only, I have rules, Decide later]
- Q2: "Configuration rules? No-hardcode scope?" options: [All paths, Paths + secrets, Decide later]
- Q3: "Definition of done?" options: [Tests pass, Tests + docs, Custom, Decide later]

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

For each drifted section, AskUserQuestion:
- "Section {N} drift: {description}. How to resolve?" options: [Update spec.md, Flag for code fix, Skip]
- If "Update spec.md" → Edit the specific section in `.claude/spec.md`
- If "Flag for code fix" → Append to `.claude/backlog.md` under `## Planned`
