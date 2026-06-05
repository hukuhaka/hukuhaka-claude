#!/usr/bin/env python3
"""
sync_cost.py — PostToolUse hook: report wall + token usage when a map-sync
pipeline completes.

Fires on every Bash PostToolUse; exits silently unless the command was the
pipeline's terminal step (record-sync). Then it slices the session
transcript from the most recent preflight.sh invocation (pipeline start)
to the end, sums token usage across assistant messages in that window
(main loop + any subagent events present in the file), and emits a
user-visible systemMessage.

Tokens are exact (summed from per-message usage). USD is deliberately NOT
reported — interactive transcripts carry no total_cost_usd and a hardcoded
price table would rot.

Input:  hook JSON on stdin ({tool_name, tool_input, transcript_path, ...})
Output: {"systemMessage": "..."} on stdout, or nothing.
"""
from __future__ import annotations

import json
import sys
from datetime import datetime
from pathlib import Path


def parse_ts(s: str):
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except (ValueError, AttributeError):
        return None


def main() -> int:
    try:
        hook = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0

    if hook.get("tool_name") != "Bash":
        return 0
    command = (hook.get("tool_input") or {}).get("command", "")
    if "record-sync" not in command:
        return 0

    transcript = hook.get("transcript_path", "")
    if not transcript or not Path(transcript).is_file():
        return 0

    # Single pass: remember where the LAST preflight Bash call sits, then sum
    # usage from that line onward (= this sync run, not earlier session work).
    events: list[dict] = []
    start_idx = 0
    with open(transcript, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            events.append(obj)
            msg = obj.get("message") or {}
            for block in (msg.get("content") or []):
                if not isinstance(block, dict) or block.get("type") != "tool_use":
                    continue
                if block.get("name") == "Bash" and "preflight" in str(
                        (block.get("input") or {}).get("command", "")):
                    start_idx = len(events) - 1

    window = events[start_idx:]
    if not window:
        return 0

    usage = {"input_tokens": 0, "output_tokens": 0,
             "cache_creation_input_tokens": 0, "cache_read_input_tokens": 0}
    t_first = t_last = None
    for obj in window:
        ts = parse_ts(obj.get("timestamp", ""))
        if ts:
            t_first = t_first or ts
            t_last = ts
        u = (obj.get("message") or {}).get("usage") or obj.get("usage") or {}
        for k in usage:
            v = u.get(k)
            if isinstance(v, int):
                usage[k] += v

    wall = f"{(t_last - t_first).total_seconds():.0f}s" if t_first and t_last else "n/a"
    total = sum(usage.values())
    out = usage["output_tokens"]
    cache = usage["cache_creation_input_tokens"] + usage["cache_read_input_tokens"]
    print(json.dumps({"systemMessage":
        f"map-sync cost: wall {wall} | tokens {total:,} total "
        f"(out {out:,}, cache {cache:,}) — exact tokens, main-transcript scope"}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
