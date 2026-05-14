#!/usr/bin/env python3
"""Compact .claude/changelog.md: keep Recent <= N items, move older to Archive.

Reads `.claude/changelog.md`, locates `## Recent` and `## Archive` sections,
keeps the top N entries (default 10) under Recent, prepends the rest to
Archive. Other content preserved as-is.

Usage:
    python3 compact-changelog.py [target_dir] [--keep N]   (defaults: .claude, N=10)
"""
import argparse
import re
import sys
from pathlib import Path


HEADER_RE = re.compile(r"^##\s+(.+?)\s*$")
ITEM_RE = re.compile(r"^[-*]\s+")


def split_sections(text: str) -> tuple[list[str], dict[str, list[str]]]:
    """Return (preamble lines, dict of section_name -> body lines)."""
    lines = text.splitlines()
    preamble: list[str] = []
    sections: dict[str, list[str]] = {}
    current: str | None = None
    for line in lines:
        m = HEADER_RE.match(line)
        if m:
            current = m.group(1).strip()
            sections[current] = []
        elif current is None:
            preamble.append(line)
        else:
            sections[current].append(line)
    return preamble, sections


def extract_entries(body: list[str]) -> tuple[list[str], list[str], list[str]]:
    """Split body into (leading non-item lines, entries, trailing non-item lines).

    An entry starts with `- ` or `* ` (top-level list item). Continuation
    lines (indented) belong to the preceding entry.
    """
    leading: list[str] = []
    entries: list[list[str]] = []
    trailing: list[str] = []
    state = "leading"
    for line in body:
        if ITEM_RE.match(line):
            entries.append([line])
            state = "entries"
        elif state == "leading":
            leading.append(line)
        elif state == "entries":
            if line.startswith((" ", "\t")) or line == "":
                if entries and (line.startswith((" ", "\t")) or (line == "" and len(entries[-1]) == 1 and entries[-1][0].strip() != "")):
                    entries[-1].append(line)
                else:
                    trailing.append(line)
                    state = "trailing"
            else:
                trailing.append(line)
                state = "trailing"
        else:
            trailing.append(line)
    flat_entries = [l for e in entries for l in e]
    return leading, flat_entries, trailing


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("target_dir", nargs="?", default=".claude")
    parser.add_argument("--keep", type=int, default=10)
    args = parser.parse_args()

    path = Path(args.target_dir) / "changelog.md"
    if not path.is_file():
        print(f"compact-changelog: {path} not found", file=sys.stderr)
        return 1

    text = path.read_text(encoding="utf-8")
    preamble, sections = split_sections(text)

    if "Recent" not in sections:
        print("compact-changelog: no '## Recent' section found, nothing to do")
        return 0

    recent_body = sections["Recent"]
    archive_body = sections.get("Archive", [])

    # Re-parse Recent into entries
    recent_lead, recent_items_flat, recent_trail = extract_entries(recent_body)

    # Group flat entry lines back into entry chunks
    chunks: list[list[str]] = []
    for line in recent_items_flat:
        if ITEM_RE.match(line):
            chunks.append([line])
        else:
            if chunks:
                chunks[-1].append(line)
    keep = chunks[: args.keep]
    move = chunks[args.keep :]

    if not move:
        print(f"compact-changelog: Recent has {len(chunks)} item(s), keep limit {args.keep}, nothing to move")
        return 0

    # Rebuild Recent body
    new_recent: list[str] = []
    new_recent.extend(recent_lead)
    for c in keep:
        new_recent.extend(c)
    new_recent.extend(recent_trail)

    # Rebuild Archive body — prepend moved entries
    arch_lead, arch_items_flat, arch_trail = extract_entries(archive_body)
    arch_chunks: list[list[str]] = []
    for line in arch_items_flat:
        if ITEM_RE.match(line):
            arch_chunks.append([line])
        else:
            if arch_chunks:
                arch_chunks[-1].append(line)
    new_archive: list[str] = []
    new_archive.extend(arch_lead)
    for c in move:
        new_archive.extend(c)
    for c in arch_chunks:
        new_archive.extend(c)
    new_archive.extend(arch_trail)

    sections["Recent"] = new_recent
    sections["Archive"] = new_archive

    # Reassemble document
    out: list[str] = list(preamble)
    for name, body in sections.items():
        out.append(f"## {name}")
        out.extend(body)
    final = "\n".join(out).rstrip() + "\n"
    path.write_text(final, encoding="utf-8")

    print(
        f"compact-changelog: kept {len(keep)} in Recent, moved {len(move)} to Archive"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
