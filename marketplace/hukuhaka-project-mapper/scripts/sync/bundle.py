#!/usr/bin/env python3
"""
bundle.py — deterministic context bundle assembler for map-sync Step 2b.

Assembles the single context bundle injected into the describe and synth
agents. Replaces the analyzer's free Read/Grep/Glob exploration: everything
the agents may see is decided here, by construction.

Bundle layout (most-stable content first, so the prompt prefix is
cache-friendly; the per-agent mode line is appended by the orchestrator at
the very end):

    ===== SKELETON =====            .claude/.sync/skeleton.json (from skeleton.py)
    ===== SCATTERED CLAUDE.md ===== every scan.md scatter row's CLAUDE.md, path-sorted
    ===== EXISTING DOCS =====       current .claude/map.md + design.md

No size limit — the byte/approx-token size is reported to stderr for cost
visibility only.

Usage:
    python3 bundle.py [project_root]   -> .claude/.sync/bundle.md
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

from changed_dirs import parse_scatter_rows


def read_or_none(path: Path) -> str | None:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None


def main(argv: list[str]) -> int:
    root = Path(argv[1] if len(argv) > 1 else os.getcwd()).resolve()
    claude_dir = root / ".claude"
    skeleton_path = claude_dir / ".sync" / "skeleton.json"
    scan_md = claude_dir / "scan.md"

    if not skeleton_path.is_file():
        print(f"ERROR: {skeleton_path} not found. Run skeleton.py first (Step 2a).",
              file=sys.stderr)
        return 1

    sections: list[str] = []

    sections.append("===== SKELETON =====")
    sections.append((read_or_none(skeleton_path) or "").rstrip())

    sections.append("\n===== SCATTERED CLAUDE.md =====")
    n_scatter = 0
    if scan_md.is_file():
        for rel in sorted(parse_scatter_rows(scan_md)):
            cm = root / rel / "CLAUDE.md"
            text = read_or_none(cm)
            if text is None:
                sections.append(f"\n--- {rel}/CLAUDE.md (missing) ---")
                continue
            sections.append(f"\n--- {rel}/CLAUDE.md ---")
            sections.append(text.rstrip())
            n_scatter += 1
    else:
        sections.append("(no .claude/scan.md — no scattered CLAUDE.md available)")

    sections.append("\n===== EXISTING DOCS =====")
    for name in ("map.md", "design.md"):
        text = read_or_none(claude_dir / name)
        sections.append(f"\n--- .claude/{name} ---")
        sections.append(text.rstrip() if text else "(absent or empty)")

    bundle = "\n".join(sections) + "\n"
    out_path = claude_dir / ".sync" / "bundle.md"
    out_path.write_text(bundle, encoding="utf-8")

    size = len(bundle.encode("utf-8"))
    print(f"# bundle: {size} bytes (~{size // 4} tokens), "
          f"{n_scatter} scattered CLAUDE.md -> {out_path.relative_to(root)}",
          file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
