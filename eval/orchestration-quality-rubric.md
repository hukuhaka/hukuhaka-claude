# Orchestration Quality Rubric

Scoring rubric for multi-agent orchestration effectiveness. Each dimension scored 1-5.

Evaluates **how well** agents were orchestrated, not whether rules were followed (that's logic eval).

Reference: `docs/plugin-guide/agents-and-hooks.md` (Part 2: Orchestration Patterns)

## Dimensions

### Model Stratification (weight: 0.25)
Whether agent model assignments match task complexity.
- 5: Every agent uses the optimal model — haiku for mechanical tasks (validation, formatting, counting), sonnet for analysis/generation, opus for architecture/multi-file reasoning. Cost-efficiency maximized
- 4: Most assignments correct, one minor suboptimality (e.g., sonnet for a simple validation that haiku could handle)
- 3: Default model used for all agents (no differentiation), or 1 clear mismatch
- 2: Multiple mismatches (e.g., opus for validation, haiku for complex analysis)
- 1: Severely mismatched or no model consideration at all

Note: If only one agent is spawned, evaluate whether that agent's model fits its task. `inherit` counts as intentional if the task has mixed complexity.

### Parallelization Effectiveness (weight: 0.25)
Whether independent tasks were dispatched simultaneously and boundaries respected.
- 5: All independent tasks dispatched in the same message. Each agent has clear file/domain boundaries. No unnecessary sequential dependencies
- 4: Mostly parallel, one missed parallelization opportunity or slightly broad boundaries
- 3: Mixed — some parallel dispatch, some unnecessary sequential ordering
- 2: Mostly sequential despite independent tasks being available
- 1: Entirely sequential when parallel was clearly possible, or agents conflicted on shared files

Signals to check: multiple Agent/Task tool_use blocks in a single assistant message = parallel dispatch. Sequential messages with independent agents = missed opportunity.

### Verification Independence (weight: 0.20)
Whether verification was performed by an independent mechanism, not self-reported by implementers.
- 5: Separate verification agent/step ran after implementation. Verifier used its own tools (Read, Grep, Glob) independently. Verification found or confirmed specific details with evidence
- 4: Verification present but minor gaps (e.g., verifier ran but checked subset of outputs)
- 3: Verification exists but is self-review (same agent checks its own work) or verifier prompt was too narrow
- 2: Minimal verification — agent claimed completion with "should work" language, no independent check
- 1: No verification at all, or verification was a no-op (always passes)

Red flags: "seems correct", "should work", "probably passes" in final output without tool-backed evidence.

### Stage Isolation (weight: 0.15)
Whether pipeline stages maintained clear boundaries (input/output format, scope, permissions).
- 5: Each stage receives structured input (JSON or well-defined format) from previous stage. Read-only stages don't write. Write stages only modify designated files. Output flows cleanly to next stage
- 4: Good isolation, one minor boundary crossing (e.g., read-only stage made a minor edit)
- 3: Stages exist but boundaries are soft — agents accessed files outside their scope or output format was unstructured
- 2: Stages poorly defined — agents overlapped significantly or skipped stages
- 1: No stage boundaries, monolithic execution

Note: For non-pipeline orchestrations (team dispatch, parallel tasks), evaluate whether agents respected their assigned scope/domain.

### Orchestration Clarity (weight: 0.15)
Whether agent dispatch decisions were explicit, prompts were well-scoped, and the overall strategy was sound.
- 5: Agent prompts include specific scope ("Fix tests in src/auth/"), boundary constraints ("Do NOT modify files outside..."), expected output format, and context from prior stages
- 4: Good prompts, minor gaps (e.g., missing boundary constraint or output format)
- 3: Functional prompts but generic (e.g., "fix the tests") without scope or boundaries
- 2: Vague prompts that leave agents guessing about scope and expectations
- 1: No meaningful orchestration — agents spawned without clear purpose

## Applicability

This rubric applies to any transcript with multi-agent orchestration:
- Pipeline workflows (analyzer → writer → validator)
- Team dispatch (parallel independent agents)
- Two-stage review (spec check → quality check)
- Mixed patterns (pipeline + parallel within stages)

For single-agent transcripts, this eval type is not applicable.
