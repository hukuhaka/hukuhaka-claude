#!/usr/bin/env python3
"""
changed_dirs.py — incremental scatter target selection for map-sync Step 1.

Reads .claude/scan.md (scatter manifest) and .claude/.map-sync-state
(last synced commit), then computes which scatter directories need their
CLAUDE.md regenerated based on what changed since the last sync.

No LLM, no agents. Pure git + path arithmetic.

Output: one scatter directory path per line (relative to root, trailing
slash) to stdout. map-sync Step 1 iterates exactly these rows.

Mapping (2-tier; targets are always scan.md scatter rows, never re-classified):
    R =  U  nearest_scatter_ancestor(f)            # Tier 1: own ## Files
       f in changed
       U  U  { p, nearest_scatter_ancestor(p) }    # Tier 2: new dir + parent ## See Also
         p in placeholder_only_rows

    changed = git diff --name-only <last_synced_commit>   (committed + tracked uncommitted + deletes)
            U git ls-files --others --exclude-standard     (untracked new files)

Full-sync (emit ALL scatter rows) when:
    - --full flag
    - no state file / unreadable / no last_synced_commit
    - last_synced_commit invalid (history rewrite)
    - not a git repo / no HEAD yet (mirrors scan.py's os.walk fallback path)

Usage:
    python3 changed_dirs.py [project_root] [--full]   (default root: cwd)
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path


STATE_FILE = ".map-sync-state"
PLACEHOLDER_MARKER = "## Files"  # filled scatter docs always have this; placeholders never do


# ─── scan.md parsing ─────────────────────────────────────────────────

def parse_scatter_rows(scan_md: Path) -> list[str]:
    """Return scatter directory paths (relative, no trailing slash) from
    scan.md. Reads both the script-generated and user-overrides sections;
    any table row with decision == 'scatter' counts (includes OVERRIDE)."""
    rows: list[str] = []
    for line in scan_md.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if len(cells) < 3:
            continue
        path, _rule, decision = cells[0], cells[1], cells[2]
        if decision != "scatter":
            continue
        if path in ("path", "---") or set(path) <= {"-"}:  # header / separator
            continue
        rows.append(path.rstrip("/"))
    # dedup, stable order
    seen: set[str] = set()
    out: list[str] = []
    for r in rows:
        if r not in seen:
            seen.add(r)
            out.append(r)
    return out


# ─── git helpers ─────────────────────────────────────────────────────

def _git(root: Path, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git", "-C", str(root), *args],
        capture_output=True, text=True, timeout=30,
    )


def head_exists(root: Path) -> bool:
    """True only if root is a git repo with at least one commit."""
    try:
        return _git(root, "rev-parse", "--verify", "HEAD").returncode == 0
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


def commit_valid(root: Path, sha: str) -> bool:
    try:
        return _git(root, "cat-file", "-e", f"{sha}^{{commit}}").returncode == 0
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


def changed_files(root: Path, since: str) -> list[str]:
    """Files changed since <since> (worktree vs commit: committed + staged +
    unstaged + deletes) unioned with untracked-not-ignored new files."""
    files: set[str] = set()
    diff = _git(root, "diff", "--name-only", since)
    if diff.returncode == 0:
        files.update(l for l in diff.stdout.splitlines() if l.strip())
    others = _git(root, "ls-files", "--others", "--exclude-standard")
    if others.returncode == 0:
        files.update(l for l in others.stdout.splitlines() if l.strip())
    return sorted(files)


# ─── state ───────────────────────────────────────────────────────────

def read_last_commit(claude_dir: Path) -> str | None:
    state = claude_dir / STATE_FILE
    if not state.is_file():
        return None
    try:
        data = json.loads(state.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return None
    sha = data.get("last_synced_commit")
    return sha if isinstance(sha, str) and sha else None


# ─── mapping ─────────────────────────────────────────────────────────

def longest_scatter_prefix(dirpath: str, scatter: set[str]) -> str | None:
    """Longest scatter dir d such that dirpath == d or dirpath is under d.
    dirpath is a directory path relative to root (posix, no trailing slash)."""
    best: str | None = None
    for d in scatter:
        if dirpath == d or dirpath.startswith(d + "/"):
            if best is None or len(d) > len(best):
                best = d
    return best


def is_placeholder(root: Path, rel_dir: str) -> bool:
    """A scatter dir is placeholder-only (needs full generation) if its
    CLAUDE.md is missing or has not yet been filled (no '## Files' section)."""
    cm = root / rel_dir / "CLAUDE.md"
    if not cm.is_file():
        return True
    try:
        return PLACEHOLDER_MARKER not in cm.read_text(encoding="utf-8")
    except OSError:
        return True


def compute_targets(root: Path, scatter_rows: list[str], changed: list[str]) -> list[str]:
    scatter = set(scatter_rows)
    targets: set[str] = set()

    # Tier 1: each changed file -> its nearest scatter-row ancestor.
    for f in changed:
        d = os.path.dirname(f)
        owner = longest_scatter_prefix(d, scatter)
        if owner is not None:
            targets.add(owner)

    # Tier 2: each placeholder-only (new) dir -> itself + nearest scatter parent.
    for p in scatter_rows:
        if is_placeholder(root, p):
            targets.add(p)
            parent = longest_scatter_prefix(os.path.dirname(p), scatter)
            if parent is not None:
                targets.add(parent)

    return sorted(targets)


# ─── main ────────────────────────────────────────────────────────────

def emit(rows: list[str]) -> None:
    for r in rows:
        print(r.rstrip("/") + "/")


def main(argv: list[str]) -> int:
    args = [a for a in argv[1:] if a != "--full"]
    full = "--full" in argv[1:]
    root = Path(args[0] if args else os.getcwd()).resolve()
    claude_dir = root / ".claude"
    scan_md = claude_dir / "scan.md"

    if not scan_md.is_file():
        print(f"ERROR: {scan_md} not found. Run /hukuhaka-project-mapper:map-scan first.",
              file=sys.stderr)
        return 1

    scatter_rows = parse_scatter_rows(scan_md)
    if not scatter_rows:
        # No scatter rows at all — nothing to do (map-sync handles messaging).
        return 0

    # Full-sync conditions.
    reason = None
    if full:
        reason = "--full flag"
    elif not head_exists(root):
        reason = "not a git repo / no commit yet"
    else:
        last = read_last_commit(claude_dir)
        if last is None:
            reason = "no .map-sync-state (first sync)"
        elif not commit_valid(root, last):
            reason = "last_synced_commit invalid (history rewrite)"

    if reason is not None:
        print(f"# full-sync: {reason}", file=sys.stderr)
        emit(scatter_rows)
        return 0

    # Incremental path.
    last = read_last_commit(claude_dir)
    changed = changed_files(root, last)  # type: ignore[arg-type]
    targets = compute_targets(root, scatter_rows, changed)
    print(f"# incremental: {len(changed)} changed file(s) -> "
          f"{len(targets)}/{len(scatter_rows)} scatter dir(s)", file=sys.stderr)
    emit(targets)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
