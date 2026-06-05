#!/usr/bin/env python3
"""
merge.py — skeleton-wins merge to the analyzer 9-field JSON (map-sync Step 2 merge).

Combines the deterministic skeleton with the describe/synth agent outputs
into the exact JSON contract the writer agent consumes. The skeleton is
authoritative for STRUCTURE (stats, stack, todos, names, paths, depends_on);
the LLM outputs contribute only prose (descriptions, data_flow, patterns,
decisions) and the entry-point include/prune verdicts.

Structural validation (anti-hallucination, by construction):
    - any describe path not present in the skeleton candidates is DROPPED
    - entry_points = skeleton entry candidates that describe marked include=true
      (candidates without a verdict default to include=false; pruned candidates
      with symbols are demoted to components so they are not silently lost)
    - synth prose referencing node names absent from the skeleton is FLAGGED
      to stderr (kept — prose is not rewritten silently)

Usage:
    python3 merge.py [project_root] < combined.json
      where combined.json = {"describe": {...}, "synth": {...}}
    Output: 9-field JSON on stdout (-> writer prompt). Diagnostics on stderr.
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path


def fail(msg: str) -> int:
    print(f"ERROR: {msg}", file=sys.stderr)
    return 1


def main(argv: list[str]) -> int:
    root = Path(argv[1] if len(argv) > 1 else os.getcwd()).resolve()
    skeleton_path = root / ".claude" / ".sync" / "skeleton.json"
    if not skeleton_path.is_file():
        return fail(f"{skeleton_path} not found. Run skeleton.py first.")

    try:
        skeleton = json.loads(skeleton_path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError) as e:
        return fail(f"unreadable skeleton.json: {e}")

    raw = sys.stdin.read()
    try:
        combined = json.loads(raw)
    except json.JSONDecodeError as e:
        return fail(f"stdin is not valid JSON ({e}). Expected {{\"describe\": ..., \"synth\": ...}}")
    describe = combined.get("describe")
    synth = combined.get("synth")
    if not isinstance(describe, dict) or not isinstance(synth, dict):
        return fail("stdin JSON must contain 'describe' and 'synth' objects")

    cand = skeleton.get("candidates", {})
    cand_entries = {c["path"]: c for c in cand.get("entry_points", [])}
    cand_comps = {c["path"]: c for c in cand.get("components", [])}
    cand_dirs = {d["path"]: d for d in cand.get("directories", [])}

    # describe output -> per-path descriptions + include verdicts
    desc_by_path: dict[str, dict] = {}
    dropped: list[str] = []
    for section in ("entry_points", "components", "directories"):
        for item in describe.get(section, []):
            if not isinstance(item, dict) or "path" not in item:
                continue
            path = item["path"]
            known = path in cand_entries or path in cand_comps or path in cand_dirs
            if not known:
                dropped.append(path)
                continue
            desc_by_path[path] = item

    def node(c: dict, path: str) -> dict:
        d = desc_by_path.get(path, {})
        out = {
            "name": c["name"],
            "path": path,
            "description": str(d.get("description", "") or c.get("skeleton_doc", "")),
        }
        if c.get("depends_on"):
            out["depends_on"] = c["depends_on"]
        return out

    entry_points: list[dict] = []
    components: list[dict] = []
    for path, c in sorted(cand_entries.items()):
        verdict = desc_by_path.get(path, {}).get("include")
        if verdict is True:
            entry_points.append(node(c, path))
        elif c.get("symbols") or c.get("skeleton_doc"):
            components.append(node(c, path))  # pruned candidate -> component
    for path, c in sorted(cand_comps.items()):
        components.append(node(c, path))

    directories = [
        {"path": path, "description": str(desc_by_path.get(path, {}).get("description", "")
                                          or d.get("skeleton_doc", ""))}
        for path, d in sorted(cand_dirs.items())
    ]

    # synth output -> prose fields, with unknown-name flagging
    known_names = {c["name"] for c in list(cand_entries.values()) + list(cand_comps.values())}
    data_flow = str(synth.get("data_flow", ""))
    patterns = [p for p in synth.get("patterns", []) if isinstance(p, dict)]
    decisions = [d for d in synth.get("decisions", []) if isinstance(d, dict)]

    unknown: set[str] = set()
    for token in re.findall(r"[A-Za-z_][A-Za-z0-9_-]{2,}", data_flow):
        if token not in known_names and token.lower() not in (
                "input", "output", "process", "user", "agent", "agents", "the", "and"):
            # only flag tokens that LOOK like node references (snake_case / kebab-case)
            if "_" in token or "-" in token:
                unknown.add(token)

    result = {
        "stats": {
            "files_scanned": skeleton["stats"]["files_scanned"],
            "queries_run": 0,
            "todos_found": skeleton["stats"]["todos_found"],
            "entry_points_found": len(entry_points),
            "components_found": len(components),
        },
        "entry_points": entry_points,
        "data_flow": data_flow,
        "components": components,
        "directories": directories,
        "stack": skeleton.get("stack", []),
        "patterns": patterns,
        "decisions": decisions,
        "todos": skeleton.get("todos", []),
    }

    if dropped:
        print(f"# merge: dropped {len(dropped)} hallucinated path(s): "
              f"{', '.join(sorted(set(dropped))[:5])}", file=sys.stderr)
    if unknown:
        print(f"# merge: data_flow references {len(unknown)} name(s) not in skeleton: "
              f"{', '.join(sorted(unknown)[:5])}", file=sys.stderr)
    print(f"# merge: {len(entry_points)} entry_points, {len(components)} components, "
          f"{len(directories)} directories", file=sys.stderr)

    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
