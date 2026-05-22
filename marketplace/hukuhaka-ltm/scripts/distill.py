#!/usr/bin/env python3
"""LTM distillation utility — deterministic post-step + pinned.md helpers.

v0.4.0 split-of-responsibility:

  - L2 card authoring (`create` / `edit` / `create-merging`) is owned by
    the `writer` subagent which uses Write/Edit directly. The previous
    `apply` / `merge` / `retire` subcommands were removed — the new
    writer authors body content (not just frontmatter fields), so a
    mechanical assembler script no longer fits.
  - L1 pinned.md edits are owned by the `l1-update` subagent which also
    uses Edit/Write directly. `pin scan` / `pin apply` remain available
    here as deterministic helpers if any agent prefers schema-validated
    mutations, but the v0.4.0 default flow uses tool calls.
  - The `reproject` subcommand stays here — it is deterministic file IO
    that should not live in an LLM-driven agent.

Operations:

  reproject
      Walk all L2 cards in .claude/ltm/index/; build the truth map of
      {L3 id -> [card filenames]} from each card's `evidence:` list; sync
      every L3 entry's `distilled-into` field:
        - absent  : entry has never been through reproject (newly captured)
        - []      : scanned, currently no card cites it (intentional
                    keep-in-L3 OR cited-then-card-retired)
        - [paths] : currently cited; e.g. [index/foo.md, index/bar.md]
      Also drops legacy `distilled: true|false` boolean field (one-shot
      migration for entries written by v0.1.x). Idempotent.
      Reports orphan citations to stderr (L2 evidence id with no matching
      L3 file).

  pin scan
      Dump current pinned.md state as JSON:
        {lines: [{text}], bytes: int, cap: 2048}
      `text` is the line content after the leading `- ` (unique within
      Core section). Helper for any agent wanting structured pinned state.

  pin apply --action add --text "<≤140>" [--evidence <l2-slug1,...>]
      Append `- <text>` under `## Core` in pinned.md. Refuses if
      resulting bytes > 2048 (caller must pair with retire). `--evidence`
      is recorded in stdout output for audit; not persisted in file.

  pin apply --action retire --match-text "<exact line content>"
      Remove the unique `- <match-text>` line from Core section. Refuses
      if 0 or ≥2 lines match.

Card frontmatter schema (unchanged):

    topic: <name>
    summary: <one-line>
    context: <one-line, why this rule>
    evidence: [<log-id1>, <log-id2>, ...]
    supersedes: [<older-card-id>, ...]
    last-updated: <ISO date>
    # plus body — authored by the `writer` subagent, NOT auto-rendered

L3 frontmatter schema (v0.2.0+):

    id, timestamp, kind, tier: l3, [autonomous: true], [supersedes: [...]],
    [distilled-into: [index/foo.md, ...]]    # absent / [] / [paths]
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path


def parse_frontmatter(text: str) -> tuple[dict, str]:
    """Return (frontmatter_dict, body). Naive — handles flat YAML only.

    Recognised value shapes: scalar, `[a, b, c]` list (empty -> []).
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


# ---------------------------------------------------------------------------
# reproject
# ---------------------------------------------------------------------------

def _reproject_internal(target_dir: Path) -> dict:
    """Reproject L3 distilled-into from L2 evidence. Return result dict.

    Idempotent. Migrates legacy `distilled: true|false` boolean by dropping
    it whenever the entry is rewritten. Overwrites scalar `distilled-into`
    values (v0.1.x shape) with lists.
    """
    index_dir = find_index_dir(target_dir)
    log_dir = find_log_dir(target_dir)

    # 1. Build the truth table: L3 id -> [card filenames] (with index/ prefix)
    citations: dict[str, list[str]] = defaultdict(list)
    cards_scanned = 0
    if index_dir.is_dir():
        for card_path in sorted(index_dir.glob("*.md")):
            if card_path.name == ".gitkeep":
                continue
            cards_scanned += 1
            fm, _ = parse_frontmatter(card_path.read_text(encoding="utf-8"))
            for eid in (fm.get("evidence") or []):
                citations[eid].append(f"index/{card_path.name}")

    # 2. Sync each L3 entry's distilled-into; collect existing ids for orphan check.
    existing_l3_ids: set[str] = set()
    touched = 0
    entries_scanned = 0
    if log_dir.is_dir():
        for path, fm in iter_log_entries(log_dir):
            entries_scanned += 1
            entry_id = fm.get("id") or re.sub(r"^\d{4}-\d{2}-\d{2}-", "", path.stem)
            existing_l3_ids.add(entry_id)
            new_val = sorted(citations.get(entry_id, []))
            current = fm.get("distilled-into")
            had_legacy_bool = "distilled" in fm

            # Rewrite when: value changed, current isn't a list, or legacy
            # boolean field is present (migration). The isinstance guard
            # catches the v0.1.x scalar -> v0.2.x list schema shift.
            needs_rewrite = (
                current != new_val
                or not isinstance(current, list)
                or had_legacy_bool
            )
            if needs_rewrite:
                # Re-read body for round-trip (iter_log_entries gave fm only).
                _, body = parse_frontmatter(path.read_text(encoding="utf-8", errors="ignore"))
                new_fm = {k: v for k, v in fm.items() if k != "distilled"}
                # Also drop legacy distilled-into scalar pointer to ensure list shape
                if not isinstance(new_fm.get("distilled-into"), list):
                    new_fm.pop("distilled-into", None)
                new_fm["distilled-into"] = new_val
                write_with_frontmatter(path, new_fm, body)
                touched += 1

    # 3. Orphan detection: card cites an L3 id that no longer exists.
    orphans: list[dict] = []
    for cited_id, cards in citations.items():
        if cited_id not in existing_l3_ids:
            for c in cards:
                orphans.append({"card": c, "missing_id": cited_id})

    result = {
        "reprojected": touched,
        "cards_scanned": cards_scanned,
        "entries_scanned": entries_scanned,
    }
    if orphans:
        result["orphans"] = orphans
    return result


def cmd_reproject(target_dir: Path) -> int:
    result = _reproject_internal(target_dir)
    for o in result.get("orphans", []):
        print(
            f"reproject: orphan — card {o['card']} cites missing L3 id {o['missing_id']}",
            file=sys.stderr,
        )
    print(json.dumps(result))
    return 0


# ---------------------------------------------------------------------------
# L1 pin operations (pinned.md) — deterministic helpers
# ---------------------------------------------------------------------------

PIN_CAP_BYTES = 2048
_PIN_CORE_HEADING_RE = re.compile(r"^##\s+Core\b.*$", re.MULTILINE)
_PIN_SECTION_HEADING_RE = re.compile(r"^##\s+\S", re.MULTILINE)


def _find_pinned(target_dir: Path) -> Path:
    return target_dir / "pinned.md"


def _split_pinned(text: str) -> tuple[str, str, str]:
    """Return (preamble, core_body, trailing).

    preamble: from start through the `## Core` heading line + newline.
    core_body: content between the Core heading and the next `## ` heading or EOF.
    trailing: from the next `## ` heading onward (empty if none).

    Raises if no `## Core` heading found.
    """
    m = _PIN_CORE_HEADING_RE.search(text)
    if not m:
        raise ValueError("pinned.md missing `## Core` heading")
    nl = text.find("\n", m.end())
    if nl == -1:
        return text, "", ""
    preamble = text[: nl + 1]
    rest = text[nl + 1:]
    m2 = _PIN_SECTION_HEADING_RE.search(rest)
    if m2 is None:
        return preamble, rest, ""
    return preamble, rest[: m2.start()], rest[m2.start():]


def _core_items(core_body: str) -> list[str]:
    """Return list of item text (without leading `- ` prefix) from core body."""
    return [ln[2:] for ln in core_body.splitlines() if ln.startswith("- ")]


def cmd_pin_scan(target_dir: Path) -> int:
    pinned = _find_pinned(target_dir)
    if not pinned.exists():
        print(json.dumps({"error": "no-pinned-file", "path": str(pinned)}))
        return 1
    text = pinned.read_text()
    try:
        _, core_body, _ = _split_pinned(text)
    except ValueError as e:
        print(json.dumps({"error": str(e)}))
        return 1
    print(json.dumps({
        "lines": [{"text": t} for t in _core_items(core_body)],
        "bytes": len(text.encode("utf-8")),
        "cap": PIN_CAP_BYTES,
    }))
    return 0


def cmd_pin_apply(args, target_dir: Path) -> int:
    pinned = _find_pinned(target_dir)
    if not pinned.exists():
        print(json.dumps({"error": "no-pinned-file", "path": str(pinned)}))
        return 1
    text = pinned.read_text()
    try:
        preamble, core_body, trailing = _split_pinned(text)
    except ValueError as e:
        print(json.dumps({"error": str(e)}))
        return 1

    if args.action == "add":
        new_text = (args.text or "").strip()
        if not new_text:
            print(json.dumps({"error": "empty-text"}))
            return 1
        existing_lines = core_body.splitlines()
        while existing_lines and not existing_lines[-1].strip():
            existing_lines.pop()
        existing_lines.append(f"- {new_text}")
        new_core = "\n".join(existing_lines) + "\n"
        if trailing:
            new_core += "\n"
        new_pinned = preamble + new_core + trailing
        new_bytes = len(new_pinned.encode("utf-8"))
        if new_bytes > PIN_CAP_BYTES:
            print(json.dumps({
                "error": "over-cap",
                "current_bytes": len(text.encode("utf-8")),
                "would_be": new_bytes,
                "cap": PIN_CAP_BYTES,
            }))
            return 1
        pinned.write_text(new_pinned)
        evidence_list = [e.strip() for e in (args.evidence or "").split(",") if e.strip()]
        print(json.dumps({
            "line_added": new_text,
            "evidence": evidence_list,
            "bytes_after": new_bytes,
            "cap": PIN_CAP_BYTES,
        }))
        return 0

    if args.action == "retire":
        match = (args.match_text or "").strip()
        if not match:
            print(json.dumps({"error": "empty-match-text"}))
            return 1
        target_line = f"- {match}"
        body_lines = core_body.splitlines()
        match_count = sum(1 for ln in body_lines if ln == target_line)
        if match_count != 1:
            print(json.dumps({
                "error": "match-ambiguous" if match_count > 1 else "no-match",
                "matches": match_count,
                "target": target_line,
            }))
            return 1
        new_lines = [ln for ln in body_lines if ln != target_line]
        new_core = "\n".join(new_lines)
        if core_body.endswith("\n") and not new_core.endswith("\n"):
            new_core += "\n"
        new_pinned = preamble + new_core + trailing
        new_bytes = len(new_pinned.encode("utf-8"))
        pinned.write_text(new_pinned)
        print(json.dumps({
            "line_removed": match,
            "bytes_after": new_bytes,
        }))
        return 0

    print(json.dumps({"error": "unknown-action", "action": args.action}))
    return 1


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

def main() -> int:
    p = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    p.add_argument("--target-dir", default=".claude/ltm", help="LTM root directory")
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser(
        "reproject",
        help="sync L3 distilled-into from L2 evidence (idempotent, migration-safe)",
    )

    pin_p = sub.add_parser("pin", help="L1 pinned.md operations")
    pin_sub = pin_p.add_subparsers(dest="pin_cmd", required=True)
    pin_sub.add_parser("scan", help="dump current pinned.md state as JSON")
    pin_apply_p = pin_sub.add_parser("apply", help="add or retire a pinned line")
    pin_apply_p.add_argument("--action", required=True, choices=["add", "retire"])
    pin_apply_p.add_argument("--text", default="", help="line text (for add; ≤140 chars)")
    pin_apply_p.add_argument(
        "--evidence",
        default="",
        help="comma-separated L2 topic slugs (audit-only, not persisted)",
    )
    pin_apply_p.add_argument(
        "--match-text",
        default="",
        dest="match_text",
        help="exact line text (without leading '- ') to retire",
    )

    args = p.parse_args()
    target = Path(args.target_dir)

    if args.cmd == "reproject":
        return cmd_reproject(target)
    if args.cmd == "pin":
        if args.pin_cmd == "scan":
            return cmd_pin_scan(target)
        if args.pin_cmd == "apply":
            return cmd_pin_apply(args, target)
    return 1


if __name__ == "__main__":
    sys.exit(main())
