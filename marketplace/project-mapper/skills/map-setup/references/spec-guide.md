# spec.md Generation Guide

Reference for init's Phase 2: generating `.claude/spec.md`. Based on SPEC_TEMPLATE.md's 9-section convention framework.

spec.md is **prescriptive** — code must follow it, not the other way around.

## Section Map

| # | Section | Case 2 Auto-detect | User Input |
|---|---------|:-:|:-:|
| 1 | Overview & Goals | No | Always |
| 2 | Architecture Decisions | Partial (manifest) | Always |
| 3 | Directory Structure | Yes (Glob) | Confirm |
| 4 | Interface Contracts | Yes (Grep signatures) | Confirm + mark immutable |
| 5 | Component Contracts | Yes (Grep classes) | Confirm |
| 6 | Naming Contracts | Partial | Always |
| 7 | Configuration Rules | Yes (config files) | Confirm |
| 8 | Contract Tests | Derived from 4+5 | No |
| 9 | Definition of Done | No | Always |

## Interview Protocol (Case 1 — New Project)

3 AskUserQuestion rounds. Maximum 4 rounds total (Round 2 follow-up if "있음" selected).

### Round 1: Project Identity (Section 1, 2)

- Q1: "What problem does this project solve?" options: [Web app, CLI tool, Library/SDK, Data pipeline]
- Q2: "Core design goals?" options: [Modularity, Performance, Simplicity, Reproducibility] (multiSelect)
- Q3: "Primary language/framework?" options: [Python, TypeScript/JS, Go, Other]

### Round 2: Structure and Contracts (Section 3, 4, 6)

- Q1: "Do you have core abstractions?" options: [Yes — I'll describe them, Not yet, Auto-suggest after first sync]
- Q2: "Naming conventions?" options: [Yes — I have rules, Language standard only, Not yet]
- Q3: "Primary component type?" options: [API/Server, CLI, Library, Pipeline]

If Q1 = "Yes": one follow-up round to capture abstraction names and key signatures.

### Round 3: Operations (Section 7, 9)

- Q1: "Configuration management?" options: [Config files, Env vars, CLI flags, Undecided]
- Q2: "Definition of done?" options: [Tests pass, Tests + docs, Tests + docs + review, Custom]

After all rounds, generate spec.md from collected answers. Sections without input: write `(To be defined)`.

## Analysis Protocol (Case 2 — Existing Project)

Auto-analysis first (max 8 tool calls), then 1 confirmation AskUserQuestion round.

### Auto-analysis Steps

1. `Glob("*/", head_limit: 15)` — directory structure (Section 3)
2. `Glob("**/*.{py,ts,js,go,rs,java}", head_limit: 20)` — language detection
3. `Grep("class.*ABC|abstract class|interface |protocol |trait ")` — interfaces (Section 4)
4. `Grep("class |module |export default")` — components (Section 5)
5. `Glob("**/*.{yaml,yml,toml,json,ini,env}")` — config files (Section 7)
6. `Read` manifest (package.json / pyproject.toml / go.mod) — tech stack (Section 2)
7-8. `Read` top interface files from step 3 — signature extraction (Section 4)

### Confirmation Round (1 AskUserQuestion)

- Q1: "What is the project's core goal?" (cannot be inferred from code)
- Q2: "Are these detected interfaces correct? Which should be immutable?" (present detection results)
- Q3: "Additional naming conventions?" options: [Language standard only, Yes — I have rules]

### Thin Project (fewer than 5 source files)

Section 4, 5, 6: write `(To be defined)` — fill in as project grows. Still ask Round confirmation questions.

## Output Format

Header: `# Project Spec` + `> Prescriptive — do not modify without explicit approval`

Sections: `## N. Section Title` — Claude writes prose, no placeholders or template variables.

Immutable marker: confirmed items in Section 4 get `> IMMUTABLE` blockquote.

Undefined sections: `(To be defined)` on one line. Keep the section heading.

Line limit: 150 lines max.
