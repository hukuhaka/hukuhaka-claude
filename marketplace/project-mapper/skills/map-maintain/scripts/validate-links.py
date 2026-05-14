#!/usr/bin/env python3
"""Validate file references in .claude/ markdown docs.

Scans every `.claude/*.md` for inline `[text](path)` links. For relative
paths, checks whether the target exists on disk. Absolute paths and
external URLs (http/https) are skipped.

Usage:
    python3 validate-links.py [target_dir]   (default: .claude)

Exit code:
    0 — all links resolved or no links found
    1 — at least one broken link
"""
import os
import re
import sys
from pathlib import Path


LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")


def main() -> int:
    target = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".claude")
    if not target.is_dir():
        print(f"validate-links: {target} does not exist", file=sys.stderr)
        return 1

    md_files = sorted(target.glob("*.md"))
    checked = 0
    broken: list[tuple[Path, int, str, str]] = []

    for md in md_files:
        text = md.read_text(encoding="utf-8", errors="replace")
        for lineno, line in enumerate(text.splitlines(), start=1):
            for m in LINK_RE.finditer(line):
                label, path = m.group(1), m.group(2).strip()
                if path.startswith(("http://", "https://", "mailto:", "#")):
                    continue
                if path.startswith("/"):
                    continue
                checked += 1
                resolved = (md.parent / path).resolve()
                if not resolved.exists():
                    broken.append((md, lineno, label, path))

    print(f"Validate links: {len(md_files)} doc(s) scanned, {checked} relative link(s) checked")
    if broken:
        print(f"  Broken: {len(broken)}")
        for md, lineno, label, path in broken:
            print(f"    {md}:{lineno}  [{label}]({path})")
        return 1
    else:
        print(f"  Broken: 0")
        return 0


if __name__ == "__main__":
    sys.exit(main())
