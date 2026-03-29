# Skill Quality Rubric

Scoring rubric for authored skill/agent quality. Each dimension scored 1-5.

Reference: `docs/plugin-guide/skills.md`, `docs/plugin-guide/skill-design.md`, `docs/plugin-guide/agents-and-hooks.md`

## Dimensions

### Description Quality — CSO (weight: 0.30)
Whether the description follows Claude Search Optimization principles.
- 5: Trigger-condition format ("Use when..."), exclusion pattern ("Do NOT use for..."), <50 words, third person, relevant keywords
- 4: Good trigger format, minor issues (slightly verbose or missing exclusion, 50-100 words)
- 3: Describes what the skill does but not when to use it; or first person
- 2: Workflow summary instead of trigger conditions; missing key context
- 1: No description, or generic/useless description

### Bulletproofing (weight: 0.25)
Whether discipline-enforcing skills resist rationalization and process skipping via verifiable structural patterns and enforcement language.
- 5: Iron law + rationalization table (3+ entries) + red flags + hard gate. Enforcement language present: imperative commands ("You MUST", "NON-NEGOTIABLE"), explicit pre-action announcements ("Announce: I will now..."), sequential gates ("Cannot proceed to X without Y"), or universal framing ("Every project goes through this")
- 4: Full structural bulletproofing (at least 3 of: iron law, rationalization table, red flags, hard gate, explicit negations) with or without enforcement language. Minor gaps (e.g., thin rationalization table)
- 3: Some bulletproofing (e.g., iron law only, or 1-2 structural patterns) but incomplete coverage
- 2: Minimal resistance to skipping (single warning, no structured patterns)
- 1: No bulletproofing in a discipline-enforcing skill

Note: Reference and simple task skills that don't enforce discipline receive baseline score of 3. Only discipline-enforcing skills can score 4-5 or 1-2.

Verifiable enforcement signals (scan for these in skill text):
- Imperative: "You MUST", "NEVER", "NON-NEGOTIABLE", "MANDATORY"
- Commitment: "Announce:", "State:", "I will now"
- Sequential gate: "Cannot proceed", "Do NOT proceed until", "BLOCKED until"
- Universal: "Every project", "Always", "No exceptions"

### Progressive Disclosure (weight: 0.20)
Whether content is organized for token efficiency and appropriate loading.
- 5: Body within budget (<500 lines for standard, <50 lines for frequent, <30 lines for onboarding). Heavy content offloaded to references/ or scripts/ (as appropriate), no duplication, TOC in large references
- 4: Reasonable size within budget, minor duplication or one oversized section
- 3: Body approaching budget limit, some content better suited for references or scripts
- 2: Exceeds budget (>500 lines) or significant duplication
- 1: Everything crammed into SKILL.md with no references, or excessive token waste

Budget tiers (all in lines):
- Onboarding / getting-started: <30 lines body
- Frequently-triggered: <50 lines body
- Standard (default): <500 lines body
- Complex router: body <100 lines, unlimited references

Archetype classification: Infer from description trigger conditions. Skills triggered on recurring high-frequency events (each PR, every commit, any test run) are frequent. Skills loaded on every session start are onboarding. Skills with conditional dispatch to sub-behaviors are routers. If archetype cannot be determined, apply standard (<500 lines) as default.

### Prompt Design (weight: 0.15)
Whether agent prompts follow design principles (single responsibility, output format, model selection).
- 5: Clear role definition, single responsibility, explicit output format, status protocol. Model selection matches task: haiku for validation/checking, sonnet for creation/analysis, opus for architecture. Independent verification mechanism (separate validator, hook-based check) preferred over self-review
- 4: Good structure, minor gaps (e.g., no explicit output format). Model selection reasonable — includes `inherit` as intentional choice for operator-controlled flexibility
- 3: Functional prompt but missing structure (no output format, mixed responsibilities). Model omitted without justification
- 2: Vague role, no output format, multiple responsibilities mixed. Model mismatch (e.g., opus for mechanical validation, haiku for architectural judgment)
- 1: No meaningful prompt design; or N/A for skills without agents (score 3 baseline)

Note: Skills that don't use agents receive baseline score of 3. Only skills with agent definitions can score 4-5 or 1-2.

Model selection strategy (from agents-and-hooks.md):
- Haiku: mechanical, well-specified tasks (link validation, formatting)
- Sonnet: standard implementation, analysis, review
- Opus/inherit: architecture, multi-file reasoning, complex judgment
- `inherit`: valid choice for skills designed to be model-agnostic or operator-controlled

### Structural Correctness (weight: 0.10)
Whether files follow naming conventions, frontmatter is valid, and organization is correct.
- 5: Valid YAML frontmatter, all recommended fields present, proper directory structure (skill-name/SKILL.md), kebab-case naming
- 4: Valid structure, minor issues (e.g., missing optional field)
- 3: Functional but unconventional (e.g., flat file instead of directory)
- 2: Frontmatter issues (missing description, malformed YAML)
- 1: No frontmatter, wrong file format, or broken structure
