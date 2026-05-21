#!/usr/bin/env python3
"""Find potential duplicates in backlog.md for a candidate entry.

Heuristic: token overlap between candidate description and existing entries.
Returns top N matches above threshold, with their line numbers.

Usage:
    python3 find-duplicates.py "<candidate description>" [target_dir]
"""
import re
import sys
from pathlib import Path


ITEM_RE = re.compile(r"^[-*]\s+(?:\[[ x]\]\s+)?(.+)$")
TOKEN_RE = re.compile(r"[A-Za-z0-9_:\.]+")


def tokens(text: str) -> set[str]:
    return {t.lower() for t in TOKEN_RE.findall(text) if len(t) > 2}


def jaccard(a: set[str], b: set[str]) -> float:
    if not a or not b:
        return 0.0
    return len(a & b) / len(a | b)


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: find-duplicates.py \"<description>\" [target_dir]", file=sys.stderr)
        return 1

    candidate = sys.argv[1]
    target = Path(sys.argv[2]) if len(sys.argv) > 2 else Path(".claude")
    backlog = target / "backlog.md"

    if not backlog.is_file():
        print(f"find-duplicates: {backlog} not found", file=sys.stderr)
        return 1

    cand_tokens = tokens(candidate)
    if not cand_tokens:
        print("find-duplicates: candidate has no comparable tokens (try a longer description)")
        return 0

    matches: list[tuple[float, int, str]] = []
    for lineno, line in enumerate(backlog.read_text(encoding="utf-8").splitlines(), start=1):
        m = ITEM_RE.match(line)
        if not m:
            continue
        body = m.group(1).strip()
        score = jaccard(cand_tokens, tokens(body))
        if score >= 0.20:
            matches.append((score, lineno, body))

    matches.sort(key=lambda x: -x[0])
    top = matches[:5]

    if not top:
        print("find-duplicates: no similar entries (threshold 0.20). Safe to add.")
        return 0

    print(f"find-duplicates: {len(top)} potential match(es) in {backlog}:")
    for score, lineno, body in top:
        print(f"  {score:.2f}  line {lineno}  {body[:120]}")
    print()
    print("Consider whether to merge instead of adding new entry.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
