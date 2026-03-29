# Skill Design

> Design principles, testing methodology, and bulletproofing techniques for effective skills.

Companion to [skills.md](skills.md) (format/spec reference). This document covers **how to design skills that work reliably** — not just how to format them.

## Claude Search Optimization (CSO)

Claude decides which skill to invoke based on its `description` field. This is the single most important piece of text in your skill.

### Description Rules

**Description = when to use, NOT what the skill does.**

| Bad | Good |
|-----|------|
| "Runs tests, checks coverage, generates reports" | "Use when running tests or checking code quality" |
| "Brainstorming skill that explores ideas through Socratic dialogue and produces design documents" | "Use before any creative work — creating features, building components, or modifying behavior" |

**Why this matters**: Claude reads descriptions for every loaded skill on every turn. If the description summarizes the workflow, Claude may follow the summary instead of loading and reading the full skill body. The body contains the nuance, the guardrails, the edge cases — the description must drive Claude to load it, nothing more.

### Description Checklist

- Describes **when** to trigger, not **how** it works
- Includes negative boundaries ("Do NOT use for X") when adjacent skills exist
- Covers the user intents that should trigger it (synonyms, related phrases)
- Under ~50 words — metadata budget is shared across all loaded skills

### Example: Router Disambiguation

When multiple skills cover adjacent domains, descriptions must include explicit exclusions:

```yaml
# map-sync
description: >
  Generate .claude/ project documentation via sync pipeline.
  Use when user asks to map or sync .claude/ docs.
  Do NOT use for init/clean/status (map-setup) or validate/compact/summary (map-maintain).
```

## Token Budgets

Skills share a context budget (~2% of context window, ~16K chars). Every loaded description costs tokens on every turn. Skill bodies load only when triggered but still consume context.

### Budget Guidelines

| Skill Category | Target Size | Rationale |
|----------------|-------------|-----------|
| Getting-started / onboarding | <150 words body | Loaded frequently, should be fast |
| Frequently-triggered skills | <200 words body | Loaded often, keep lean |
| Standard skills | <500 lines body | Default target |
| Complex router skills | Unlimited references | Body stays lean, references load on demand |

### Reducing Token Cost

- Move detailed instructions to `references/` files — only loaded when needed
- Use `scripts/` for deterministic logic — executed without loading into context
- Split large skills into focused sub-skills with clear description boundaries
- Use `disable-model-invocation: true` for user-only skills — removes description from context entirely

## Skill Archetypes

Beyond [content patterns](skills.md#content-patterns) (reference, task, router), skills fall into three design archetypes:

| Archetype | Purpose | Structure | Example |
|-----------|---------|-----------|---------|
| **Technique** | Step-by-step process with decision points | Ordered steps, flowcharts, checklists | TDD cycle, deployment pipeline |
| **Pattern** | Way of thinking applied to varying situations | Principles, examples, anti-patterns | Code review evaluation, debugging methodology |
| **Reference** | Domain knowledge applied to current work | Facts, schemas, conventions | API design rules, coding standards |

**Technique** skills need the most bulletproofing — they enforce process, and agents will try to skip steps. **Pattern** skills need clear examples of correct and incorrect application. **Reference** skills are simplest — they provide facts Claude applies naturally.

## Degrees of Freedom

Match instruction specificity to task fragility:

| Level | Style | When |
|-------|-------|------|
| **High freedom** | Guidelines, principles | Creative tasks, well-understood domains |
| **Medium freedom** | Pseudocode, decision trees | Multi-step processes with judgment calls |
| **Low freedom** | Exact scripts, literal commands | Critical paths, irreversible actions, known failure modes |

Rule of thumb: **the more damage a wrong decision causes, the less freedom the skill should allow.**

## Bulletproofing Skills

Agent rationalization is the #1 failure mode for discipline-enforcing skills. Claude will find plausible reasons to skip steps, especially under time pressure or when the step seems unnecessary for the current case.

### Common Rationalization Patterns

| Rationalization | Why It Fails |
|-----------------|-------------|
| "This is too simple to need X" | Simple cases are where unexamined assumptions cause the most waste |
| "I'll do X after" | After never comes — context shifts, urgency increases |
| "I'm following the spirit, not the letter" | Spirit and letter are the same. This rationalization closes no loopholes |
| "The pragmatic approach is to skip X" | Pragmatic = systematic. Skipping process is not pragmatic, it's gambling |
| "Just this once" | Standards erode one exception at a time |

### Counter-Techniques

1. **Hard gates** — explicit checkpoints that cannot be bypassed:
   ```markdown
   <HARD-GATE>
   Do NOT proceed to implementation until design is approved.
   This applies to EVERY project regardless of perceived simplicity.
   </HARD-GATE>
   ```

2. **Rationalization tables** — preemptively close known escape routes:
   ```markdown
   | If you think... | The reality is... |
   |"Tests aren't needed here"|Every change needs verification|
   |"I'll add tests after"|Tests written after code prove nothing|
   ```

3. **Red flags** — observable behaviors that indicate skill violation:
   ```markdown
   ## Red Flags — STOP if you notice:
   - Using words like "should", "probably", "seems to"
   - About to commit without running tests
   - Satisfaction before verification
   ```

4. **Explicit negations** — close loopholes with direct prohibitions:
   ```markdown
   Do NOT:
   - Skip review for "simple" changes
   - Trust agent self-reports without independent verification
   - Proceed with unfixed Critical issues
   ```

### Persuasion Principles

Research-backed techniques for increasing agent compliance (Meincke et al. 2025, Cialdini 2021):

| Principle | Technique | Example |
|-----------|-----------|---------|
| **Authority** | Imperative language, non-negotiable framing | "You MUST", "This is NON-NEGOTIABLE" |
| **Commitment** | Explicit announcements before action | "Announce: I will now write a failing test" |
| **Scarcity** | Sequential dependencies, time-bound requirements | "Cannot proceed to GREEN without verified RED" |
| **Social Proof** | Universal patterns, failure modes | "Every project goes through this process" |
| **Unity** | Collaborative language | "We verify together", "Our shared goal" |

**Principle combinations by skill type:**

| Skill Type | Primary | Supporting |
|------------|---------|------------|
| Process/discipline (TDD, review) | Authority + Commitment | Scarcity |
| Investigation (debugging, analysis) | Commitment + Scarcity | Authority |
| Quality (verification, standards) | Authority + Social Proof | Unity |

## Testing Skills

Skills are documentation — but documentation that must reliably control agent behavior. Testing skills follows TDD methodology applied to the skill itself.

### RED-GREEN-REFACTOR for Skills

#### RED Phase: Baseline Without Skill

Run a pressure scenario WITHOUT the skill installed. Document exact failure behaviors.

```
Pressure scenario: "We're behind schedule. Just implement the feature quickly."
Without skill: Claude skips tests, implements directly, claims done without verification.
Observed failures:
- No tests written
- No design review
- Completion claimed without running test suite
```

#### GREEN Phase: Write Minimal Skill

Write the minimum skill that addresses the specific failures observed in RED. Don't over-engineer — fix what actually broke.

```
After installing skill:
- Claude writes failing test first ✓
- Claude runs test to verify failure ✓
- Claude implements minimal code ✓
- But: skips refactoring step when "code looks clean enough"
```

#### REFACTOR Phase: Close Loopholes

Each time an agent finds a new rationalization to bypass the skill, add an explicit counter:

1. Agent skipped refactoring → add: "Refactoring is MANDATORY even when code appears clean"
2. Agent combined RED+GREEN → add: "RED and GREEN are separate steps. Never combine them"
3. Agent mocked instead of testing real behavior → add anti-pattern: "Never test mock behavior instead of real behavior"

### Pressure Scenarios

Test with escalating pressure to find breaking points:

| Pressure Type | Scenario |
|---------------|----------|
| **Time** | "We're behind schedule, just ship it" |
| **Sunk cost** | "I've already written 200 lines, let's not start over" |
| **Authority** | "The tech lead said to skip tests for this" |
| **Exhaustion** | Long session with many tasks completed |
| **Simplicity** | "This is just a one-line change" |

### Signs of a Bulletproof Skill

- Agent follows process even under time pressure
- Agent pushes back on requests to skip steps
- Agent catches its own violations before proceeding
- No new rationalization patterns emerge across 3+ test runs
- Agent applies skill correctly in novel situations not covered in examples

## Checklists

### Pre-Ship Checklist

- [ ] Description follows CSO rules (when, not how)
- [ ] Body under 500 lines (details in references)
- [ ] Tested with at least 2 pressure scenarios
- [ ] Known rationalizations have explicit counters
- [ ] Hard gates protect critical decision points
- [ ] Token cost measured (`/context` before and after loading)

### Anti-Patterns

- **Skill describes workflow in description** — Claude follows description, ignores body
- **No negative boundaries** — adjacent skills trigger incorrectly
- **Instructions assume good faith** — agent will rationalize skipping steps
- **Testing only happy path** — bulletproofing requires adversarial testing
- **Over-engineering initial version** — write minimal skill first, add counters for observed failures
- **Putting all content in SKILL.md** — split into references for token efficiency
