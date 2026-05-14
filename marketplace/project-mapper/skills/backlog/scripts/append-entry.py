#!/usr/bin/env python3
"""Append an entry to backlog.md under ## Planned > ### {Priority} Priority.

Reads backlog.md, locates the priority sub-section (creating it if absent),
appends the entry as a new top-level item. Idempotent — won't add duplicate
exact text under the same section.

Usage:
    python3 append-entry.py --priority high --entry '`file:symbol`: description' [target_dir]

Optional:
    --context "Related: file1, file2"    (sub-bullet)
    --behavior "current 1-line summary"  (sub-bullet)
"""
import argparse
import re
import sys
from pathlib import Path


PRIORITY_LABELS = {
    "high": "### High Priority",
    "medium": "### Medium Priority",
    "low": "### Low Priority",
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--priority", required=True, choices=["high", "medium", "low"])
    parser.add_argument("--entry", required=True, help="Main entry text (without leading '- [ ] ')")
    parser.add_argument("--context", default=None, help="Optional 'Related: ...' sub-bullet")
    parser.add_argument("--behavior", default=None, help="Optional 'Current: ...' sub-bullet")
    parser.add_argument("target_dir", nargs="?", default=".claude")
    args = parser.parse_args()

    backlog = Path(args.target_dir) / "backlog.md"
    if not backlog.is_file():
        print(f"append-entry: {backlog} not found", file=sys.stderr)
        return 1

    label = PRIORITY_LABELS[args.priority]
    text = backlog.read_text(encoding="utf-8")
    lines = text.splitlines()

    # Locate ## Planned
    try:
        planned_idx = next(
            i for i, l in enumerate(lines) if l.strip() == "## Planned"
        )
    except StopIteration:
        print("append-entry: '## Planned' section not found in backlog.md", file=sys.stderr)
        return 1

    # Find boundary of ## Planned section (next ## heading or EOF)
    end_idx = len(lines)
    for i in range(planned_idx + 1, len(lines)):
        if re.match(r"^##\s+", lines[i]):
            end_idx = i
            break

    # Find the target priority sub-section within ## Planned
    pri_idx = None
    for i in range(planned_idx + 1, end_idx):
        if lines[i].strip() == label:
            pri_idx = i
            break

    new_entry_lines = [f"- [ ] {args.entry}"]
    if args.context:
        new_entry_lines.append(f"  - {args.context}")
    if args.behavior:
        new_entry_lines.append(f"  - {args.behavior}")

    if pri_idx is None:
        # Sub-section missing — create at end of ## Planned
        insert_at = end_idx
        block = ["", label, ""] + new_entry_lines
        new_lines = lines[:insert_at] + block + lines[insert_at:]
    else:
        # Find end of this priority sub-section (next ### or ## or EOF)
        sub_end = end_idx
        for i in range(pri_idx + 1, end_idx):
            if re.match(r"^(##|###)\s+", lines[i]):
                sub_end = i
                break

        # Idempotency check — don't add identical first-line entry already present
        existing = "\n".join(lines[pri_idx + 1 : sub_end])
        if new_entry_lines[0] in existing.splitlines():
            print(f"append-entry: identical entry already in {label}, skipping")
            return 0

        # Insert at end of sub-section, before any trailing blank lines
        insert_at = sub_end
        while insert_at > pri_idx + 1 and lines[insert_at - 1].strip() == "":
            insert_at -= 1
        new_lines = lines[:insert_at] + new_entry_lines + lines[insert_at:]

    backlog.write_text("\n".join(new_lines).rstrip() + "\n", encoding="utf-8")
    print(f"append-entry: added to {label} → {backlog}")
    print(f"  Entry: {args.entry}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
