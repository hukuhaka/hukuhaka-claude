---
name: ltm-append
description: >
  Record a new entry to .claude/ltm/log/ when the conversation produces
  worth-preserving knowledge — decisions, findings, philosophy, abandoned
  approaches. Drafts entry, requires user assent, then writes via
  timestamped append helper. Do NOT use for current conversation state,
  scratch notes, or non-endorsed content.
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: ${CLAUDE_PLUGIN_ROOT}/scripts/append-entry-nudge.sh
---

# ltm-append

Detect a worth-preserving moment in conversation and record it as an LTM entry.

<IRON-LAW>
NEVER call Bash(append-entry.py …), Write, Edit, or any tool that creates
or mutates a file under .claude/ltm/log/ in the same turn the entry was
drafted UNLESS the user has explicitly assented in that same turn.

"Explicit assent" = a clear, direct go-word from the user in the same turn.
Whitelisted defaults:

- English: `yes`, `yeah`, `yep`, `yup`, `go`, `go ahead`, `do it`,
  `save it`, `record it`, `commit`, `write it`, `log it`, `ship it`,
  `proceed`
- Korean: `응`, `예`, `네`, `그래`, `어`, `좋아`, `기록`, `기록해`, `써`,
  `저장`, `남겨`, `ㄱㄱ`, `ㅇㅇ`

NOT assent (still ambiguous): `ok` / `okay` / `오케이` / `ㅇㅋ`, `sure`,
`hmm`, `maybe`, `좀`, `글쎄`, silence, thumbs-up emoji alone. These are
soft yeses, not commit signals — ask again for a clear go-word.

Project RULES (`.claude/ltm/CLAUDE.md`) may extend the whitelist with
additional language- or team-specific go-words. Honour them on
activation.

This rule applies to EVERY entry regardless of how obvious the closure
sounded. Auto-appending is the failure mode this skill exists to prevent.
A PreToolUse hook on this skill emits a reminder to stderr when a Bash
command targets `append-entry.py` against `.claude/ltm/log/`; the hook
does not block (it cannot reliably read conversation context to verify
assent). The real gate is YOU, here, applying IRON-LAW + the pre-action
announcement below. Do not lean on the hook.
</IRON-LAW>

> **Default language: English.** Plugin defaults assume English entries
> and triggers. Projects may declare additional language-specific
> triggers in `.claude/ltm/CLAUDE.md` — load and honour them.

## When this skill activates

Two paths: passive (closure detection) and active (explicit user
invocation). Project RULES may extend either list.

### Passive — closure-shaped statements

- "we decided", "let's go with", "the choice is"
- "turns out", "the actual reason", "found out"
- "won't work because", "this is wrong because", "abandoning"
- "general principle", "lesson", "the takeaway is"
- "trade-off resolved as"

Listen for *closure-shaped* statements. Open exploration ("what if we did
X") is not append-worthy yet — wait for the closing.

### Active — explicit invocation

Activate immediately when the user signals intent to record, even without
a closure phrase. Examples:

- English: "let's record this", "save this to ltm", "log this", "add an
  entry", "let's note this down", "write this up", "I want to record
  something"
- Korean: "이거 기록하자", "ltm에 적어두자", "이거 남겨두자", "엔트리 추가
  하자", "기록 추가", "정리해서 남기자", "회고 남기자"

Active mode is for *retrospective* recording — design intent, philosophy,
journey-style entries that don't have a single closure moment. The user
provides the framing; you draft from conversation context (or by asking
focused follow-ups), then go through the same Confirm + Write flow as
passive mode. Same IRON-LAW assent gate applies.

## Pre-flight

1. Check `.claude/ltm/CLAUDE.md` exists. If not, tell user "this project hasn't bootstrapped LTM yet — run `/ltm:init` first" and stop.
2. **Reload RULES**: read `.claude/ltm/CLAUDE.md` fully. The user's project may have declared specific kinds, triggers, or fields; follow them.
3. Confirm gate: do NOT use Bash to invoke append-entry.py, and do NOT
   use Write or Edit on anything under `.claude/ltm/log/`, until the user
   has explicitly assented in the same turn (see IRON-LAW above). The
   drafting step is in-conversation only — no tool calls that touch disk.

## Drafting

Build the draft with these elements:

- **Title**: one-line summary, ≤80 chars. Quote the user's own framing when possible.
- **Kind**: pick from RULES-declared kinds. If user's statement straddles two, ask. If RULES doesn't list a fitting kind, propose a new one (don't force-fit).
- **Body**: paraphrase what's being recorded. Include:
  - what the situation was
  - what was decided / found / abandoned
  - the *reason* — this is the highest-value part for future-you
  - any context (file paths, related entries, links) that future-you would need to reconstruct
- **Supersedes** (optional): if this contradicts a prior entry that you (via `ltm-recall`) found, name its id.

## Confirm

Show the user the draft. Ask:

- "Record this? Edit anything? (kind, title, body, supersedes)"

Only proceed when user explicitly OKs with a whitelisted go-word (see
IRON-LAW above). "yes / yeah / go / go ahead / 응 / 그래 / 기록해" — clear
assent. "ok / okay / sure / hmm / 오케이 / ㅇㅋ" — ambiguous, ask again
for a clear go-word.

## Rationalizations to refuse

| If you think… | The reality is… |
|---|---|
| "The user clearly meant yes" | If they meant yes they can type yes. Ask. |
| "This is too clear-cut to need confirmation" | The clearest-seeming closures are exactly where unilateral writes happen. Ask. |
| "I'll write it now and let them edit after" | Files in `.claude/ltm/log/` are timestamp-stamped and cumulative. There is no clean edit-after. Ask first. |
| "The user said 'sounds right' — close enough" | "Close enough" is not assent. Ask for a clear go-word. |
| "Asking again will annoy them" | One extra round-trip is cheap. A wrong append is permanent noise in their LTM. Ask. |

## Write

Pre-action announcement (REQUIRED — say this out loud before the tool call):

> "User assent received: `<quote the user's exact go-word>`. Writing
> entry kind=`<kind>`, title=`<title>` to `.claude/ltm/log/` now."

Then call the helper:

```bash
echo "<body>" | python3 ${CLAUDE_PLUGIN_ROOT}/scripts/append-entry.py \
    --kind <kind> \
    --title "<title>" \
    --supersedes "<id1,id2>"   # optional
```

If you cannot fill in the quoted go-word from the user's last message,
STOP and return to Confirm. The announcement is what makes silent
auto-append impossible — do not skip it.

Tell the user the resulting file path.

## Red flags — STOP if you notice

- You are about to call append-entry.py and you cannot quote the user's
  exact assent word from this turn.
- You drafted the entry and the user's most recent message was a
  question or a continuation, not an answer to "Record this?".
- You are tempted to "just stage it" or "write a tentative version".
  There is no tentative version — write = permanent.
- You are skipping the pre-action announcement because "it's obvious".
  That is the rationalization this skill exists to defeat.

## Anti-patterns

- Auto-appending without user OK — never. The skill is *suggestion + execute*, not *automation*.
- Appending mid-exploration when the user is still thinking — wait for closure.
- Padding the body with chat fluff — keep entries dense and dated.
- Inventing a kind that doesn't fit RULES — if RULES has 5 declared kinds and this is a 6th, ask the user whether to add a new kind (and if so, that's a separate `/ltm:declare-rule` invocation).
- Appending the same content twice — if the user re-states a decision in a different way, look for a recent matching entry and either skip (already recorded) or supersede it.
