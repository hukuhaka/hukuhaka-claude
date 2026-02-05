---
name: codex
description: >
  Collaborative problem-solving with OpenAI Codex. Claude and Codex analyze
  each other's output to produce synthesized, stronger results.
---

# Codex Co-worker

Collaborative problem-solving with OpenAI Codex. Not a pass-through - Claude and Codex analyze each other's output to produce synthesized, stronger results.

## Core Principle

**Iterative Mutual Refinement**: Codex produces output → Claude analyzes → (optional) follow-up to Codex → repeat until satisfactory or max iterations reached.

## Prerequisites

- Codex CLI installed (`npm install -g @openai/codex`)
- OpenAI API key configured

## Commands

| Command | Description |
|---------|-------------|
| `ask [question]` | Get Codex answer, Claude critiques and enhances |
| `plan [task]` | Codex plans → Claude identifies gaps → Synthesized plan |
| `review` | Codex reviews → Claude adds missed issues → Combined review |
| `solve [problem]` | Codex solution → Claude stress-tests → Robust solution |
| `compare [question]` | Both answer independently → Synthesis of approaches |

## Options

**General options:**

| Option | Default | Description |
|--------|---------|-------------|
| `--iterations N` | 1 | Refinement loop count (1-5) |
| `--verbose` | false | Show intermediate analysis steps |
| `--timeout N` | 120 | Codex timeout in seconds |
| `--retries N` | 1 | Retry count on failure |
| `--context` | off | Include .claude/ docs (`--context` or `--context=light` for map+design, `--context=full` for +implementation+code) |
| `--compact` | false | Minimal output (synthesized result only) |
| `--verify <cmd>` | none | Run command after Codex output (e.g., "npm test") |

**Review-specific options (v0.93+):**

| Option | Description |
|--------|-------------|
| `--uncommitted` | Review staged, unstaged, and untracked changes |
| `--base <branch>` | Review changes against a base branch (e.g., main) |
| `--commit <sha>` | Review changes introduced by a specific commit |

**Iteration guide:**
- `1`: Single pass (default) - good for simple questions
- `2`: One refinement - recommended for most tasks
- `3`: Deep dive - complex architecture/debugging
- `4-5`: Use sparingly - risk of token waste and direction drift

## Usage Examples

```
/codex ask "What's the best way to implement caching here?"
/codex ask --context "What's the best caching strategy?"
/codex plan "Add authentication to the API"
/codex plan --context=full --iterations 2 "Add authentication"
/codex plan --iterations 2 "Design microservice communication"
/codex review --uncommitted
/codex review --base main
/codex review --commit abc123
/codex review --base main "Focus on security issues"
/codex solve --verify "npm test" "Fix the memory leak"
/codex solve --iterations 3 "Memory leak in the event handler"
/codex compare "How should we structure the database schema?"
```

## Prompt Templates

### ask
```
Question: {user_input}

Provide a clear, actionable answer with reasoning.
```

### plan
```
Create an implementation plan for: {user_input}

Include:
1. Step-by-step tasks (ordered)
2. Files to create/modify
3. Dependencies and risks
4. Testing approach
```

### solve
```
Analyze and solve: {user_input}

Include:
1. Root cause analysis
2. Solution options (with trade-offs)
3. Recommended approach with rationale
4. Prevention strategies
```

### Context Prefix (when --context used)
```
Project context:
{.claude/map.md contents}
{.claude/design.md contents}
{if full: .claude/implementation.md contents}
{if full: relevant code snippets}

---
{original prompt template}
```

### review
Uses native `codex review` command (v0.93+). Custom instructions can be appended.

## Implementation

<workflow>

### Step 1: Parse Command
Extract command type and arguments from user input.

### Step 2: Execute Codex
Run Codex with the appropriate command:

**For ask/plan/solve/compare:**
```bash
codex exec --json "<prompt>" 2>&1
```

**Capture from first response (for multi-iteration):**
- Parse `thread.started` event from JSONL output → store `thread_id`
- This enables conversation continuity across iterations

**For review (v0.93+ native command):**
```bash
codex review --uncommitted ["<custom_instructions>"]
codex review --base <branch> ["<custom_instructions>"]
codex review --commit <sha> ["<custom_instructions>"]
```

### Step 3: Parse Response

**For ask/plan/solve/compare (using `codex exec --json`):**
Parse JSONL output to extract:
- `thread.started` → `thread_id` (save for resume in multi-iteration)
- `item.completed` with `type: "agent_message"` → response text
- `item.completed` with `type: "command_execution"` → executed commands
- `turn.completed` → `usage` object (accumulate for statistics)

**For review (using native `codex review`):**
Output is plain text (NOT JSONL). Capture stdout directly without JSON parsing.

### Step 4: Claude Analysis (CRITICAL)
**Do NOT just present Codex output. Analyze it:**

**For `ask`:**
- Identify gaps or oversimplifications in Codex's answer
- Add context Codex might have missed
- Correct any inaccuracies
- Enhance with additional considerations

**For `plan`:**
- Check for missing steps or dependencies
- Identify potential blockers Codex overlooked
- Suggest order optimizations
- Add edge cases and error handling considerations

**For `solve`:**
- Stress-test the proposed solution
- Identify scenarios where it might fail
- Suggest additional safeguards
- Validate the root cause analysis

**For `review`:**
- Add issues Codex missed
- Prioritize findings by severity
- Suggest specific fixes
- Check for false positives

### Step 5: Iteration Decision (if --iterations > 1)

**Check if refinement needed:**
1. Are there significant gaps in Codex's response?
2. Did Claude identify critical missing pieces?
3. Would a follow-up question materially improve the result?

**If YES and iterations remaining:**
- Use `codex exec resume --json "{thread_id}" "{follow_up_prompt}"` to maintain conversation context
- Codex will have access to all previous conversation history
- Formulate a focused follow-up prompt based on gaps identified
- Return to Step 4

**Resume command (maintains context):**
```bash
codex exec resume --json "{thread_id}" "{follow_up_prompt}" 2>&1
```

**Follow-up prompt template:**
```
Follow-up questions to address gaps:
{claude_identified_gaps}

Please refine your answer addressing these specific points.
```
Note: With resume, no need to repeat original context - Codex remembers the conversation.

**Exit conditions (stop iterating):**
- Max iterations reached
- Claude analysis shows no significant gaps
- Codex response fully addresses the question
- Circular refinement detected (current response ≈ previous response in key points)

### Step 6: Synthesize Final Output
Combine all iterations into final output:

**Standard output:**
```
## Codex's Response
[Final Codex output summary]

## Claude's Analysis
[Strengths, gaps, corrections]

## Iteration History (if --verbose and iterations > 1)
- Round 1: [key insight]
- Round 2: [refinement]
...

## Synthesized Result
[Combined best-of-both output - the actual deliverable]
```

**Compact output (--compact flag):**
```
## Result
[Synthesized result only - no Codex response or Claude analysis sections]
```

**Usage Statistics (always shown unless --compact):**
```
## Usage Statistics
| Metric | Value |
|--------|-------|
| Input Tokens | {sum of input_tokens from turn.completed events} |
| Cached Tokens | {sum of cached_input_tokens} |
| Output Tokens | {sum of output_tokens} |
| Iterations | {count} |
```

**For `compare` command:**
1. Claude answers first (store in memory, do not output yet)
2. Execute Codex with same question
3. Analyze differences and trade-offs between both answers
4. Produce synthesis that addresses both perspectives

Note: Claude answers first to avoid bias from seeing Codex's response.

### Step 7: Verify (if --verify specified)

1. Run the verify command
2. If fails: Include failure in Claude's analysis
3. If passes: Note verification success in output

Output addition:
```
## Verification
✅ `{command}` passed
```
or
```
## Verification
❌ `{command}` failed
[Error summary]
```

</workflow>

## Error Handling

**Failure types:**
- Timeout: Codex exceeds --timeout
- Exit non-zero: CLI error
- Empty response: No agent_message in output
- Parse error: Invalid JSONL (for exec command)

**Retry policy:**
- Backoff schedule: 1s, 2s, 4s (exponential)
- Max attempts: retries + 1
- Only retry on timeout or transient errors (not auth failures)

**Behavior:**
1. Retry with exponential backoff (if --retries > 0)
2. On final failure: Claude continues with best effort, marks assumptions
3. Show actionable error message + stderr summary

**Verification handling (--verify):**
- Non-zero exit: Include failure details in analysis, mark with ⚠️
- Command not found: Skip verification, warn user, continue
- Timeout: Treat as failure, include in output

**Fallback strategy:**
- If Codex fails, Claude answers independently
- Output clearly marked: "⚠️ Codex unavailable - Claude-only response"

## Collaboration Value

| Scenario | Codex Strength | Claude Strength | Synthesis |
|----------|---------------|-----------------|-----------|
| Planning | Practical steps | Edge cases, risks | Complete plan |
| Debugging | Pattern matching | Logical analysis | Root cause + fix |
| Review | Common issues | Context-aware issues | Thorough review |
| Architecture | Implementation focus | Trade-off analysis | Balanced design |

## Response Format (Quick Reference)

Standard output (see Step 6 for full detail):
```
## Codex's Response
[Brief summary of Codex output]

## Claude's Analysis
**Strengths:** [What Codex got right]
**Gaps:** [What was missed or oversimplified]
**Corrections:** [Any inaccuracies]

## Synthesized Result
[Final combined output - the actual deliverable]
```

With `--compact`: Only "## Result" section (no intermediate analysis).

## Common Usage Patterns

**Quick question:**
```
/codex ask "How should I structure error handling here?"
```

**Code review before commit:**
```
/codex review --uncommitted
```

**Review PR against main:**
```
/codex review --base main
```

**Deep planning with project context:**
```
/codex plan --context=full --iterations 2 "Add user authentication"
```

**Validate solution with tests:**
```
/codex solve --verify "npm test" "Fix the race condition in queue processing"
```

## Notes

- Invoke using `/codex` prefix (e.g., `/codex review --uncommitted`)
- Requires Codex CLI v0.93.0+ for native `review` command
- Codex runs in suggest mode (analysis only, no file modifications)
- Always synthesize - never just pass through Codex output
- For large codebases, specify file paths for better context
- Use `--json` flag for parseable output (exec command)
- Use `--context` to give Codex awareness of project architecture

**Multi-iteration continuity:**
- First call captures `thread_id` from `thread.started` event
- Subsequent iterations use `codex exec resume` with stored `thread_id`
- This allows Codex to remember context from previous iterations
- Single iteration mode uses standard `codex exec` (no resume needed)

**Iteration warnings:**
- Each iteration = ~1 Codex API call + token cost
- After 3 iterations, risk of "circular refinement" (same points repeated)
- Claude compares current vs previous response; if 90%+ similar key points, stop early
- If stuck in loop, Claude should synthesize with available info and note limitations

**Usage statistics:**
- Token usage extracted from `turn.completed` events in JSONL
- Accumulated across all iterations
- Helps users understand API cost per query
- Hidden in `--compact` mode for cleaner output
