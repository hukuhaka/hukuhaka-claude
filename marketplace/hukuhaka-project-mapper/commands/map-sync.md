---
name: map-sync
description: "Full sync pipeline: scatter, analyze, write, validate"
allowed-tools:
  - "Bash(bash:*)"
  - "Task"
  - "Agent"
---

# /hukuhaka-project-mapper:map-sync [path]

Full documentation sync pipeline. Generates `.claude/` docs from codebase analysis. Reads `.claude/scan.md` as the manifest for which directories receive scattered `CLAUDE.md` — run `/hukuhaka-project-mapper:map-scan` first if scan.md does not exist.

## Why Separate Agents?

Analyzer uses read-only tools to analyze code. Writer uses edit tools to write documentation. Separating them ensures each agent operates with minimum permissions, and the structured JSON interface between them makes the pipeline inspectable and debuggable.

## Pre-flight

Before starting the pipeline, run the bundled preflight script via Bash from the project root (cwd):

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sync/preflight.sh
```

The script cats `.claude/map.md`, `.claude/design.md`, `.claude/spec.md` (if they exist) into stdout. Capture this output and pass it to the analyzer agent as context.

Do NOT use Bash `ls` to enumerate `.claude/` and do NOT skip preflight. If the script reports `.claude/` does not exist, tell user to run `/hukuhaka-project-mapper:map-init` first and STOP.

## Pipeline

Execute these steps **sequentially**. Each step MUST complete before the next begins. Do NOT run steps in parallel.

### Step 1: Scatter

Refresh each scattered `CLAUDE.md` **first**, before top-level analysis. This ordering is deliberate: when the analyzer (Step 2) later reads files inside these directories, Claude Code auto-loads the just-refreshed folder `CLAUDE.md` into the analyzer's context (nested CLAUDE.md on-demand load), so top-level docs are built on current folder summaries.

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
Agent(subagent_type: "hukuhaka-project-mapper:analyzer", prompt: "scatter: D")
  → wait for result →
Agent(subagent_type: "hukuhaka-project-mapper:writer", prompt: "scatter: {scatter JSON}")
```

Rules:
- Never touch root `./CLAUDE.md`
- Respect `.gitignore` patterns
- Refresh exactly the directories `changed-dirs.sh` prints — the helper, not you, owns scope

### Step 2: Analyze

After scatter completes, spawn analyzer agent and wait for JSON result. Because scatter ran first, the analyzer auto-loads each freshly-written folder `CLAUDE.md` as it reads files in those directories:

```
Agent(subagent_type: "hukuhaka-project-mapper:analyzer", prompt: "Analyze {path}. Context: {map.md + design.md contents}")
```

### Step 3: Write

After analyzer completes, spawn writer agent with analyzer output:

```
Agent(subagent_type: "hukuhaka-project-mapper:writer", prompt: "Generate .claude/ docs from: {analyzer JSON result}")
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

Note: `.claude/.map-sync-state` is machine-local state. Add it to the project's `.gitignore` if not already ignored.

## Final Report

After all steps complete, display:

```
Sync complete
  Step 1 (scatter)
    Mode: {incremental | full}
    CLAUDE.md refreshed: {n} of {total} scatter dirs

  Step 2 (analyze)
    Files scanned: {n}

  Step 3 (write)
    Docs generated: 4

  Step 4 (validate)
    Links checked: {n}
    Broken: {n}

  Step 5 (record)
    Synced commit: {short sha | n/a (non-git)}
```

## On Failure

If any step fails, STOP and explain the failure. Do NOT attempt workarounds. Do NOT write `.claude/` files directly — only agents write files.

## Critical Rules

- All `subagent_type` values MUST use `hukuhaka-project-mapper:` prefix (e.g., `hukuhaka-project-mapper:analyzer`)
- Analyzer and writer MUST NOT run in parallel — writer depends on analyzer output
- Scatter analyzer+writer pairs are also sequential per subdirectory
