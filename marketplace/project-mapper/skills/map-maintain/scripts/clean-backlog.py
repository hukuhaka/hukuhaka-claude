#!/usr/bin/env python3
"""Move completed items (`- [x] ...`) from backlog.md to changelog.md.

Scans `.claude/backlog.md` for top-level checked items, removes them,
prepends them to `.claude/changelog.md` under `## Recent`. Empty
sub-sections (### High Priority etc.) are preserved.

Usage:
    python3 clean-backlog.py [target_dir]   (default: .claude)
"""
import re
import sys
from pathlib import Path


CHECKED_RE = re.compile(r"^[-*]\s+\[x\]\s+", re.IGNORECASE)
ITEM_RE = re.compile(r"^[-*]\s+")


def main() -> int:
    target = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".claude")
    backlog_path = target / "backlog.md"
    changelog_path = target / "changelog.md"

    if not backlog_path.is_file():
        print(f"clean-backlog: {backlog_path} not found", file=sys.stderr)
        return 1

    backlog_lines = backlog_path.read_text(encoding="utf-8").splitlines()

    # Walk lines; collect chunks of completed items, leave others.
    kept: list[str] = []
    removed_chunks: list[list[str]] = []
    i = 0
    while i < len(backlog_lines):
        line = backlog_lines[i]
        if CHECKED_RE.match(line):
            chunk = [line]
            i += 1
            # Pull continuation (indented) lines
            while i < len(backlog_lines) and (
                backlog_lines[i].startswith((" ", "\t"))
                or (backlog_lines[i] == "" and i + 1 < len(backlog_lines) and backlog_lines[i + 1].startswith((" ", "\t")))
            ):
                chunk.append(backlog_lines[i])
                i += 1
            removed_chunks.append(chunk)
        else:
            kept.append(line)
            i += 1

    if not removed_chunks:
        print("clean-backlog: no completed (- [x]) items found, nothing to do")
        return 0

    # Write back trimmed backlog (preserve trailing newline)
    backlog_path.write_text("\n".join(kept).rstrip() + "\n", encoding="utf-8")

    # Prepend moved items to changelog under ## Recent
    if not changelog_path.is_file():
        # Create minimal changelog if missing
        changelog_path.write_text("# Changelog\n\n## Recent\n\n## Archive\n", encoding="utf-8")

    cl_text = changelog_path.read_text(encoding="utf-8")
    cl_lines = cl_text.splitlines()
    try:
        recent_idx = next(i for i, l in enumerate(cl_lines) if l.strip() == "## Recent")
    except StopIteration:
        # Append a Recent section at end
        cl_lines.extend(["", "## Recent", ""])
        recent_idx = len(cl_lines) - 2

    # Find first content line after `## Recent` heading (skip blank)
    insert_at = recent_idx + 1
    while insert_at < len(cl_lines) and cl_lines[insert_at] == "":
        insert_at += 1

    # Build moved item lines (uncheck the [x] when moving — they're now logged)
    moved: list[str] = []
    for chunk in removed_chunks:
        for line in chunk:
            line = re.sub(r"^([-*]\s+)\[x\]\s+", r"\1", line, count=1, flags=re.IGNORECASE)
            moved.append(line)

    new_lines = (
        cl_lines[:insert_at]
        + moved
        + ([""] if cl_lines[insert_at:insert_at + 1] != [""] else [])
        + cl_lines[insert_at:]
    )
    changelog_path.write_text("\n".join(new_lines).rstrip() + "\n", encoding="utf-8")

    print(
        f"clean-backlog: moved {len(removed_chunks)} completed item(s) "
        f"from backlog.md → changelog.md (## Recent)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
