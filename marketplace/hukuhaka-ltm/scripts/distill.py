#!/usr/bin/env python3
"""LTM distillation helper — promote raw L3 log entries into L2 knowledge cards.

Operations:

  scan
      Walk .claude/ltm/log/, find entries with `distilled: false` in
      frontmatter, cluster them by slug-token-prefix (1-2 leading tokens
      after stripping common stopwords), and print JSON to stdout. Claude
      reads this and presents proposals to the user.

  apply --topic <name> [--supersedes <card-id>] --evidence <id1,id2,...>
      Read card body from stdin. Either create .claude/ltm/index/<name>.md
      or merge into the existing card (appending to evidence, refreshing
      last-updated). Then mark each evidence log entry's frontmatter
      distilled: true and add a "→ index/<name>.md" pointer.

  undo --topic <name>
      Delete the index card and revert distilled: true → false for every
      log entry currently cited as evidence.

Card schema (frontmatter):

    topic: <name>
    summary: <one-line>
    context: <one-line, why this rule>
    evidence: [<log-id1>, <log-id2>, ...]
    supersedes: [<older-card-id>, ...]
    last-updated: <ISO date>

Design intent: distill is a Claude-orchestrated batch operation, not a
silent automation. This script does the file IO; the slash command
markdown decides what to surface and confirm with the user.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
from pathlib import Path


SLUG_STOPWORDS = {
    "why", "what", "how", "the", "a", "an", "is", "are", "was", "were",
    "to", "of", "in", "on", "for", "with", "from",
}

SLUG_TOKEN_RE = re.compile(r"[a-z0-9]+")


def parse_frontmatter(text: str) -> tuple[dict, str]:
    """Return (frontmatter_dict, body). Naive — handles flat YAML only.

    Recognised value shapes: scalar, `[a, b, c]` list.
    """
    if not text.startswith("---\n"):
        return {}, text
    end = text.find("\n---\n", 4)
    if end == -1:
        return {}, text
    raw = text[4:end]
    body = text[end + 5 :]
    fm: dict = {}
    for line in raw.splitlines():
        line = line.rstrip()
        if not line or ":" not in line:
            continue
        key, _, value = line.partition(":")
        key = key.strip()
        value = value.strip()
        if value.startswith("[") and value.endswith("]"):
            inner = value[1:-1].strip()
            fm[key] = [v.strip() for v in inner.split(",") if v.strip()] if inner else []
        else:
            fm[key] = value
    return fm, body


def write_with_frontmatter(path: Path, fm: dict, body: str) -> None:
    lines = ["---"]
    for k, v in fm.items():
        if isinstance(v, list):
            lines.append(f"{k}: [{', '.join(v)}]")
        else:
            lines.append(f"{k}: {v}")
    lines.append("---")
    path.write_text("\n".join(lines) + "\n\n" + body.lstrip("\n"), encoding="utf-8")


def slug_tokens(slug: str) -> list[str]:
    """Lowercase alphanumeric tokens, stopwords removed, length ≥3 chars."""
    tokens = SLUG_TOKEN_RE.findall(slug.lower())
    return [t for t in tokens if t not in SLUG_STOPWORDS and len(t) >= 3]


def cluster_key(slug: str) -> str:
    """Take first 1-2 meaningful tokens as the topic-cluster key."""
    tokens = slug_tokens(slug)
    if not tokens:
        return "misc"
    if len(tokens) == 1:
        return tokens[0]
    return f"{tokens[0]}-{tokens[1]}"


def find_log_dir(target_dir: Path) -> Path:
    return target_dir / "log"


def find_index_dir(target_dir: Path) -> Path:
    return target_dir / "index"


def iter_log_entries(log_dir: Path):
    if not log_dir.is_dir():
        return
    for path in sorted(log_dir.glob("*.md")):
        text = path.read_text(encoding="utf-8", errors="ignore")
        fm, _ = parse_frontmatter(text)
        yield path, fm


def cmd_scan(target_dir: Path) -> int:
    log_dir = find_log_dir(target_dir)
    clusters: dict[str, dict] = {}
    undistilled_total = 0
    for path, fm in iter_log_entries(log_dir):
        if fm.get("distilled", "false").lower() == "true":
            continue
        undistilled_total += 1
        slug = path.stem  # e.g. 2026-05-04-foo-bar
        # Strip leading date YYYY-MM-DD-
        slug_only = re.sub(r"^\d{4}-\d{2}-\d{2}-", "", slug)
        key = cluster_key(slug_only)
        bucket = clusters.setdefault(
            key, {"topic_suggestion": key, "entries": [], "kinds": set()}
        )
        bucket["entries"].append(
            {
                "id": fm.get("id", slug),
                "path": str(path),
                "kind": fm.get("kind", "unknown"),
                "title": _extract_title(path),
                "timestamp": fm.get("timestamp", ""),
                "autonomous": fm.get("autonomous", "false").lower() == "true",
                "supersedes": fm.get("supersedes", []) if isinstance(fm.get("supersedes"), list) else [],
            }
        )
        bucket["kinds"].add(fm.get("kind", "unknown"))

    # Convert sets to sorted lists for JSON
    out_clusters = []
    for key, bucket in sorted(clusters.items(), key=lambda kv: -len(kv[1]["entries"])):
        out_clusters.append(
            {
                "topic_suggestion": bucket["topic_suggestion"],
                "kinds": sorted(bucket["kinds"]),
                "entry_count": len(bucket["entries"]),
                "entries": bucket["entries"],
            }
        )

    print(
        json.dumps(
            {
                "undistilled_count": undistilled_total,
                "clusters": out_clusters,
            },
            indent=2,
        )
    )
    return 0


def _extract_title(path: Path) -> str:
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return path.stem
    _, body = parse_frontmatter(text)
    for line in body.splitlines():
        line = line.strip()
        if line.startswith("# "):
            return line[2:].strip()
        if line:
            return line[:80]
    return path.stem


def cmd_apply(args, target_dir: Path) -> int:
    topic = args.topic.strip()
    if not topic:
        print("distill: --topic is required", file=sys.stderr)
        return 1
    if not re.match(r"^[a-z0-9][a-z0-9-]*$", topic):
        print(f"distill: --topic must be kebab-case slug, got {topic!r}", file=sys.stderr)
        return 1
    evidence = [e.strip() for e in args.evidence.split(",") if e.strip()]
    if not evidence:
        print("distill: --evidence (comma-separated log ids) required", file=sys.stderr)
        return 1
    supersedes = [s.strip() for s in (args.supersedes or "").split(",") if s.strip()]

    body_stdin = ""
    if not sys.stdin.isatty():
        body_stdin = sys.stdin.read()
    body = body_stdin.strip()
    if not body:
        print("distill: body required on stdin (summary line + optional context)", file=sys.stderr)
        return 1

    # Split body: first non-empty line = summary, rest = context
    lines = [ln for ln in body.splitlines() if ln.strip() or True]
    nonempty = [i for i, ln in enumerate(lines) if ln.strip()]
    if not nonempty:
        print("distill: body has no non-empty lines", file=sys.stderr)
        return 1
    summary_idx = nonempty[0]
    summary = lines[summary_idx].strip()
    context_lines = lines[summary_idx + 1 :]
    context = "\n".join(context_lines).strip()

    index_dir = find_index_dir(target_dir)
    index_dir.mkdir(parents=True, exist_ok=True)
    card_path = index_dir / f"{topic}.md"
    today = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d")

    if card_path.exists():
        existing_fm, existing_body = parse_frontmatter(card_path.read_text(encoding="utf-8"))
        merged_evidence = list(dict.fromkeys((existing_fm.get("evidence") or []) + evidence))
        merged_super = list(dict.fromkeys((existing_fm.get("supersedes") or []) + supersedes))
        prev_summary = existing_fm.get("summary", "") if isinstance(existing_fm.get("summary"), str) else ""
        prev_context = existing_fm.get("context", "") if isinstance(existing_fm.get("context"), str) else ""
        existing_fm["topic"] = topic
        existing_fm["summary"] = summary
        if context:
            existing_fm["context"] = context
        existing_fm["evidence"] = merged_evidence
        if merged_super:
            existing_fm["supersedes"] = merged_super
        existing_fm["last-updated"] = today
        # Preserve user-edited body verbatim. If the existing body still
        # matches the auto-rendered form for the prior summary/context,
        # it was never touched — safe to regenerate. Otherwise the user
        # added prose we must not silently clobber.
        prev_auto = _render_card_body(prev_summary, prev_context)
        if existing_body.strip() == prev_auto.strip():
            body_to_write = _render_card_body(summary, context)
        else:
            body_to_write = existing_body
        write_with_frontmatter(card_path, existing_fm, body_to_write)
    else:
        fm = {
            "topic": topic,
            "summary": summary,
            "evidence": evidence,
            "last-updated": today,
        }
        if context:
            fm["context"] = context
        if supersedes:
            fm["supersedes"] = supersedes
        write_with_frontmatter(card_path, fm, _render_card_body(summary, context))

    # Mark each evidence log entry as distilled. Match on frontmatter id
    # first; fall back to filename-stem (date-prefix stripped) so manually
    # created entries lacking an `id:` field still resolve.
    log_dir = find_log_dir(target_dir)
    marked = 0
    for path, fm in iter_log_entries(log_dir):
        entry_id = fm.get("id")
        if not entry_id:
            entry_id = re.sub(r"^\d{4}-\d{2}-\d{2}-", "", path.stem)
        if entry_id in evidence:
            updated_fm = dict(fm)
            updated_fm["distilled"] = "true"
            updated_fm["distilled-into"] = f"index/{topic}.md"
            _, body_text = parse_frontmatter(path.read_text(encoding="utf-8", errors="ignore"))
            write_with_frontmatter(path, updated_fm, body_text)
            marked += 1

    print(json.dumps({"card": str(card_path), "marked": marked}))
    return 0


def _render_card_body(summary: str, context: str) -> str:
    parts = [f"# {summary}"]
    if context:
        parts.append(context)
    return "\n\n".join(parts) + "\n"


def cmd_undo(args, target_dir: Path) -> int:
    topic = args.topic.strip()
    if not topic:
        print("distill: --topic is required", file=sys.stderr)
        return 1
    index_dir = find_index_dir(target_dir)
    card_path = index_dir / f"{topic}.md"
    if not card_path.exists():
        print(f"distill: no card at {card_path}", file=sys.stderr)
        return 1
    fm, _ = parse_frontmatter(card_path.read_text(encoding="utf-8"))
    evidence = fm.get("evidence") or []
    log_dir = find_log_dir(target_dir)
    reverted = 0
    for path, lfm in iter_log_entries(log_dir):
        entry_id = lfm.get("id")
        if not entry_id:
            entry_id = re.sub(r"^\d{4}-\d{2}-\d{2}-", "", path.stem)
        if entry_id in evidence:
            updated = dict(lfm)
            updated["distilled"] = "false"
            updated.pop("distilled-into", None)
            _, body_text = parse_frontmatter(path.read_text(encoding="utf-8", errors="ignore"))
            write_with_frontmatter(path, updated, body_text)
            reverted += 1
    card_path.unlink()
    print(json.dumps({"reverted": reverted, "card_removed": str(card_path)}))
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--target-dir", default=".claude/ltm", help="LTM root directory")
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("scan", help="list undistilled L3 entries grouped into proposed topics")

    ap = sub.add_parser("apply", help="write/merge an L2 card and mark log entries distilled")
    ap.add_argument("--topic", required=True)
    ap.add_argument("--evidence", required=True, help="comma-separated log entry ids")
    ap.add_argument("--supersedes", default="", help="comma-separated older card ids")

    ud = sub.add_parser("undo", help="delete an L2 card and revert distilled flags")
    ud.add_argument("--topic", required=True)

    args = p.parse_args()
    target = Path(args.target_dir)

    if args.cmd == "scan":
        return cmd_scan(target)
    if args.cmd == "apply":
        return cmd_apply(args, target)
    if args.cmd == "undo":
        return cmd_undo(args, target)
    return 1


if __name__ == "__main__":
    sys.exit(main())
