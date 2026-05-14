#!/usr/bin/env python3
"""Format audit findings into priority-grouped markdown.

Reads analyzer-improve-mode JSON from stdin.
Writes the priority-grouped audit report to stdout.

Usage:
    cat findings.json | python3 format-findings.py
    echo '{...}' | python3 format-findings.py
"""
import json
import sys


PRIORITY_ORDER = [
    ("high", "High Priority"),
    ("medium", "Medium Priority"),
    ("low", "Low Priority"),
]


def main() -> int:
    raw = sys.stdin.read().strip()
    if not raw:
        print("ERROR: no JSON on stdin", file=sys.stderr)
        return 1
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"ERROR: invalid JSON: {e}", file=sys.stderr)
        return 1

    stats = data.get("stats", {}) or {}
    findings = data.get("findings", []) or []

    by_pri: dict[str, list] = {"high": [], "medium": [], "low": []}
    for f in findings:
        p = (f.get("priority") or "low").lower()
        if p not in by_pri:
            p = "low"
        by_pri[p].append(f)

    print("## Audit Results")
    print()
    for key, label in PRIORITY_ORDER:
        items = by_pri[key]
        if not items:
            continue
        print(f"### {label} ({len(items)} items)")
        for f in items:
            files_field = f.get("files_affected") or f.get("file") or []
            if isinstance(files_field, list):
                files = ", ".join(files_field) if files_field else "?"
            else:
                files = str(files_field)
            title = f.get("title") or "(untitled)"
            confidence = f.get("confidence") or "?"
            effort = f.get("effort") or "?"
            suggestion = f.get("suggestion") or ""
            print(f"- `{files}` {title} [{confidence}] effort:{effort} — {suggestion}")
        print()

    files_scanned = stats.get("files_scanned", "?")
    cats_checked = stats.get("categories_checked", "?")
    total = stats.get("total_findings", len(findings))
    cd = stats.get("confidence_distribution") or {}
    high_c = cd.get("high", "?")
    med_c = cd.get("medium", "?")
    low_c = cd.get("low", "?")

    print(
        f"Stats: {files_scanned} files scanned, {cats_checked} categories checked, "
        f"{total} total findings ({high_c} high-confidence, {med_c} medium, {low_c} low)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
