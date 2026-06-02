#!/usr/bin/env bash
#
# hukuhaka-claude install preflight
#
# Discovers what tools / packages each selected component needs, checks
# them against the host, prints a JSON report to stdout.
#
# Usage:
#   scripts/preflight.sh --components a,b,c --src-dir /path/to/source
#
# Exit codes:
#   0 = all required satisfied
#   1 = at least one required missing

set -euo pipefail

SRC_DIR=""
COMPONENTS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --components) COMPONENTS="$2"; shift 2 ;;
        --src-dir) SRC_DIR="$2"; shift 2 ;;
        -h|--help)
            sed -n '3,15p' "$0"
            exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

if [ -z "$SRC_DIR" ] || [ ! -d "$SRC_DIR" ]; then
    echo "Error: --src-dir is required and must point to an extracted source tree" >&2
    exit 2
fi

if ! command -v python3 &>/dev/null; then
    # Without python3 we can't do the structured scan / JSON output.
    # Emit a minimal report indicating python3 itself is missing.
    cat <<'JSON'
{
  "summary": {"missing_required": 1, "missing_optional": 0, "ok": 0},
  "requirements": [
    {
      "name": "python3", "kind": "system", "required": true, "found": false,
      "needed_by": ["preflight scanner"]
    }
  ]
}
JSON
    exit 1
fi

# Component → source path resolver. Returns absolute dir or empty.
resolve_component_path() {
    local name="$1"
    if [ -d "$SRC_DIR/marketplace/$name" ]; then
        echo "$SRC_DIR/marketplace/$name"
    elif [ -d "$SRC_DIR/skills/$name" ]; then
        echo "$SRC_DIR/skills/$name"
    fi
    # statusline / agent-teams / claude-md are features → no scan path
}

# Build the requirements set as JSON via python3.
COMPONENTS="$COMPONENTS" SRC_DIR="$SRC_DIR" python3 <<'PY'
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

components_csv = os.environ.get("COMPONENTS", "")
src_dir = Path(os.environ["SRC_DIR"])
components = [c for c in components_csv.split(",") if c]

# stdlib module names — for is_stdlib check.
# Python 3.10+ has sys.stdlib_module_names; older needs a hardcoded list.
ALWAYS_STDLIB = {"__future__", "__main__"}  # not always in stdlib_module_names
try:
    stdlib_modules = set(sys.stdlib_module_names) | ALWAYS_STDLIB
except AttributeError:
    # Conservative list for 3.8–3.9. Anything not here is treated as third-party.
    stdlib_modules = {
        "abc", "argparse", "ast", "asyncio", "base64", "binascii", "bisect",
        "builtins", "calendar", "collections", "concurrent", "configparser",
        "contextlib", "copy", "csv", "ctypes", "datetime", "decimal",
        "difflib", "enum", "errno", "fcntl", "fnmatch", "functools", "gc",
        "getopt", "getpass", "glob", "gzip", "hashlib", "heapq", "html",
        "http", "importlib", "inspect", "io", "ipaddress", "itertools",
        "json", "logging", "math", "mimetypes", "multiprocessing",
        "operator", "os", "pathlib", "pickle", "platform", "pprint", "queue",
        "random", "re", "select", "selectors", "shlex", "shutil", "signal",
        "socket", "sqlite3", "ssl", "stat", "string", "struct", "subprocess",
        "sys", "tarfile", "tempfile", "termios", "textwrap", "threading",
        "time", "tomllib", "traceback", "tty", "typing", "unicodedata",
        "unittest", "urllib", "uuid", "warnings", "weakref", "xml",
        "zipfile", "zlib",
    } | ALWAYS_STDLIB

# requirement key: (name, kind) where kind ∈ {system, python}
requirements = {}

def add_req(name, kind, required, needed_by):
    key = (name, kind)
    if key in requirements:
        if needed_by not in requirements[key]["needed_by"]:
            requirements[key]["needed_by"].append(needed_by)
        # required wins
        requirements[key]["required"] = requirements[key]["required"] or required
    else:
        requirements[key] = {
            "name": name,
            "kind": kind,
            "required": required,
            "needed_by": [needed_by],
        }

# ── Hardcoded baselines (always required by installer/deploy themselves)
add_req("curl", "system", True, "installer (download)")
add_req("tar", "system", True, "installer (extract archive)")
add_req("python3", "system", True, "deploy (JSON manifests)")

# ── Optional baselines
add_req("jq", "system", False, "deploy (alternative JSON parser)")
add_req("whiptail", "system", False, "selector UI (Python TUI is default fallback)")
add_req("git", "system", False, "dev tools (eval pipeline)")

# ── Component scan
def resolve(name):
    p1 = src_dir / "marketplace" / name
    if p1.is_dir():
        return p1
    p2 = src_dir / "skills" / name
    if p2.is_dir():
        return p2
    return None

def shebang(path):
    try:
        with open(path, "rb") as f:
            first = f.readline()
        if first.startswith(b"#!"):
            return first[2:].decode("utf-8", "replace").strip()
    except Exception:
        pass
    return ""

import ast

def python_imports(path):
    """Return top-level python module names imported by the file.

    Uses ast.parse so that import-like syntax inside string literals
    (e.g. embedded JS bundles in render-html.py: `import React from
    "react"`) is NOT mistaken for a real python import.
    """
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            tree = ast.parse(f.read())
    except (SyntaxError, OSError):
        return []
    mods = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                mods.add(alias.name.split(".")[0])
        elif isinstance(node, ast.ImportFrom):
            if node.module and node.level == 0:
                mods.add(node.module.split(".")[0])
    return sorted(mods)

for cname in components:
    cpath = resolve(cname)
    if cpath is None:
        # statusline / agent-teams / claude-md / unknown — no scan
        continue
    for root, _dirs, files in os.walk(cpath):
        for f in files:
            full = Path(root) / f
            if f.endswith(".py"):
                add_req("python3", "system", True, cname)
                for mod in python_imports(full):
                    if mod in stdlib_modules:
                        continue
                    add_req(mod, "python", True, cname)
            elif f.endswith(".sh"):
                sb = shebang(full)
                if "bash" in sb:
                    add_req("bash", "system", True, cname)
                else:
                    add_req("sh", "system", True, cname)

# ── Check host
def check_system(name):
    path = shutil.which(name)
    if not path:
        return False, None, None
    version = None
    for flag in ("--version", "-V", "-v"):
        try:
            r = subprocess.run([name, flag], capture_output=True, timeout=2, text=True)
            out = (r.stdout or r.stderr).strip().split("\n")[0]
            if out:
                version = out[:120]
                break
        except Exception:
            continue
    return True, path, version

def check_python_module(name):
    try:
        r = subprocess.run(
            ["python3", "-c", f"import {name}"],
            capture_output=True, timeout=4
        )
        return r.returncode == 0
    except Exception:
        return False

results = []
for (name, kind), info in requirements.items():
    if kind == "system":
        found, path, version = check_system(name)
        entry = {**info, "found": found}
        if found:
            entry["path"] = path
            if version:
                entry["version"] = version
        results.append(entry)
    elif kind == "python":
        found = check_python_module(name)
        entry = {**info, "found": found}
        results.append(entry)

# Sort: required-missing first, then optional-missing, then ok.
def sort_key(r):
    if r["required"] and not r["found"]:
        return (0, r["name"])
    if not r["required"] and not r["found"]:
        return (1, r["name"])
    return (2, r["name"])

results.sort(key=sort_key)

missing_required = sum(1 for r in results if r["required"] and not r["found"])
missing_optional = sum(1 for r in results if not r["required"] and not r["found"])
ok = sum(1 for r in results if r["found"])

print(json.dumps({
    "summary": {
        "missing_required": missing_required,
        "missing_optional": missing_optional,
        "ok": ok,
    },
    "requirements": results,
}, indent=2))

sys.exit(1 if missing_required > 0 else 0)
PY
