---
description: Promote raw L3 log entries into L2 knowledge cards (`index/<topic>.md`), surface auto-recorded entries for batch review, or promote a card into L1 `pinned.md`.
---

# /ltm:distill — three-tier maintenance

This command orchestrates the L1/L2/L3 lifecycle. The actual file operations are performed by `${CLAUDE_PLUGIN_ROOT}/scripts/distill.py` (for L2) and direct edits via Edit tool (for L1). The interactive flow — surfacing proposals, gathering assent, writing — happens here.

Routing on `$ARGUMENTS`:

| Argument | Mode | Description |
|---|---|---|
| (empty) or `--retroactive` | Retroactive distill | Cluster all undistilled L3 entries and propose L2 cards. |
| `--review-recent` | Review pending digest | Read the newest `.session-digest-archive/` file (or `.session-digest.pending` if not yet rotated) and present auto-recorded entries to the user. |
| `--promote <log-id>` | L1 promotion | Read a specific L3 entry, draft a one-line L1 principle, confirm with user, append to `pinned.md`. |
| `--undo <topic>` | Revert an L2 card | Confirm with user, then run `distill.py undo --topic <name>` (deletes card + reverts `distilled: true` on cited log entries). |

## Preflight (all modes)

1. Confirm `.claude/ltm/CLAUDE.md` exists. If not, tell the user "this project hasn't bootstrapped LTM yet — run `/ltm:init` first" and stop.
2. Reload `.claude/ltm/CLAUDE.md` to honour any project-specific kind / clustering rules.

## Mode 1: Retroactive distill (`--retroactive` or no arg)

1. Run `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/distill.py --target-dir .claude/ltm scan`.
2. Parse the JSON. If `undistilled_count == 0`, say "Nothing to distill — all L3 entries are already linked to L2 cards." and stop.
3. Present clusters in priority order (most entries first). For each cluster, show:
   - Suggested topic slug (`topic_suggestion`)
   - Kind distribution
   - Entry titles (read entry titles, not full body)
4. For each cluster, **draft** an L2 card from the entries:
   - Read each log entry (full body) via Read tool.
   - Synthesize one-line `summary` (≤120 chars) — the *rule* or *insight*, not the topic.
   - Synthesize one-line `context` — *why* the rule exists (constraint, incident, principle).
   - List `evidence` = the cluster's entry ids.
   - Check for supersede: if an existing card at `.claude/ltm/index/<topic>.md` already says something, decide merge-vs-supersede.
5. Present each draft to the user in this exact format:

   ```
   ### Card: <topic>
   summary: <one-line>
   context: <one-line>
   evidence: <id1, id2, ...> (N entries)
   supersedes: <if any>
   ```

6. Ask: "Apply this card? (y / edit / skip)". On `edit`, take user revisions and re-show. Skip → move on.
7. On `y`, run:
   ```bash
   printf '%s\n%s\n' "<summary>" "<context>" | \
     python3 ${CLAUDE_PLUGIN_ROOT}/scripts/distill.py \
       --target-dir .claude/ltm apply \
       --topic <topic> \
       --evidence <id1,id2,...> \
       [--supersedes <old-card-id>]
   ```
8. After all clusters processed, list cards now in `.claude/ltm/index/` and suggest any candidates for L1 promotion (cards cited by ≥3 active sessions or marked explicitly as core principle). Do not promote autonomously — that requires explicit user assent (`/ltm:distill --promote`).

## Mode 2: `--review-recent`

1. Find the most recent `.claude/ltm/.session-digest.pending` or, if it has been rotated already, the newest file in `.claude/ltm/.session-digest-archive/`.
2. Read it. Each line is `- [<kind>] <title> → <path>`.
3. For each entry, Read the log file and present:
   - Kind, title, autonomous: true
   - Body (first 400 chars + "…" if longer)
4. Ask the user: "Any of these need correction or supersede? (id / `all-good`)".
5. On correction: Edit the log file directly (overwrite-nudge will fire — that's expected, this is a deliberate L3 fix). If a wrong entry should be retired, add a one-line `note: superseded by user review 2026-MM-DD` to the body and append a clarifying entry via `ltm-append`.
6. On `all-good`, optionally suggest running `/ltm:distill --retroactive` if any reviewed entry now warrants L2 promotion.

## Mode 3: `--promote <log-id>`

1. Locate the log entry by id: `grep -l "id: <log-id>" .claude/ltm/log/*.md`.
2. Read the entry. Draft a single-line L1 principle (≤140 chars, imperative or declarative — "X over Y", "Always Z", "Never Q because R").
3. Show the draft. Ask: "Add this line to `.claude/ltm/pinned.md`? (y / edit / no)". L1 requires explicit assent — apply IRON-LAW-style assent gating here.
4. On `y`, Edit `.claude/ltm/pinned.md`: append under `## Core` section with a date stamp. Also append to `## Promotion log` section: `- <date> — promoted from <log-id>: <one-line>`.
5. Optionally record the promotion itself via `ltm-append` as a `rule-evolution`-kind entry.

## Mode 4: `--undo <topic>`

1. Read `.claude/ltm/index/<topic>.md`. Show its summary + evidence list to the user.
2. Ask: "Delete this card and revert `distilled: true` on its evidence entries? (y / no)".
3. On `y`, run `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/distill.py --target-dir .claude/ltm undo --topic <topic>`. Report the count of reverted entries.

## Anti-patterns

- Calling `distill.py apply` without showing the draft to the user. The whole point of L2 is that the user can shape the card before it gets cited everywhere.
- Auto-promoting to L1 in retroactive mode. L1 is the only tier with explicit-assent guard — keep it intentional.
- Skipping the Read tool on cited log entries. Synthesizing `summary` / `context` from filename slug alone produces low-quality cards.
- Re-running distill on already-distilled entries. `scan` filters them out; respect that.
