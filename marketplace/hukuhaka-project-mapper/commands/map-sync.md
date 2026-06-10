---
name: map-sync
description: "Full sync pipeline: scatter, skeleton, bundle, describe+synth, merge, write, validate"
allowed-tools:
  - "Bash(bash:*)"
  - "Task"
  - "Agent"
---

# /hukuhaka-project-mapper:map-sync [path]

Full documentation sync pipeline. Generates `.claude/` docs from codebase analysis. Reads `.claude/scan.md` as the manifest for which directories receive scattered `CLAUDE.md` — run `/hukuhaka-project-mapper:map-scan` first if scan.md does not exist.

## Why Scripts + Restricted Agents?

Structure extraction (symbols, imports, file counts, TODOs) is deterministic — the bundled `skeleton.py` computes it exactly, with zero tokens and zero hallucination. The LLM agents (`describe`, `synth`) only write prose over that skeleton, from a script-assembled context bundle, with no exploration tools. Scope is enforced by construction: everything an agent sees is decided by `bundle.py`, not by agent obedience. The structured JSON interface into the writer is unchanged, keeping the pipeline inspectable and debuggable.

## Pre-flight

Before starting the pipeline, run the bundled preflight script via Bash from the project root (cwd):

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sync/preflight.sh
```

The script cats `.claude/map.md`, `.claude/design.md`, `.claude/spec.md` (if they exist) into stdout so the orchestrator sees the current doc state.

Do NOT use Bash `ls` to enumerate `.claude/` and do NOT skip preflight. If the script reports `.claude/` does not exist, tell user to run `/hukuhaka-project-mapper:map-init` first and STOP.

## Pipeline

Execute these steps **sequentially** unless a step explicitly says parallel. Each step MUST complete before the next begins.

### Step 1: Scatter

Refresh each scattered `CLAUDE.md` **first**, before the core analyze phase. This ordering is deliberate: the bundle assembler (Step 2b) reads the scattered `CLAUDE.md` files from disk, so they must be freshly regenerated before the bundle is built — top-level docs are built on current folder summaries.

If `.claude/scan.md` is missing from the preflight output, STOP and tell the user to run `/hukuhaka-project-mapper:map-scan` first.

**Select which directories to refresh (incremental).** Run the bundled helper via Bash from the project root:

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sync/changed-dirs.sh
```

It reads `.claude/scan.md` (the scatter manifest) and `.claude/.map-sync-state` (last synced commit), and prints **only the scatter directories that need regeneration**, one per line. The mapping is git-diff based:

- A changed file refreshes the nearest scatter directory that owns it (its own `## Files`).
- A brand-new scatter directory (placeholder, from a recent `map-scan`) refreshes itself **and** its parent scatter directory (whose `## See Also` must index the new child).

The helper emits **ALL** scatter rows (full sync) when any of these hold — these are the safe, correct defaults; do NOT second-guess them:

- no `.claude/.map-sync-state` yet (first sync after `map-scan`)
- the recorded commit is invalid (history rewrite)
- the project is not a git repo
- the user passed `--full` (force a full refresh — append `--full` to the helper invocation)

Iterate **exactly** the directories the helper prints. Do NOT widen this list back to "all rows", and do NOT narrow it further by your own judgment — the helper already decided scope.

For each directory D the helper prints:

```
Bash: bash ${CLAUDE_PLUGIN_ROOT}/scripts/sync/skeleton.sh . --scatter D
  → capture the extract from stdout →
Agent(subagent_type: "hukuhaka-project-mapper:describe", prompt: "scatter: D\n\n{extract}")
  → wait for scatter JSON →
Agent(subagent_type: "hukuhaka-project-mapper:writer", prompt: "scatter: {scatter JSON}")
```

Rules:
- Never touch root `./CLAUDE.md`
- Respect `.gitignore` patterns
- Refresh exactly the directories `changed-dirs.sh` prints — the helper, not you, owns scope
- describe+writer pairs are sequential per directory (writer depends on the scatter JSON)

### Step 2: Analyze (skeleton → bundle → describe ∥ synth → merge)

#### 2a. Skeleton (script, 0 tokens)

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sync/skeleton.sh
```

Writes `.claude/.sync/skeleton.json`: stats, todos, stack, and candidate entry_points / components / directories with the deterministic import graph (`depends_on`). This is the structural half of the analysis — no agent decides it.

#### 2b. Bundle (script, 0 tokens)

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sync/bundle.sh
```

Writes `.claude/.sync/bundle.md` (skeleton + scattered CLAUDE.md + existing docs) and reports its size to stderr. Capture the size for the final report. There is no size limit.

#### 2c+2d. Describe and Synth (agents, parallel)

Spawn **BOTH agents with BOTH Agent tool calls in ONE single assistant message** — this is the one sanctioned parallelism; they are mutually independent consumers of the same bundle. Do NOT dispatch them in two separate messages, and do NOT wait for describe before spawning synth.

Pass the bundle by PATH, not by contents — never paste bundle.md into the prompt (relaying it costs output tokens twice and does not scale; the agents Read it themselves):

```
Agent(subagent_type: "hukuhaka-project-mapper:describe", prompt: "Read {abs path to .claude/.sync/bundle.md} then describe:")
Agent(subagent_type: "hukuhaka-project-mapper:synth",    prompt: "Read {abs path to .claude/.sync/bundle.md} then synth:")
```

Wait for BOTH results. Each returns a single JSON object (describe: descriptions + entry include verdicts; synth: data_flow/patterns/decisions).

#### 2e. Merge (script, 0 tokens)

Pipe both agent outputs into the merge script:

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sync/merge.sh <<'EOF'
{"describe": {…describe JSON…}, "synth": {…synth JSON…}}
EOF
```

stdout is the 9-field analyzer-contract JSON for the writer. stderr reports structural validation (dropped hallucinated paths, unknown data_flow names) — capture these counts for the final report.

### Step 3: Write

After merge completes, spawn writer agent with the merged JSON:

```
Agent(subagent_type: "hukuhaka-project-mapper:writer", prompt: "Generate .claude/ docs from: {merged 9-field JSON}")
```

### Step 4: Validate

After write completes, spawn validator agent:

```
Agent(subagent_type: "hukuhaka-project-mapper:validator", prompt: "Validate .claude/ links")
```

### Step 5: Record sync state

After validation completes successfully, stamp the synced commit so the next run can compute an incremental scatter set. Run via Bash from the project root:

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sync/record-sync.sh
```

This writes `.claude/.map-sync-state` with the current `HEAD`. It is a no-op on a non-git project (the pipeline simply stays full-sync). Do NOT run this if an earlier step aborted — leaving the state unchanged makes the next run safely re-sync.

Note: `.claude/.map-sync-state` and `.claude/.sync/` are machine-local state. Add them to the project's `.gitignore` if not already ignored.

## Final Report

After all steps complete, display:

```
Sync complete
  Step 1 (scatter)
    Mode: {incremental | full}
    CLAUDE.md refreshed: {n} of {total} scatter dirs

  Step 2 (analyze)
    Files scanned: {n}    bundle: ~{n} tokens
    Entry points: {n}  Components: {n}
    Dropped hallucinated paths: {n}

  Step 3 (write)
    Docs generated: 4

  Step 4 (validate)
    Links checked: {n}
    Broken: {n}

  Step 5 (record)
    Synced commit: {short sha | n/a (non-git)}

  Usage
    {wall} | tokens {total} (out {output}, cache {cache})
```

The `Usage` line is supplied by the sync-cost hook, which fires after the
Step 5 `record-sync.sh` call and injects the figures into context via
`additionalContext`. Copy them verbatim from that injected
`map-sync usage for this run ...` note into the block above. If the note is
absent (non-git project, or the hook did not run), omit the `Usage` block.

## On Failure

If any step fails, STOP and explain the failure. Do NOT attempt workarounds.

- `skeleton.sh` / `bundle.sh` / `merge.sh` nonzero exit → STOP and show the script's stderr.
- describe or synth returns malformed JSON → the merge script errors clearly; STOP and show it. Do NOT hand-repair agent JSON.
- Do NOT write `.claude/` files directly — only agents write files.
- Do NOT fall back to exploring the codebase yourself or spawning the legacy analyzer; the scripts are the pipeline.

## Critical Rules

- All `subagent_type` values MUST use `hukuhaka-project-mapper:` prefix (e.g., `hukuhaka-project-mapper:describe`)
- Strict ordering: skeleton → bundle → {describe ∥ synth} → merge → writer → validator. The ONLY parallel fan-out is describe+synth
- describe and synth MUST be dispatched in the SAME message block (they share the bundle and are mutually independent)
- The merge script MUST complete before the top-level writer is spawned (writer consumes the merged JSON)
- The top-level writer MUST NOT appear in the same message block as describe or synth
- Scatter describe+writer pairs are sequential per subdirectory
