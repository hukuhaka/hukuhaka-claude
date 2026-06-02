#!/usr/bin/env python3
"""
scan.py — deterministic structural decision for map-scan skill.

Walks the project tree, classifies each directory by 6 rules, writes
.claude/scan.md as a single audit table, and touches placeholder
CLAUDE.md files at every scatter row.

No LLM. No agents. Pure file-existence + count checks.

Usage:
    python3 scan.py [project_root]   (default: cwd)
"""
from __future__ import annotations

import os
import subprocess
import sys
from datetime import date
from pathlib import Path


# ─── Configuration ───────────────────────────────────────────────────

DENY = {
    # Build / cache / dependency dirs
    "node_modules", ".venv", "venv", "__pycache__", "target", "dist",
    "build", ".gradle", ".next", ".idea", ".vscode", ".pytest_cache",
    ".mypy_cache", ".ruff_cache", "Pods", "Carthage", "bower_components",
    # Vendored / external
    "vendor", "third_party", "external",
    # Assets / non-code
    "assets", "static", "public", "fixtures", "icons", "fonts", "images",
    "res", "migrations",
}

MARKERS = [
    "package.json", "pyproject.toml", "setup.py", "Cargo.toml",
    "go.mod", "pubspec.yaml", "build.gradle", "build.gradle.kts",
    "AndroidManifest.xml",
]

SOURCE_EXT = {
    ".py", ".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs",
    ".kt", ".kts", ".swift", ".m", ".mm",
    ".go", ".rs", ".dart",
    ".cpp", ".cc", ".cxx", ".c", ".h", ".hpp",
    ".java", ".scala", ".rb", ".php",
}


# ─── Tree enumeration ────────────────────────────────────────────────

def find_deny_dirs(root: Path) -> list[Path]:
    """Find DENY-named directories that exist on disk. Includes top-level
    deny dirs only (no descent into deny dirs to find nested ones)."""
    found: list[Path] = []
    for dirpath, dirnames, _ in os.walk(root):
        p = Path(dirpath)
        for deny_name in [d for d in dirnames if d in DENY]:
            found.append(p / deny_name)
        # Prune deny + hidden from further walk
        dirnames[:] = [d for d in dirnames if d not in DENY and not d.startswith(".")]
    return found


def list_tracked_dirs(root: Path) -> list[Path] | None:
    """Use git ls-files to get all tracked + untracked-not-ignored files,
    then derive the set of directories. Returns None if not a git repo.
    Deny dirs are added separately via find_deny_dirs."""
    try:
        result = subprocess.run(
            ["git", "-C", str(root), "ls-files", "-co", "--exclude-standard"],
            capture_output=True, text=True, check=True, timeout=30,
        )
    except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
        return None

    dirs: set[Path] = set()
    for line in result.stdout.splitlines():
        if not line.strip():
            continue
        p = root / line
        for parent in p.parents:
            if parent == root:
                break
            if any(part in DENY for part in parent.relative_to(root).parts):
                continue
            dirs.add(parent)
    # Surface deny dirs as audit rows (they exist but were pruned from walk)
    dirs.update(find_deny_dirs(root))
    return sorted(dirs)


def walk_dirs(root: Path) -> list[Path]:
    """Fallback enumeration via os.walk. Includes deny dirs as 1-level
    entries (for audit visibility) but does not descend into them."""
    dirs: list[Path] = []
    for dirpath, dirnames, _filenames in os.walk(root):
        p = Path(dirpath)
        for deny_name in [d for d in dirnames if d in DENY]:
            dirs.append(p / deny_name)
        kept = [d for d in dirnames if d not in DENY and not d.startswith(".")]
        dirnames[:] = kept
        if p != root:
            dirs.append(p)
    return sorted(dirs)


# ─── Per-directory facts ─────────────────────────────────────────────

def own_source_count(d: Path) -> int:
    n = 0
    try:
        for entry in d.iterdir():
            if entry.is_file() and entry.suffix.lower() in SOURCE_EXT:
                n += 1
    except (PermissionError, OSError):
        pass
    return n


def has_source_anywhere(d: Path) -> bool:
    """True if any descendant of d (recursively) is a source file,
    pruning deny-listed dirs."""
    for dirpath, dirnames, filenames in os.walk(d):
        dirnames[:] = [x for x in dirnames if x not in DENY and not x.startswith(".")]
        for f in filenames:
            if Path(f).suffix.lower() in SOURCE_EXT:
                return True
    return False


def source_bearing_children(d: Path) -> list[Path]:
    children: list[Path] = []
    try:
        for entry in d.iterdir():
            if not entry.is_dir():
                continue
            if entry.name in DENY or entry.name.startswith("."):
                continue
            if has_source_anywhere(entry):
                children.append(entry)
    except (PermissionError, OSError):
        pass
    return children


def found_marker(d: Path) -> str | None:
    for m in MARKERS:
        if (d / m).exists():
            return m
    return None


# ─── Decision tree ───────────────────────────────────────────────────

def classify(d: Path) -> tuple[str, str, str]:
    """Return (rule, decision, note)."""
    if d.name in DENY:
        return ("DENY", "skip", f"deny-list: {d.name}")

    marker = found_marker(d)
    if marker:
        return ("MARKER", "scatter", f"workspace marker: {marker}")

    own = own_source_count(d)
    children = source_bearing_children(d)

    if own == 0 and len(children) == 1:
        return ("PASSTHROUGH", "passthrough", "single-child chain")
    if len(children) >= 2 or (own >= 1 and len(children) >= 1):
        suffix = "subdir" if len(children) == 1 else "subdirs"
        return ("BRANCH", "scatter", f"{len(children)} {suffix}")
    if own >= 2 and len(children) == 0:
        suffix = "source file" if own == 1 else "source files"
        return ("LEAF", "scatter", f"{own} {suffix}")
    return ("TRIVIAL", "skip", "trivial")


# ─── Output ──────────────────────────────────────────────────────────

PLACEHOLDER = "# {name}\n\n<!-- managed by map-sync -->\n"


def render_scan_md(rows: list[dict], root: Path, source: str) -> str:
    today = date.today().isoformat()
    lines = [
        "# Scan Manifest",
        "",
        f"> Auto-generated by /hukuhaka-project-mapper:map-scan on {today}.",
        f"> Enumeration source: {source}.",
        "> Source of truth for which directories get a CLAUDE.md.",
        "> map-sync only updates files listed here with `decision == scatter`.",
        "> Hand-edit below the `user-overrides` marker; never edit script-generated rows.",
        "",
        "## Script-generated",
        "",
        "| path | rule | decision | note |",
        "| --- | --- | --- | --- |",
    ]
    # Per (alpha) decision: only scatter and DENY-skip rows in the table.
    # PASSTHROUGH and TRIVIAL are omitted.
    for row in rows:
        if row["decision"] == "scatter" or row["rule"] == "DENY":
            path = row["path"].relative_to(root).as_posix() + "/"
            lines.append(
                f"| {path} | {row['rule']} | {row['decision']} | {row['note']} |"
            )
    lines.extend([
        "",
        "<!-- user-overrides below -->",
        "",
    ])
    return "\n".join(lines)


def touch_placeholder(d: Path) -> bool:
    """Create empty placeholder CLAUDE.md if missing. Return True if created."""
    target = d / "CLAUDE.md"
    if target.exists():
        return False
    target.write_text(PLACEHOLDER.format(name=d.name), encoding="utf-8")
    return True


# ─── Main ────────────────────────────────────────────────────────────

def main(argv: list[str]) -> int:
    root = Path(argv[1] if len(argv) > 1 else os.getcwd()).resolve()
    claude_dir = root / ".claude"

    if not claude_dir.is_dir():
        print(f"ERROR: {claude_dir}/ does not exist. Run /hukuhaka-project-mapper:map-init first.", file=sys.stderr)
        return 1

    tracked = list_tracked_dirs(root)
    if tracked is not None:
        dirs = tracked
        source = "git ls-files -co --exclude-standard"
    else:
        dirs = walk_dirs(root)
        source = "os.walk (non-git fallback)"

    if not dirs:
        print(f"ERROR: no directories found under {root}. Project empty or all denied?", file=sys.stderr)
        return 1

    rows = []
    for d in dirs:
        rule, decision, note = classify(d)
        rows.append({"path": d, "rule": rule, "decision": decision, "note": note})

    scan_md = claude_dir / "scan.md"
    scan_md.write_text(render_scan_md(rows, root, source), encoding="utf-8")

    created = 0
    skipped = 0
    for row in rows:
        if row["decision"] == "scatter":
            if touch_placeholder(row["path"]):
                created += 1
            else:
                skipped += 1

    counts = {
        "scatter": sum(1 for r in rows if r["decision"] == "scatter"),
        "skip": sum(1 for r in rows if r["decision"] == "skip"),
        "passthrough": sum(1 for r in rows if r["decision"] == "passthrough"),
    }

    print(f"Scan complete — wrote {scan_md.relative_to(root)}.")
    print(f"  Enumeration source: {source}")
    print(f"  Directories evaluated: {len(rows)}")
    print(f"  Decisions: scatter={counts['scatter']}, skip={counts['skip']}, passthrough={counts['passthrough']}")
    print(f"  Placeholder CLAUDE.md: {created} created, {skipped} already existed")
    print("")
    print("Run /hukuhaka-project-mapper:map-sync to fill the placeholders with content.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
