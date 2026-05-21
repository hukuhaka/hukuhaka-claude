---
name: codex-coworker
description: >
  Collaborative problem-solving with OpenAI Codex. Claude and Codex analyze each other's output to produce synthesized, stronger results.
---

# Codex Co-worker

**Mutual Refinement**: Codex produces output → Claude analyzes → Synthesized result combining both perspectives.

## Prerequisites

- Codex CLI installed (`npm install -g @openai/codex`)
- OpenAI API key configured

## Commands

| Command | Description |
|---------|-------------|
| `ask [question]` | Get Codex answer, Claude critiques and enhances. Covers questions, planning, problem-solving, and general tasks |
| `review` | Codex reviews → Claude adds missed issues → Combined review |
| `compare [question]` | Both answer independently → Synthesis of approaches |

## Options

**General options:**

| Option | Default | Description |
|--------|---------|-------------|
| `--context` | off | Include .claude/ docs (`--context` or `--context=light` for map+design, `--context=full` for +implementation+code) |
| `--compact` | false | Minimal output (synthesized result only) |
| `--verify <cmd>` | none | Run command after Codex output (e.g., "npm test") |

**Review-specific options (v0.93+):**

| Option | Description |
|--------|-------------|
| `--uncommitted` | Review staged, unstaged, and untracked changes |
| `--base <branch>` | Review changes against a base branch (e.g., main) |
| `--commit <sha>` | Review changes introduced by a specific commit |

## Usage Examples

```
/codex-coworker ask "What's the best way to implement caching here?"
/codex-coworker ask --context "What's the best caching strategy?"
/codex-coworker ask --context "Add user authentication"
/codex-coworker ask --context=full "Design microservice communication"
/codex-coworker ask --verify "npm test" "Fix the memory leak"
/codex-coworker ask --compact "What's the project structure?"
/codex-coworker review --uncommitted
/codex-coworker review --base main
/codex-coworker review --commit abc123
/codex-coworker review --base main "Focus on security issues"
/codex-coworker compare "How should we structure the database schema?"
```

## Prompt Templates

Prompts sent to Codex are assembled in this order, all inside the same heredoc:

1. **Persona** (always)
2. **Per-command framing** (always, varies by command)
3. **Context Prefix** (only when `--context` used)
4. **User question** (verbatim)

### Persona (always prepended for `ask` / `compare`)
```
You are providing a second opinion to Claude Code, which is working in
this repo and has the full conversation context. You do not. Focus on
what a fresh reader catches: risks, alternative approaches, missed
edge cases. Claude will synthesize your response with its own — so be
direct, take a position, and skip restating things Claude likely
already knows. You are read-only; do not edit files.
```

Not injected on the `review` path — `codex review` is a native subcommand with its own internal system prompt. The user-provided `custom_instructions` arg remains the user's surface and is passed through unchanged.

### Per-command framing (prepended after Persona)

| Command | Framing line |
|---|---|
| `ask` | `Answer the question below. Give your strongest single answer; surface tradeoffs only when they materially change the choice.` |
| `compare` | `Answer independently. Claude is forming a parallel answer; do not hedge to be safe — your distinct angle is the value.` |
| `review` | n/a (handled by `codex review` native subcommand) |

### Context Prefix (when --context used)
```
Project context:
{.claude/map.md contents}
{.claude/design.md contents}
{if full: .claude/backlog.md contents}
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

### Security Considerations

**Prompt injection prevention:**
- Always pass prompts via heredoc (`<<'CODEX_PROMPT'`) to prevent shell expansion
- Never interpolate user input directly into shell command strings
- Treat `--context` file contents (.claude/) as untrusted input — pass via heredoc, not interpolation

### Step 2: Execute Codex
Run Codex with the appropriate command:

**For ask/compare:**
```bash
codex exec --json "$(cat <<'CODEX_PROMPT'
{Persona block}

{Per-command framing line}

{Context Prefix block — only if --context was used}

{user question, verbatim}
CODEX_PROMPT
)" 2>&1
```

The Persona and Per-command framing come from the templates above and are always prepended on this path. The Context Prefix is opt-in via `--context`.

**For review (v0.93+ native command):**
```bash
codex review --uncommitted ["<custom_instructions>"]
codex review --base <branch> ["<custom_instructions>"]
codex review --commit <sha> ["<custom_instructions>"]
```

### Step 3: Parse Response

**For ask/compare (using `codex exec --json`):**
Parse JSONL output to extract:
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
- If planning task: check for missing steps, dependencies, blockers, edge cases
- If problem-solving task: stress-test the solution, validate root cause analysis

**For `review`:**
- Add issues Codex missed
- Prioritize findings by severity
- Suggest specific fixes
- Check for false positives

### Step 5: Synthesize Final Output
Combine into final output:

**Standard output:**
```
## Codex's Response
[Final Codex output summary]

## Claude's Analysis
[Strengths, gaps, corrections]

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
```

**For `compare` command:**
1. Claude answers first (store in memory, do not output yet)
2. Execute Codex with same question
3. Analyze differences and trade-offs between both answers
4. Produce synthesis that addresses both perspectives

Note: Claude answers first to avoid bias from seeing Codex's response.

### Step 6: Verify (if --verify specified)

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
- Exit non-zero: CLI error
- Empty response: No agent_message in output
- Parse error: Invalid JSONL (for exec command)

**Behavior:**
1. On failure: Claude continues with best effort, marks assumptions
2. Show actionable error message + stderr summary

**Verification handling (--verify):**
- Non-zero exit: Include failure details in analysis, mark with ⚠️
- Command not found: Skip verification, warn user, continue
- Timeout: Treat as failure, include in output

**Fallback strategy:**
- If Codex fails, Claude answers independently
- Output clearly marked: "⚠️ Codex unavailable - Claude-only response"

## Notes

- Codex runs in suggest mode (analysis only, no file modifications)
- For large codebases, specify file paths for better context
