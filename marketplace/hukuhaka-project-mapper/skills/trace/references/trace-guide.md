# Trace Guide

Type-specific methodology and .claude/ document integration for the trace skill.

## Type Detection Heuristics

User input signals mapped to trace type:

- **error**: "crash", "exception", "TypeError", "null", "undefined is not", stack trace pasted, error message quoted
- **data-flow**: "wrong value", "missing field", "stale", "not updated", "shows old data", "transform"
- **dependency**: "what uses", "impact of changing", "who calls", "references to", "safe to remove"
- **regression**: "was working", "broke after", "since update", "worked yesterday", "after merge"

If multiple signals present, prefer the dominant category. If truly ambiguous, ask user.

## Type: error

**Anchor strategy**: Grep the error message keyword or exception type. If stack trace provided, start from the deepest application frame (skip framework/library frames).

**Trace direction**: Backward (caller chain). Walk up from crash site to find what passed the bad value.

**Common signals**:
- Unexpected null/undefined — trace where the value was supposed to be set
- Type mismatch — trace the producer of the wrong-typed value
- Missing import/module — check recent file moves or renames

**Convergence**: Found when you identify the line that produces the bad input to the crash site.

## Type: data-flow

**Anchor strategy**: Grep or Read the symbol definition where data originates or where wrong value is observed.

**Trace direction**: Forward (producer to consumer) or backward (consumer to producer), depending on which end the user reports.

**Common signals**:
- Missing transform — data passes through without expected conversion
- Stale cache — value read from cache, not from source
- Shadowed variable — local overwrites expected outer value
- Async timing — value read before write completes

**Convergence**: Found when you identify the step where data stops matching expectations.

## Type: dependency

**Anchor strategy**: Grep all references to the target symbol across the codebase.

**Trace direction**: Fan-out. Map the full impact surface.

**Output**: List of all dependents grouped by type (direct call, import, type reference, config).

**Common signals**:
- Unused export — no references found (safe to remove)
- Hidden coupling — reference via string, config, or reflection (check non-code files)
- Circular dependency — A uses B uses A (note cycle in report)

**Convergence**: Complete when all reference paths have been followed one level deep.

## Type: regression

**Anchor strategy**: `git log --oneline -20` to find suspect commits, then `git diff <range>` on the likely change.

**Trace direction**: Diff-driven. Focus on changed lines and their downstream effects.

**Common signals**:
- Changed function signature — callers still pass old args
- Removed null check — downstream now receives unexpected values
- Reordered operations — timing-dependent code breaks
- Config change — environment or build config modified

**Convergence**: Found when a specific commit's change explains the observed regression.

## Using .claude/ Documents

Each .claude/ document provides a different lens for trace analysis:

**map.md** — Expected code structure and data flow. Compare the trace chain against map.md's documented flow. Any deviation is a potential divergence point.

**design.md** — Intended architecture patterns and conventions. If traced code violates a pattern documented in design.md (e.g., skips a middleware layer, calls DB directly instead of through repository), flag it as a potential root cause.

**spec.md** — Interface contracts and invariants. Any traced value that violates a spec.md contract is a strong divergence marker. Check function signatures, naming conventions, and defined boundaries.

**backlog.md** — Known issues and planned work. If the trace leads to a known backlog item, note it in the report. Avoid re-investigating already-documented problems.
