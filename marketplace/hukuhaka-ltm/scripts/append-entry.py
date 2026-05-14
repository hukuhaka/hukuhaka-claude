#!/usr/bin/env python3
"""Append a new entry to the LTM log directory (L3 / raw timeline).

Universal guardrails enforced here:
  1. Every entry is timestamped (ISO 8601 UTC + local-day filename).
  2. Every entry has a stable id (filename slug + short hash).
  3. Every entry carries tier: l3 and distilled: false until /ltm:distill
     promotes it into an L2 index card.

Project-declared shape (handled via flags, not hard-coded):
  - --kind     freeform string (e.g., decision, anti-pattern, finding,
                rule-evolution, harness-version-changed, model-version-changed)
  - --slug     short kebab-case identifier (auto-generated from --title if
                omitted)
  - --title    one-line summary (becomes H1 of body if no stdin)
  - --supersedes  comma-separated list of entry ids this one replaces
  - --target-dir  defaults to .claude/ltm
  - --autonomous  marks frontmatter autonomous: true (Stop-hook-driven
                  closure-signal append; bypasses the per-turn assent gate
                  declared in ltm-append/SKILL.md — see CLAUDE.md L3 policy)

Body source priority: stdin (if non-empty) > --title-only stub.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import re
import sys
from pathlib import Path


SLUG_RE = re.compile(r"[^a-z0-9]+")


def slugify(text: str, max_len: int = 50) -> str:
    text = text.lower().strip()
    slug = SLUG_RE.sub("-", text).strip("-")
    return slug[:max_len] or "entry"


def make_id(slug: str, ts_iso: str) -> str:
    """Stable short id: slug + 6-char hash of slug+timestamp."""
    h = hashlib.sha256(f"{slug}|{ts_iso}".encode()).hexdigest()[:6]
    return f"{slug}-{h}"


def build_frontmatter(
    *,
    entry_id: str,
    timestamp_iso: str,
    kind: str | None,
    supersedes: list[str],
    autonomous: bool,
) -> str:
    lines = ["---", f"id: {entry_id}", f"timestamp: {timestamp_iso}"]
    if kind:
        lines.append(f"kind: {kind}")
    lines.append("tier: l3")
    lines.append("distilled: false")
    if autonomous:
        lines.append("autonomous: true")
    if supersedes:
        sup_yaml = ", ".join(supersedes)
        lines.append(f"supersedes: [{sup_yaml}]")
    lines.append("---")
    return "\n".join(lines)


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--kind", default=None, help="entry kind (project-declared, freeform)")
    p.add_argument("--title", default=None, help="one-line summary")
    p.add_argument("--slug", default=None, help="short kebab-case id (auto from title if omitted)")
    p.add_argument(
        "--supersedes",
        default="",
        help="comma-separated entry ids this entry supersedes",
    )
    p.add_argument("--target-dir", default=".claude/ltm", help="LTM root directory")
    p.add_argument(
        "--autonomous",
        action="store_true",
        help="mark autonomous: true in frontmatter (Stop-hook closure-signal path)",
    )
    p.add_argument("--dry-run", action="store_true", help="print path + content, don't write")
    args = p.parse_args()

    if not args.title and not args.slug:
        print("append-entry: provide --title or --slug", file=sys.stderr)
        return 1

    slug = args.slug or slugify(args.title)
    now = dt.datetime.now(dt.timezone.utc)
    ts_iso = now.strftime("%Y-%m-%dT%H:%M:%SZ")
    day = now.strftime("%Y-%m-%d")

    entry_id = make_id(slug, ts_iso)
    supersedes = [s.strip() for s in args.supersedes.split(",") if s.strip()]

    body_stdin = ""
    if not sys.stdin.isatty():
        body_stdin = sys.stdin.read().strip()

    body_parts: list[str] = []
    if args.title:
        body_parts.append(f"# {args.title}")
    if body_stdin:
        body_parts.append(body_stdin)
    if not body_parts:
        body_parts.append(f"# {slug}\n\n(no body provided)")
    body = "\n\n".join(body_parts)

    frontmatter = build_frontmatter(
        entry_id=entry_id,
        timestamp_iso=ts_iso,
        kind=args.kind,
        supersedes=supersedes,
        autonomous=args.autonomous,
    )
    full = f"{frontmatter}\n\n{body}\n"

    log_dir = Path(args.target_dir) / "log"
    out_path = log_dir / f"{day}-{slug}.md"

    if args.dry_run:
        print(f"[dry-run] would write: {out_path}")
        print("---")
        print(full)
        return 0

    log_dir.mkdir(parents=True, exist_ok=True)

    # Avoid silent overwrite — if the path already exists (rare slug
    # collision within the same day), append a short disambiguator.
    if out_path.exists():
        out_path = log_dir / f"{day}-{slug}-{entry_id.split('-')[-1]}.md"

    out_path.write_text(full, encoding="utf-8")
    print(str(out_path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
