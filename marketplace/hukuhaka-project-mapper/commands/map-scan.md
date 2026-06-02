---
name: map-scan
description: "Decide CLAUDE.md placement: write .claude/scan.md + placeholder CLAUDE.md files"
allowed-tools:
  - "Bash(bash:*)"
  - "Bash(python3:*)"
  - "Read"
---

# /hukuhaka-project-mapper:map-scan [path]

One-time structural decision for project-mapper. Decides where `CLAUDE.md` should live in the project tree and writes the manifest to `.claude/scan.md` plus empty placeholder `CLAUDE.md` files at every scatter location.

This command does NOT fill in content. Content is written by `/hukuhaka-project-mapper:map-sync`, scoped to the rows of `scan.md`. `scan.md` is the single source of truth — sync reads it, never reinvents.

## Pre-flight

`.claude/` must exist. If `.claude/map.md` is missing, tell the user to run `/hukuhaka-project-mapper:map-init` first and STOP.

## Steps

### Step 1 — Run scan script

Invoke the bundled script via Bash from the project root (cwd):

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/scan/scan.sh
```

The script:
1. Walks the project directory tree (via `git ls-files -co --exclude-standard`, falling back to `os.walk` if not a git repo)
2. Classifies each directory with a deterministic 6-rule decision tree (see "Decision tree" below)
3. Writes `.claude/scan.md` (a single table of all decisions)
4. Touches an empty `CLAUDE.md` at every `decision == scatter` row, preserving any existing `CLAUDE.md` content (does not overwrite)

### Step 2 — Report

Display the script's stdout verbatim as the completion report. The script includes the count summary (scatter/skip/passthrough) and the next-step suggestion (`/hukuhaka-project-mapper:map-sync`) — do not paraphrase.

## Decision tree

Each directory is classified by the first matching rule (no LLM):

| # | Rule | Trigger | Decision |
|---|---|---|---|
| 1 | DENY | Directory name in deny-list (`node_modules`, `vendor`, `assets`, `dist`, `build`, `.gradle`, `res`, ...) | skip (no recurse) |
| 2 | MARKER | Directory contains workspace marker (`package.json`, `pyproject.toml`, `build.gradle`, `AndroidManifest.xml`, ...) | scatter |
| 3 | PASSTHROUGH | Own source files == 0 AND exactly 1 source-bearing child directory | passthrough (no CLAUDE.md, recurse into child) |
| 4 | BRANCH | >=2 source-bearing children OR (own source >=1 AND >=1 source-bearing child) | scatter |
| 5 | LEAF | >=2 own source files, no source-bearing children | scatter |
| 6 | TRIVIAL | Own source <=1 AND no source-bearing children | skip |

Source-bearing child = a child directory whose subtree contains at least one source file in the project's primary languages.

Full deny-list, marker list, and source extension list are defined in `scripts/scan/scan.py` constants. Edit those constants to customize per-project.

## scan.md format

See [scan-md-format.md](../scripts/scan/references/scan-md-format.md) for column spec, user-overrides section semantics, and Stocks-shaped example.

## Re-running

`map-scan` is idempotent over deterministic input. Re-running on an unchanged tree produces an identical `scan.md`. User edits to `scan.md` below the `<!-- user-overrides -->` marker are PRESERVED across re-runs — script-generated rows are above, manual rows below.

If a directory has been added to the project since the last scan and `map-sync` reported it as `(new)`, re-run `map-scan` to incorporate it.

## On Failure

If `scan.sh` fails (missing `python3`, not a git repo, no source files found), STOP and report the script's stderr. Do NOT attempt LLM fallback. Do NOT use the Write/Edit tools to create `scan.md` manually.

## Critical Rules

- Do NOT spawn any agents (no `Agent` / `Task` calls)
- Do NOT use Write or Edit to invent placement decisions — invoke the bundled script
- Never touch root `./CLAUDE.md`
- `scan.md` is the single source of truth — sync reads it, never reinvents
