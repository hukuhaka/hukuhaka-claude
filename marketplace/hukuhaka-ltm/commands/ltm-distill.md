---
description: 6-step skeleton distill — cluster (subagent) → file mapping (main context) → N parallel card writers → per-card validate → L1 update → final review. Single mode; no arguments.
allowed-tools: Read, Bash, Agent, AskUserQuestion
---

# /ltm:distill — skeleton orchestration (v0.4.0)

This command re-derives L2 from L3 and L1 from L2. **Cluster + writers + validate + L1 + final review are subagents. File mapping (Step 2) is done by you, the main orchestrator, directly** — that's the load-bearing change in v0.4.0. The old multi-agent lock-step (cluster → plan → validate → writer → cluster-l1 → plan-l1 → validate-l1 → writer) collapsed because every per-stage schema layer became echo. You author the file-allocation plan in your own context where the user can intervene.

`$ARGUMENTS` is ignored.

## Preflight

1. Confirm `.claude/ltm/CLAUDE.md` exists. If not: "this project hasn't bootstrapped LTM — run `/ltm:init` first" and stop.
2. Confirm `.claude/ltm/pinned.md` exists. If not: "pinned.md missing — run `/ltm:init`" and stop.
3. Re-load `.claude/ltm/CLAUDE.md` to honour project policy. All subagent prompts receive it verbatim.

## Step 1 — cluster (one subagent invocation)

Enumerate L3 entries and pass paths + policy to the cluster subagent.

```bash
ls .claude/ltm/log/*.md
```

Invocation:

```
Agent(subagent_type: "hukuhaka-ltm:cluster",
      prompt:
        "L3 paths:\n" + <every log/*.md path on its own line> +
        "\n\nProject policy (verbatim):\n" + <contents of .claude/ltm/CLAUDE.md> +
        "\n\nRead each L3 in full. Decide axis decomposition. Output JSON per spec.")
```

**Coverage check** (you do this after receiving the JSON):

- Strip any code-fence wrappers from the response.
- Collect every `id:` from `.claude/ltm/log/*.md` frontmatter (bash one-liner with `grep '^id:' .claude/ltm/log/*.md`).
- Every id MUST appear in exactly one axis's `l3_ids`. No duplicates.
- If coverage fails: re-invoke cluster ONCE with the specific gap surfaced. If still failing, surface to the user and stop.

## Step 2 — file mapping (you do this in your own context)

This is the v0.4.0 hinge. Do NOT delegate this step to a subagent. You read existing L2 + the cluster output and decide how each axis maps to a file operation. Your decisions go to the user gate at 2g, then to the N writer subagents at Step 3.

### 2a. Inputs

- Cluster output from Step 1 (axes with `axis_id`, `name`, `description`, `l3_ids`)
- Existing L2 frontmatter — Read every `.claude/ltm/index/*.md` (frontmatter only is enough; body only if disambiguation needed)

### 2b. Decide op for each axis

**Default bias: axis = card.** Cluster's axes are the canonical decomposition this cycle. The strong default is one card per axis. If an axis maps to 2+ existing cards that cover overlapping or adjacent ground within that axis, **default to `create-merging` (collapse them into one)**, not multiple parallel `edit` rows. Preserving an in-axis card split requires explicit per-card justification — that two cards within the same axis genuinely encode non-overlapping principles that would be lost in a merge. "These are different angles" is not justification; the merged card carries multiple sections covering each angle.

This bias exists because v0.1–v0.3 cards monotonically accumulated — every new L3 became a new card and cross-axis L2 merge was structurally invisible. The user gate at 2g exists to catch the opposite mistake (over-merging cards that genuinely belong split), so leaning toward collapse here is the safer default.

For each axis, pick ONE of:

- **`edit`** — exactly one existing card covers this axis (its `evidence:` overlaps significantly with axis `l3_ids`, OR its `topic`/`summary` semantically matches the axis description). Writer integrates any new L3 evidence and rewrites body if it's a stub.
- **`create`** — no existing card matches. Writer creates a new file.
- **`create-merging`** — the axis spans 2+ existing cards. Writer creates a new (or repurposed) winner file; orchestrator deletes the source files after. **Use this whenever multiple existing cards land in one axis** unless the per-card justification rule above is met.
- **`split`** — rare. One existing card's content is genuinely two axes. Orchestrator retires the source; two writer invocations create the new pair.
- **`noop`** — the axis maps cleanly to one existing card AND the card needs no changes (evidence list unchanged, body already substantive). Skip.

You have free judgment on the matching. Per project decision D1, no deterministic rule (those failed in v0.2.x). Output a rationale alongside each op so the user gate can scrutinize.

### 2c. Orphan check

Walk every existing L2 card. For each, ask: "does at least one Step-1 axis claim any of this card's `evidence:` L3 ids?"

- If NO axis claims any of the card's L3s → the card's axis disappeared (all its L3s went elsewhere or were retired). Add an orphan-retire row: `{op: retire, target: <slug>.md, rationale: "no axis claims this card's evidence"}`.
- If SOME L3s are claimed by other axes but the card has substantive synthesis beyond those L3s → consider `set-evidence` (edit with shrunk evidence list).

### 2d. Re-request cluster if obviously off

If after 2b–2c you see that the cluster's axis decomposition is clearly wrong (e.g., two single-L3 axes that obviously belong together, or one axis that lumps L3s with no shared theme), re-invoke the cluster subagent ONCE with specific feedback. Example feedback:

> "Axes a8 and a9 both contain a single CLI-tooling L3 (installer DX and TUI rendering). They're the same axis — please re-cluster as one `cli-tooling` axis."

Cap: 1 re-request. If the re-request output is still off, **do not auto-retry**. Escalate to the user with `AskUserQuestion` — show the cluster output + your specific concern, let user decide whether to override the cluster decomposition by hand or proceed with what cluster returned.

### 2e. Build the assignment plan

Once your op decisions are final, emit the assignment plan as YAML in your visible response:

```yaml
assignments:
  - target: cli-tooling.md
    op: create-merging
    sources_to_retire: [tooling-installer.md, tooling-python-tui.md]
    l3_ids: [install-sh-..., tty-setraw-...]
    rationale: "Two cards merged into CLI tooling conventions axis"
  - target: skill-hukuhaka-ltm.md
    op: edit
    l3_ids: [..., ...]
    rationale: "Existing axis; evidence list unchanged but body needs rewrite (stub)"
  - target: meta-project-no-subdir-autoload.md
    op: retire
    rationale: "Absorbed into skill-project-mapper.md axis"
```

### 2f. User gate (Step 2g per the plan terminology)

Show the assignment plan + per-op rationale + counts (e.g., "12 cards: 8 edit, 1 create, 1 create-merging, 2 retire").

- **≤4 non-noop rows** → `AskUserQuestion` with one option per row, `multiSelect: true`. Labels like "Apply: <target> (<op>)". User checks which to proceed with.
- **>4 non-noop rows** → plain text approval. Tell the user:
  > Approve which assignments? Reply with row numbers (e.g., `1,2,4`), `all`, `none`, or `skip N` to drop row N. Inspect each `retire` and `create-merging` row before approving — both delete files irreversibly.

Wait for the response. Build the approved subset. Drop any row the user skipped.

## Step 3 — card writers (N parallel subagent invocations)

For each approved non-retire assignment, invoke the writer subagent. **Emit all writer invocations in ONE message with multiple Agent tool calls** for parallelism.

```
Agent(subagent_type: "hukuhaka-ltm:writer",
      prompt:
        "Assignment:\n" + <YAML of the one assignment row> +
        "\n\nL3 bodies (full text):\n" + <each L3 in l3_ids inlined> +
        ( "\n\nExisting card content:\n" + <Read .claude/ltm/index/<target>> if op == edit) +
        ( "\n\nSource cards to merge:\n" + <Read each source in sources_to_retire> if op == create-merging) +
        "\n\nReference exemplar path: .claude/ltm/index/git-publish-workflow.md (Read it for calibration)" +
        "\n\nProject policy (verbatim):\n" + <.claude/ltm/CLAUDE.md> +
        "\n\nWrite the card per agent spec. Return JSON only.")
```

Retire assignments do NOT invoke writer. Handle them directly:

```bash
rm .claude/ltm/index/<target>
```

For `create-merging`, after the winner writer returns successfully, delete each source:

```bash
rm .claude/ltm/index/<source>
```

Collect each writer's JSON response. Note any `{error: ...}` responses — surface to user, continue with remaining assignments.

## Step 4 — validate (one subagent invocation)

After all writers complete, invoke the validate subagent with the list of affected card paths (everything written/edited/merged in Step 3; not retired cards).

```
Agent(subagent_type: "hukuhaka-ltm:validate",
      prompt:
        "Affected card paths:\n" + <each path on a line> +
        "\n\nL3 directory: .claude/ltm/log/ (Read individual entries as needed to verify evidence)" +
        "\n\nReference card: .claude/ltm/index/git-publish-workflow.md" +
        "\n\nRead each card cold. Report issues per agent spec. Return JSON only.")
```

Parse the JSON `{issues: [{card, problem, severity}]}`.

- If `issues: []` → proceed to Step 5.
- If non-empty issues → present to user with `AskUserQuestion`:
  - One option per high-severity issue: "Re-spin writer for `<card>`" or "Accept as-is".
  - Per response, either re-invoke writer for that card (with the validator's `problem` text in the prompt as feedback) and re-validate (loop bounded at 1 re-spin per card), or accept and proceed.
  - Medium/low severity issues: surface as a summary but don't gate by default.

## Step 5 — L1 update (one subagent invocation)

Invoke the l1-update subagent. It reads the new L2 corpus + current pinned.md and writes pinned.md directly.

Get current byte count for the prompt:

```bash
wc -c .claude/ltm/pinned.md
```

```
Agent(subagent_type: "hukuhaka-ltm:l1-update",
      prompt:
        "L2 corpus paths:\n" + <every .claude/ltm/index/*.md path> +
        "\n\nCurrent pinned.md (verbatim):\n" + <Read .claude/ltm/pinned.md> +
        "\n\nProject policy (verbatim):\n" + <.claude/ltm/CLAUDE.md> +
        "\n\nCurrent bytes: <N> / Cap: 2048" +
        "\n\nDecide L1 changes and edit pinned.md directly. Return JSON only.")
```

Parse `{lines_added, lines_retired, lines_kept, bytes_after, cap}`. Surface a one-line summary.

No user gate here in the default flow — the dry-run gate was at Step 2g. If you want to gate L1 separately, you can (especially if `lines_retired` is non-empty) but the v0.4.0 design treats L1 as an automatic consequence of L2 changes. Final review catches any anomalies.

## Step 6 — final review (one subagent invocation)

End-to-end sanity check across the now-current corpus.

```
Agent(subagent_type: "hukuhaka-ltm:final-review",
      prompt:
        "L2 corpus paths:\n" + <every .claude/ltm/index/*.md path> +
        "\n\npinned.md path: .claude/ltm/pinned.md" +
        "\n\nL3 directory: .claude/ltm/log/ (glob for paths; Read frontmatter as needed)" +
        "\n\nProject policy (verbatim):\n" + <.claude/ltm/CLAUDE.md> +
        "\n\nReport cross-card and cross-tier anomalies per agent spec. Read-only. Return JSON only.")
```

Parse `{summary, anomalies}`. Surface to the user in the closeout. Do NOT auto-fix anomalies — user reads them and decides what to do (manual fix, defer to next cycle, etc.).

## Post — reproject (deterministic)

After Step 6, run reproject once to sync L3 `distilled-into` pointers:

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/distill.py --target-dir .claude/ltm reproject
```

Report `{reprojected, cards_scanned, entries_scanned, orphans?}`. Any orphans here are an anomaly Step 6 should have flagged.

## Closeout

Report to the user:

- **L2 changes**: count of edits / creates / merges / retires applied. Skipped count if user dropped any at Step 2g.
- **Validate**: `issues: []` or per-card defects raised at Step 4.
- **L1 changes**: `{lines_added, lines_retired, bytes_after / 2048}` from Step 5.
- **Anomalies**: from Step 6, with concrete file references.
- **Reproject**: row count touched + any orphans.

End with `result:` line summarizing what was applied.

## Anti-patterns

- **Skipping Step 2 user gate** (`AskUserQuestion`) and proceeding to writers. The whole v0.4.0 architecture trusts you in Step 2 *with the user as backstop*. No backstop → echo migrates here.
- **Spawning writers sequentially.** Step 3 is the parallelism point — emit all writer Agent calls in a single message.
- **Delegating Step 2 to a subagent.** That recreates the v0.2.x→v0.3.x mistake of "another agent layer to fight echo". You do the mapping in main context because the user can read your reasoning and intervene.
- **Approving `retire` rows in bulk without inspecting them.** Each retire is irreversible at the file level (recovery is git revert).
- **Touching L3 frontmatter from any agent.** Only `distill.py reproject` writes `distilled-into`.
- **Running reproject before Step 3 completes.** Reproject's truth source is L2 evidence lists; running it mid-batch produces incomplete state.
- **Adding a multi-mode arg dispatcher (`--retroactive`, `--review-recent`, `--promote`, `--undo`).** Those were removed in v0.3.0; v0.4.0 stays single-mode. If users want different behaviors, they intervene at the user gates.
- **Bypassing Step 4 validate or Step 6 final-review because "I already see the results".** Both serve as independent checks; skipping recreates the v0.1–v0.3 echo failure mode (writers without cold-read review).
