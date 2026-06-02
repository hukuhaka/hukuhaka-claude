#!/usr/bin/env python3
"""
record_sync.py — stamp the last-synced commit after a map-sync run.

Writes .claude/.map-sync-state with the current HEAD so the next run's
changed_dirs.py can compute an incremental scatter set. Called at the end
of the map-sync pipeline (after Step 4). No-op on a non-git project — the
incremental path is git-only, so leaving no state simply keeps full-sync.

Usage:
    python3 record_sync.py [project_root]   (default root: cwd)
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path


STATE_FILE = ".map-sync-state"


def head_sha(root: Path) -> str | None:
    try:
        r = subprocess.run(
            ["git", "-C", str(root), "rev-parse", "--verify", "HEAD"],
            capture_output=True, text=True, timeout=30,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None
    if r.returncode != 0:
        return None
    sha = r.stdout.strip()
    return sha or None


def main(argv: list[str]) -> int:
    root = Path(argv[1] if len(argv) > 1 else os.getcwd()).resolve()
    claude_dir = root / ".claude"
    if not claude_dir.is_dir():
        print(f"record_sync: {claude_dir} does not exist; nothing recorded.", file=sys.stderr)
        return 0

    sha = head_sha(root)
    if sha is None:
        print("record_sync: not a git repo / no HEAD; state not written (stays full-sync).",
              file=sys.stderr)
        return 0

    state = claude_dir / STATE_FILE
    state.write_text(
        json.dumps({"last_synced_commit": sha, "synced_at": datetime.now().isoformat()},
                   indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"record_sync: {state.relative_to(root)} <- {sha[:12]}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
