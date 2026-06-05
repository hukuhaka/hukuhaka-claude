#!/usr/bin/env python3
"""
skeleton.py — deterministic structural skeleton for map-sync Step 2a.

Extracts the machine-decidable half of the analyzer's 9-field JSON contract
with zero LLM tokens: stats, todos, stack, and candidate entry_points /
components / directories (name, path, depends_on, entry-candidate flag).
Descriptions are deliberately ABSENT — writing them is the describe agent's
job over this skeleton.

Per-language extraction (stdlib only):
    .py          ast — top-level defs/classes, docstrings, imports, __main__ guard
    .sh/.bash    regex — function defs, source edges, shebang
    .md          line scan — H1/H2, frontmatter name, relative links
    .json        json — top-level keys; manifest name/version
    other source regex fallback — function/class/export-like definition lines

depends_on (deterministic version of the old analyzer grep rule): a node's
internal imports, kept only when the imported module is imported by >= 2
files project-wide.

Usage:
    python3 skeleton.py [project_root]            -> .claude/.sync/skeleton.json
    python3 skeleton.py [project_root] --scatter D -> per-dir extract on stdout
"""
from __future__ import annotations

import ast
import json
import os
import re
import subprocess
import sys
from pathlib import Path

# Reuse scan.py's deny/marker/source configuration (same plugin, sibling dir).
_SCAN_DIR = Path(__file__).resolve().parent.parent / "scan"
sys.path.insert(0, str(_SCAN_DIR))
from scan import DENY, MARKERS, SOURCE_EXT  # noqa: E402

# Optional tree-sitter extraction (sibling module owns the dependency gate);
# any failure degrades per-file to extract_generic — never fatal.
try:
    import treesitter_extract
except ImportError:
    treesitter_extract = None

SYMBOL_EXT = {".py", ".sh", ".bash", ".md", ".json"}
ENTRY_NAMES = {"main", "app", "cli", "run", "server", "index", "__main__"}
TODO_RE = re.compile(r"(TODO|FIXME)[:\s](.{0,120})")
SH_FUNC_RE = re.compile(r"^\s*(?:function\s+)?([A-Za-z_][A-Za-z0-9_-]*)\s*\(\)\s*\{?\s*$")
SH_SOURCE_RE = re.compile(r"^\s*(?:source|\.)\s+([^\s;]+)")
MD_LINK_RE = re.compile(r"\[[^\]]*\]\(([^)#][^)]*)\)")
GENERIC_DEF_RE = re.compile(
    r"^\s*(?:export\s+)?(?:default\s+)?(?:pub\s+)?(?:async\s+)?"
    r"(?:function|class|def|fn|func|type|interface|struct|trait|impl)\s+"
    r"([A-Za-z_][A-Za-z0-9_]*)"
)

# Import extraction for non-Python sources (always-on, stdlib regex — runs
# with or without tree-sitter, so even the generic fallback gains imports).
# Values: (pattern, format) — format reshapes the capture for the resolver,
# e.g. require_relative paths get an explicit './' prefix.
IMPORT_PATTERNS: dict[tuple, list[tuple[re.Pattern, str]]] = {
    (".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs"): [
        (re.compile(r"""^\s*import\s+(?:[^'"]*?\sfrom\s)?\s*['"]([^'"]+)['"]"""), "{0}"),
        (re.compile(r"""^\s*export\s+[^'"]*?\sfrom\s+['"]([^'"]+)['"]"""), "{0}"),
        (re.compile(r"""^\s*\}\s*from\s+['"]([^'"]+)['"]"""), "{0}"),
        (re.compile(r"""\brequire\(\s*['"]([^'"]+)['"]\s*\)"""), "{0}"),
    ],
    (".go",): [
        (re.compile(r'^\s*import\s+(?:[\w.]+\s+)?"([^"]+)"'), "{0}"),
    ],
    (".java", ".kt", ".kts", ".scala"): [
        (re.compile(r"^\s*import\s+(?:static\s+)?([\w.]+)"), "{0}"),
    ],
    (".rs",): [
        (re.compile(r"^\s*(?:pub(?:\([^)]*\))?\s+)?use\s+([A-Za-z_][\w:]*)"), "{0}"),
        (re.compile(r"^\s*(?:pub(?:\([^)]*\))?\s+)?mod\s+([A-Za-z_]\w*)\s*;"), "mod {0}"),
    ],
    (".c", ".h", ".cpp", ".cc", ".cxx", ".hpp", ".m", ".mm"): [
        (re.compile(r'^\s*#\s*include\s+"([^"]+)"'), "{0}"),  # <...> = external, skipped
    ],
    (".rb",): [
        (re.compile(r"""^\s*require_relative\s+['"]([^'"]+)['"]"""), "./{0}"),
        (re.compile(r"""^\s*require\s+['"]([^'"]+)['"]"""), "{0}"),
    ],
    (".php",): [
        (re.compile(r"^\s*use\s+([\w\\]+)"), "{0}"),
    ],
    (".swift",): [
        (re.compile(r"^\s*import\s+(\w+)"), "{0}"),
    ],
    (".dart",): [
        (re.compile(r"""^\s*import\s+['"]([^'"]+)['"]"""), "{0}"),
    ],
}
GO_IMPORT_OPEN_RE = re.compile(r"^\s*import\s*\(")
GO_IMPORT_LINE_RE = re.compile(r'^\s*(?:[\w.]+\s+)?"([^"]+)"')


def extract_imports_regex(ext: str, text: str) -> list[str]:
    """Per-language import targets; [] for languages without patterns."""
    pats = None
    for exts, p in IMPORT_PATTERNS.items():
        if ext in exts:
            pats = p
            break
    if pats is None:
        return []
    imports: list[str] = []
    seen: set[str] = set()

    def add(value: str) -> None:
        if value and value not in seen:
            seen.add(value)
            imports.append(value)

    in_go_block = False
    for line in text.splitlines():
        if ext == ".go":
            if GO_IMPORT_OPEN_RE.match(line):
                in_go_block = True
                continue
            if in_go_block:
                if line.strip().startswith(")"):
                    in_go_block = False
                else:
                    m = GO_IMPORT_LINE_RE.match(line)
                    if m:
                        add(m.group(1))
                continue
        for rx, fmt in pats:
            m = rx.search(line)
            if m:
                add(fmt.format(m.group(1)))
                break
    return imports


# ─── enumeration ─────────────────────────────────────────────────────

def list_files(root: Path) -> list[str]:
    """All tracked + untracked-not-ignored files (git), or os.walk fallback.
    Prunes DENY dirs, hidden paths, .claude/, and CLAUDE.md files (those are
    bundle inputs, not analysis targets)."""
    files: list[str] = []
    try:
        result = subprocess.run(
            ["git", "-C", str(root), "ls-files", "-co", "--exclude-standard"],
            capture_output=True, text=True, check=True, timeout=30,
        )
        files = [l for l in result.stdout.splitlines() if l.strip()]
    except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if d not in DENY and not d.startswith(".")]
            for f in filenames:
                files.append((Path(dirpath) / f).relative_to(root).as_posix())

    out: list[str] = []
    for f in files:
        parts = Path(f).parts
        if any(p in DENY or p.startswith(".") for p in parts[:-1]):
            continue
        if parts and parts[0].startswith("."):
            continue
        if Path(f).name == "CLAUDE.md":
            continue
        if (root / f).is_file():
            out.append(f)
    return sorted(out)


def read_text(path: Path) -> str | None:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None


# ─── per-language extractors ─────────────────────────────────────────

def _sig(node) -> str:
    """Render a def's signature (args with defaults + return annotation) so
    downstream prose agents see implementation detail without reading bodies."""
    try:
        args = ast.unparse(node.args)
        ret = f" -> {ast.unparse(node.returns)}" if node.returns else ""
        deco = "".join(f"@{ast.unparse(d)} " for d in node.decorator_list[:2])
        return f"{deco}({args}){ret}"
    except Exception:
        return "(...)"


def extract_python(rel: str, text: str) -> dict:
    """ast-based: signatures, doc, imports (all, incl. nested), __main__ guard."""
    info: dict = {"symbols": [], "doc": "", "imports": [], "entry_reasons": []}
    try:
        tree = ast.parse(text)
    except SyntaxError:
        # regex fallback for unparseable files
        for line in text.splitlines():
            m = GENERIC_DEF_RE.match(line)
            if m:
                info["symbols"].append(m.group(1))
        return info

    doc = ast.get_docstring(tree)
    if doc:
        info["doc"] = doc.strip().splitlines()[0]
    for node in tree.body:
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            info["symbols"].append(f"def {node.name}{_sig(node)}")
        elif isinstance(node, ast.ClassDef):
            cls_doc = ast.get_docstring(node)
            info["symbols"].append(
                f"class {node.name}" + (f"  # {cls_doc.strip().splitlines()[0]}" if cls_doc else ""))
            for sub in node.body[:10]:
                if isinstance(sub, (ast.FunctionDef, ast.AsyncFunctionDef)):
                    info["symbols"].append(f"  {node.name}.{sub.name}{_sig(sub)}")
        elif isinstance(node, ast.Assign):
            # module-level singletons/objects: `app = FastAPI(...)`, `_pool = ConnectionPool(...)`
            for tgt in node.targets:
                if isinstance(tgt, ast.Name) and isinstance(node.value, ast.Call):
                    try:
                        fn = ast.unparse(node.value.func)
                    except Exception:
                        continue
                    info["symbols"].append(f"{tgt.id} = {fn}(...)")
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            info["imports"].extend(a.name for a in node.names)
        elif isinstance(node, ast.ImportFrom) and node.module:
            info["imports"].append(node.module)
    if "__main__" in text:
        info["entry_reasons"].append("__main__ guard")
    return info


def extract_shell(rel: str, text: str) -> dict:
    info: dict = {"symbols": [], "doc": "", "imports": [], "entry_reasons": []}
    lines = text.splitlines()
    if lines and lines[0].startswith("#!"):
        info["entry_reasons"].append("shebang")
    for line in lines[:5]:
        if line.startswith("#") and not line.startswith("#!"):
            info["doc"] = line.lstrip("# ").strip()
            break
    for line in lines:
        m = SH_FUNC_RE.match(line)
        if m:
            info["symbols"].append(f"fn {m.group(1)}")
        m = SH_SOURCE_RE.match(line)
        if m:
            info["imports"].append(m.group(1))
    return info


def extract_markdown(rel: str, text: str) -> dict:
    info: dict = {"symbols": [], "doc": "", "imports": [], "entry_reasons": []}
    lines = text.splitlines()
    in_fm = False
    for i, line in enumerate(lines):
        if i == 0 and line.strip() == "---":
            in_fm = True
            continue
        if in_fm:
            if line.strip() == "---":
                in_fm = False
            elif line.startswith("name:"):
                info["symbols"].append(f"name {line.split(':', 1)[1].strip()}")
            continue
        if line.startswith("# ") and not info["doc"]:
            info["doc"] = line[2:].strip()
        elif line.startswith("## "):
            info["symbols"].append(f"h2 {line[3:].strip()}")
        for m in MD_LINK_RE.finditer(line):
            target = m.group(1).strip()
            if not target.startswith(("http://", "https://", "mailto:")):
                info["imports"].append(target)
    return info


def extract_json_file(rel: str, text: str) -> dict:
    info: dict = {"symbols": [], "doc": "", "imports": [], "entry_reasons": []}
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        return info
    if isinstance(data, dict):
        info["symbols"] = [f"key {k}" for k in list(data)[:12]]
        name = data.get("name")
        version = data.get("version")
        if isinstance(name, str):
            info["doc"] = f"{name}" + (f" v{version}" if isinstance(version, str) else "")
        if Path(rel).name == "package.json":
            # R4: declared executables
            bins = data.get("bin")
            if isinstance(bins, str):
                info["entry_hints"] = [bins]
            elif isinstance(bins, dict):
                info["entry_hints"] = [v for v in bins.values() if isinstance(v, str)]
            # stack signal — also for NESTED package.json (frontend/ etc.),
            # which detect_stack's root-only branch never sees
            deps = data.get("dependencies")
            if isinstance(deps, dict):
                info["stack_hints"] = sorted(deps)[:8]
    return info


def extract_generic(rel: str, text: str) -> dict:
    """Fallback for source languages without a dedicated extractor."""
    info: dict = {"symbols": [], "doc": "", "imports": [], "entry_reasons": []}
    for line in text.splitlines():
        m = GENERIC_DEF_RE.match(line)
        if m:
            info["symbols"].append(m.group(1))
    return info


# ─── Tier-2 manifest extractors ──────────────────────────────────────
# Record/meta files, matched by FILENAME. Hard caps by design: single-pass
# stdlib regex, ~20 lines each, no evaluation, no graph output. Each emits
# exactly 3 signal types: stack_hints (-> detect_stack), a 1-line doc
# ("name vX" pattern), entry_hints (-> R4 cross-ref in build_skeleton).

GRADLE_DEP_RE = re.compile(
    r"""(?:implementation|api|compileOnly|runtimeOnly|testImplementation)"""
    r"""\s*[("']\s*['"]?([\w.:-]+)""")
GRADLE_MAIN_RE = re.compile(r"""mainClass(?:\.set)?\s*[=(]\s*["']([\w.]+)["']""")
POM_ARTIFACT_RE = re.compile(r"<artifactId>([\w.-]+)</artifactId>")
POM_VERSION_RE = re.compile(r"<version>([\w.-]+)</version>")
POM_MAIN_RE = re.compile(r"<mainClass>([\w.]+)</mainClass>")
GOMOD_REQ_RE = re.compile(
    r"^\s*(?:require\s+)?([\w./-]+\.[\w./-]+)\s+v[\w.+-]+", re.MULTILINE)
GEM_RE = re.compile(r"""^\s*gem\s+['"]([\w-]+)""", re.MULTILINE)
CMAKE_PROJECT_RE = re.compile(
    r"project\s*\(\s*([\w-]+)(?:[^)]*VERSION\s+([\d.]+))?", re.IGNORECASE)
CMAKE_EXE_RE = re.compile(r"add_executable\s*\(\s*([\w-]+)\s+([^)]+)\)", re.IGNORECASE)


def _dedup(seq: list[str]) -> list[str]:
    out: list[str] = []
    for s in seq:
        if s and s not in out:
            out.append(s)
    return out


def _manifest_info(doc: str, deps: list[str], stack: list[str],
                   entries: list[str], symbols: list[str] | None = None) -> dict:
    return {"symbols": symbols if symbols is not None else [f"dep {d}" for d in deps[:12]],
            "doc": doc, "imports": [], "entry_reasons": [],
            "stack_hints": stack, "entry_hints": entries}


def extract_gradle(rel: str, text: str) -> dict:
    deps = _dedup(GRADLE_DEP_RE.findall(text))
    main = GRADLE_MAIN_RE.search(text)
    return _manifest_info("Gradle build", deps, ["Gradle"] + deps[:8],
                          [main.group(1)] if main else [])


def extract_pom(rel: str, text: str) -> dict:
    artifacts = POM_ARTIFACT_RE.findall(text)
    name = artifacts[0] if artifacts else ""
    ver = POM_VERSION_RE.search(text)
    deps = _dedup(artifacts[1:])
    main = POM_MAIN_RE.search(text)
    doc = f"{name} v{ver.group(1)}" if name and ver else (name or "Maven POM")
    return _manifest_info(doc, deps, ["Maven"] + deps[:8],
                          [main.group(1)] if main else [])


def extract_gomod(rel: str, text: str) -> dict:
    mod = re.search(r"^module\s+(\S+)", text, re.MULTILINE)
    gover = re.search(r"^go\s+([\d.]+)", text, re.MULTILINE)
    deps = _dedup(GOMOD_REQ_RE.findall(text))
    doc = f"module {mod.group(1)}" if mod else "Go module"
    return _manifest_info(doc, deps,
                          ([f"Go {gover.group(1)}"] if gover else ["Go"]) + deps[:8], [])


def extract_cargo(rel: str, text: str) -> dict:
    section, name, ver = "", "", ""
    deps: list[str] = []
    entries: list[str] = []
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("["):
            section = s.strip("[]")
            continue
        m = re.match(r'([\w-]+)\s*=\s*"?([^"\n]*)"?', s)
        if not m:
            continue
        key, val = m.group(1), m.group(2)
        if section == "package":
            name = val if key == "name" else name
            ver = val if key == "version" else ver
        elif "dependencies" in section and key not in deps:
            deps.append(key)
        elif section == "bin" and key == "path":
            entries.append(val)
    doc = f"{name} v{ver}" if name and ver else (name or "Cargo manifest")
    return _manifest_info(doc, deps, ["Rust (Cargo)"] + deps[:8], entries)


def extract_gemfile(rel: str, text: str) -> dict:
    deps = _dedup(GEM_RE.findall(text))
    return _manifest_info("Gemfile", deps, ["Ruby (Bundler)"] + deps[:8], [])


def extract_pyproject(rel: str, text: str) -> dict:
    """Nested pyproject.toml (backend/ etc.) — detect_stack's root-only
    branch never sees it. Same regex approach as the root parsing."""
    name = re.search(r'^name\s*=\s*"([^"]+)"', text, re.MULTILINE)
    ver = re.search(r'^version\s*=\s*"([^"]+)"', text, re.MULTILINE)
    deps: list[str] = []
    m = re.search(r"dependencies\s*=\s*\[([^\]]*)\]", text, re.DOTALL)
    if m:
        deps = _dedup(re.findall(r'"([A-Za-z0-9_.\-]+)', m.group(1)))
    doc = (f"{name.group(1)} v{ver.group(1)}" if name and ver
           else (name.group(1) if name else "pyproject"))
    return _manifest_info(doc, deps, deps[:8], [])


def extract_cmake(rel: str, text: str) -> dict:
    m = CMAKE_PROJECT_RE.search(text)
    name = m.group(1) if m else ""
    ver = m.group(2) if m and m.group(2) else ""
    symbols: list[str] = []
    entries: list[str] = []
    for em in CMAKE_EXE_RE.finditer(text):
        symbols.append(f"executable {em.group(1)}")
        for tok in em.group(2).split():
            if Path(tok).suffix.lower() in SOURCE_EXT:
                entries.append(tok)
                break
    doc = f"{name} v{ver}" if name and ver else (f"{name} (CMake)" if name else "CMake build")
    return _manifest_info(doc, [], ["CMake"] + ([name] if name else []),
                          entries, symbols=symbols[:12])


MANIFEST_EXTRACTORS = {
    "build.gradle": extract_gradle,
    "build.gradle.kts": extract_gradle,
    "pom.xml": extract_pom,
    "go.mod": extract_gomod,
    "Cargo.toml": extract_cargo,
    "Gemfile": extract_gemfile,
    "CMakeLists.txt": extract_cmake,
    "pyproject.toml": extract_pyproject,
}


def extract_file(rel: str, text: str) -> dict | None:
    manifest = MANIFEST_EXTRACTORS.get(Path(rel).name)
    if manifest is not None:
        return manifest(rel, text)
    ext = Path(rel).suffix.lower()
    if ext == ".py":
        return extract_python(rel, text)
    if ext in (".sh", ".bash"):
        return extract_shell(rel, text)
    if ext == ".md":
        return extract_markdown(rel, text)
    if ext == ".json":
        return extract_json_file(rel, text)
    if ext in SOURCE_EXT:
        info = None
        if treesitter_extract is not None:
            info = treesitter_extract.extract(rel, text)
        if info is None:
            info = extract_generic(rel, text)
        info["imports"] = extract_imports_regex(ext, text)
        return info
    return None


# ─── R2: declaration/definition merge ────────────────────────────────

def _unit_key(rel: str) -> tuple[str, str]:
    """(parent_dir, logical stem) — foo.d.ts collapses to foo."""
    p = Path(rel)
    stem = p.stem
    if p.suffix == ".ts" and stem.endswith(".d"):
        stem = stem[:-2]
    return (p.parent.as_posix(), stem)


def merge_decl_def(extracted: dict[str, dict]) -> None:
    """R2 (cross-language rule): when a declaration file and a definition file
    share (parent_dir, stem), the definition wins — .h/.hpp vs .c/.cpp/.cc/
    .cxx/.m/.mm, .d.ts vs .ts. The decl node is marked merged_into (skipped as
    a candidate, kept in the dict so imports of the decl path still resolve);
    its doc fills an empty definition doc and its imports are unioned in.
    Declaration-only units (lone header, generated .d.ts) stay as nodes."""
    by_key: dict[tuple[str, str], list[str]] = {}
    for rel in extracted:
        by_key.setdefault(_unit_key(rel), []).append(rel)
    for rels in by_key.values():
        if len(rels) < 2:
            continue
        decls: list[str] = []
        defs: list[str] = []
        for rel in rels:
            ext = Path(rel).suffix.lower()
            if ext in (".h", ".hpp") or (ext == ".ts" and Path(rel).stem.endswith(".d")):
                decls.append(rel)
            elif ext in (".c", ".cpp", ".cc", ".cxx", ".m", ".mm", ".ts"):
                defs.append(rel)
        if not decls or not defs:
            continue
        target = sorted(defs)[0]
        info = extracted[target]
        for decl in decls:
            dinfo = extracted[decl]
            if not info.get("doc") and dinfo.get("doc"):
                info["doc"] = dinfo["doc"]
            for imp in dinfo.get("imports", []):
                if imp not in info["imports"]:
                    info["imports"].append(imp)
            dinfo["merged_into"] = target


# ─── import graph -> depends_on ──────────────────────────────────────

def py_module_name(rel: str) -> str:
    """src/core/config.py -> src.core.config ; src/core/__init__.py -> src.core"""
    p = Path(rel)
    parts = list(p.with_suffix("").parts)
    if parts and parts[-1] == "__init__":
        parts = parts[:-1]
    return ".".join(parts)


# R1 (cross-language rule): an import is INTERNAL iff it resolves to a repo
# file — then it becomes a depends_on edge; otherwise it is external and
# dropped. Python implements this via the module-name map below; the families
# here get a resolver each. Deferred with recorded reasons: .rs (needs crate
# root + mod tree), .php (namespace->PSR-4 map), .swift (module imports are
# external by nature). .dart relative imports resolve via the plain fallback.

JS_RESOLVE_EXTS = (".ts", ".tsx", ".d.ts", ".js", ".jsx", ".mjs", ".cjs")


def _resolve_js(rel: str, imp: str, files: dict, ctx: dict) -> str | None:
    """'./x' / '../y' -> extension candidates + index barrels; bare = external."""
    if not imp.startswith("."):
        return None
    base = os.path.normpath((Path(rel).parent / imp).as_posix())
    cands = [base] + [base + e for e in JS_RESOLVE_EXTS] \
        + [f"{base}/index{e}" for e in JS_RESOLVE_EXTS]
    for cand in cands:
        if cand in files and cand != rel:
            return cand
    return None


def _resolve_c(rel: str, imp: str, files: dict, ctx: dict) -> str | None:
    """Quoted #include: relative join, else unique-basename match (covers
    -I include dirs without parsing build files; ambiguous basenames skip)."""
    cand = os.path.normpath((Path(rel).parent / imp).as_posix())
    if cand in files and cand != rel:
        return cand
    owners = ctx["basenames"].get(Path(imp).name, [])
    if len(owners) == 1 and owners[0] != rel:
        return owners[0]
    return None


def _resolve_go(rel: str, imp: str, files: dict, ctx: dict) -> str | None:
    """go.mod module prefix -> package dir -> representative .go file."""
    prefix = ctx.get("go_module")
    if not prefix or not (imp == prefix or imp.startswith(prefix + "/")):
        return None
    sub = imp[len(prefix):].strip("/") or "."
    pkg = sorted(f for f in files if f.endswith(".go") and f != rel
                 and Path(f).parent.as_posix() == sub)
    for f in pkg:  # prefer <dirname>.go as the package's face
        if Path(f).stem == Path(sub).name:
            return f
    return pkg[0] if pkg else None


def _resolve_jvm(rel: str, imp: str, files: dict, ctx: dict) -> str | None:
    """package.path.Class -> a unique file whose path ends with the suffix."""
    suffix = imp.rstrip(".").replace(".", "/")
    for ext in (".java", ".kt", ".kts", ".scala"):
        target = suffix + ext
        hits = [f for f in files
                if (f == target or f.endswith("/" + target)) and f != rel]
        if len(hits) == 1:
            return hits[0]
    return None


def _resolve_rb(rel: str, imp: str, files: dict, ctx: dict) -> str | None:
    """require_relative ('./'-prefixed by the import table); require = external."""
    if not imp.startswith("."):
        return None
    base = os.path.normpath((Path(rel).parent / imp).as_posix())
    for cand in (base, base + ".rb"):
        if cand in files and cand != rel:
            return cand
    return None


IMPORT_RESOLVERS: dict[str, object] = {}
for _e in (".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs"):
    IMPORT_RESOLVERS[_e] = _resolve_js
for _e in (".c", ".h", ".cpp", ".cc", ".cxx", ".hpp", ".m", ".mm"):
    IMPORT_RESOLVERS[_e] = _resolve_c
for _e in (".java", ".kt", ".kts", ".scala"):
    IMPORT_RESOLVERS[_e] = _resolve_jvm
IMPORT_RESOLVERS[".go"] = _resolve_go
IMPORT_RESOLVERS[".rb"] = _resolve_rb


def resolve_imports(files: dict[str, dict], root: Path | None = None) -> dict[str, list[str]]:
    """Map each file -> list of INTERNAL files it imports/sources/links."""
    module_to_file: dict[str, str] = {}
    basenames: dict[str, list[str]] = {}
    for rel in files:
        if rel.endswith(".py"):
            module_to_file[py_module_name(rel)] = rel
        basenames.setdefault(Path(rel).name, []).append(rel)
    go_module = None
    if root is not None:
        gomod = read_text(root / "go.mod")
        if gomod:
            m = re.search(r"^module\s+(\S+)", gomod, re.MULTILINE)
            if m:
                go_module = m.group(1)
    ctx = {"basenames": basenames, "go_module": go_module}

    edges: dict[str, list[str]] = {}
    for rel, info in files.items():
        targets: list[str] = []
        for imp in info.get("imports", []):
            if rel.endswith(".py"):
                # exact module or a parent package match
                mod = imp
                while mod:
                    if mod in module_to_file and module_to_file[mod] != rel:
                        targets.append(module_to_file[mod])
                        break
                    mod = mod.rpartition(".")[0]
                continue
            resolver = IMPORT_RESOLVERS.get(Path(rel).suffix.lower())
            if resolver is not None:
                target = resolver(rel, imp, files, ctx)
                if target:
                    targets.append(target)
                continue
            # plain path edge (shell source / md link / dart relative)
            cand = os.path.normpath((Path(rel).parent / imp).as_posix())
            if cand in files and cand != rel:
                targets.append(cand)
            elif imp in files and imp != rel:
                targets.append(imp)
        edges[rel] = sorted(set(targets))
    return edges


def compute_depends_on(edges: dict[str, list[str]]) -> dict[str, list[str]]:
    """node -> short names of imports whose target has >= 2 importers
    project-wide (the analyzer contract's old grep rule, computed exactly)."""
    importer_count: dict[str, int] = {}
    for _src, targets in edges.items():
        for t in targets:
            importer_count[t] = importer_count.get(t, 0) + 1
    eligible = {t for t, n in importer_count.items() if n >= 2}
    out: dict[str, list[str]] = {}
    for src, targets in edges.items():
        out[src] = sorted(Path(t).stem if Path(t).stem != "__init__" else Path(t).parent.name
                          for t in targets if t in eligible)
    return out


# ─── stack + todos ───────────────────────────────────────────────────

# stdlib imports worth surfacing as stack entries (semantic signal, not noise)
NOTABLE_STDLIB = {
    "sqlite3": "SQLite (stdlib sqlite3)",
    "argparse": "argparse (stdlib)",
    "asyncio": "asyncio",
    "tkinter": "Tkinter",
    "multiprocessing": "multiprocessing",
}


def detect_stack(root: Path, files: list[str], extracted: dict[str, dict]) -> list[str]:
    stack: list[str] = []
    exts = {Path(f).suffix.lower() for f in files}
    pyproject = read_text(root / "pyproject.toml") if "pyproject.toml" in files else None
    if ".py" in exts:
        label = "Python"
        if pyproject:
            m = re.search(r'requires-python\s*=\s*"([^"]+)"', pyproject)
            if m:
                label = f"Python {m.group(1)}"
        stack.append(label)
    if pyproject:
        m = re.search(r"dependencies\s*=\s*\[([^\]]*)\]", pyproject, re.DOTALL)
        if m:
            for dep in re.findall(r'"([A-Za-z0-9_.\-]+)', m.group(1)):
                stack.append(dep)
    pkg = read_text(root / "package.json") if "package.json" in files else None
    if pkg:
        try:
            data = json.loads(pkg)
            if ".ts" in exts or ".tsx" in exts:
                stack.append("TypeScript")
            elif ".js" in exts:
                stack.append("JavaScript")
            stack.extend(sorted(data.get("dependencies", {}))[:8])
        except json.JSONDecodeError:
            pass
    # notable stdlib usage (from the already-extracted import lists)
    imported = {i for info in extracted.values() for i in info.get("imports", [])}
    for mod, label in NOTABLE_STDLIB.items():
        if mod in imported:
            stack.append(label)
    # deployment tooling visible in shell scripts
    for rel in files:
        if Path(rel).suffix.lower() in (".sh", ".bash"):
            text = read_text(root / rel) or ""
            if re.search(r"\bdocker\b", text):
                stack.append("Docker (deployment)")
                break
    # languages by extension — only when substantial (>= 2 files)
    for ext, label in ((".sh", "Shell"), (".go", "Go"), (".rs", "Rust"),
                       (".kt", "Kotlin"), (".swift", "Swift"), (".rb", "Ruby"),
                       (".ts", "TypeScript"), (".tsx", "TypeScript"),
                       (".java", "Java"), (".cpp", "C++")):
        if label not in stack and sum(1 for f in files if Path(f).suffix.lower() == ext) >= 2:
            stack.append(label)
    # Tier-2 manifest signals (gradle/pom/go.mod/Cargo/Gemfile/CMake)
    for rel in sorted(extracted):
        for hint in extracted[rel].get("stack_hints", []):
            if hint not in stack:
                stack.append(hint)
    return stack


def scan_todos(root: Path, files: list[str]) -> list[dict]:
    todos: list[dict] = []
    for rel in files:
        ext = Path(rel).suffix.lower()
        if ext not in SYMBOL_EXT and ext not in SOURCE_EXT:
            continue
        text = read_text(root / rel)
        if text is None:
            continue
        for lineno, line in enumerate(text.splitlines(), 1):
            m = TODO_RE.search(line)
            if m:
                todos.append({"file": rel, "line": lineno,
                              "text": f"{m.group(1)}: {m.group(2).strip()}"})
    return todos


# ─── candidates ──────────────────────────────────────────────────────

def manifest_entry_map(extracted: dict[str, dict]) -> dict[str, str]:
    """R4: resolve manifest-declared entries (package.json bin, gradle/pom
    mainClass, Cargo [[bin]] path, CMake add_executable source) to file nodes
    -> {target_rel: reason}. Path hints join relative to the manifest's dir;
    dotted class hints use the JVM suffix match."""
    out: dict[str, str] = {}
    for man_rel, info in extracted.items():
        for hint in info.get("entry_hints", []):
            target = None
            if "/" in hint or Path(hint).suffix.lower() in SOURCE_EXT:
                cand = os.path.normpath((Path(man_rel).parent / hint).as_posix())
                if cand in extracted and cand != man_rel:
                    target = cand
            elif "." in hint:  # dotted mainClass
                target = _resolve_jvm(man_rel, hint, extracted, {})
            if target:
                out.setdefault(target, f"declared entry in {Path(man_rel).name}")
    return out


def entry_reasons(rel: str, info: dict, root: Path, console_scripts: set[str]) -> list[str]:
    reasons = list(info.get("entry_reasons", []))
    stem = Path(rel).stem.lower()
    if stem in ENTRY_NAMES:
        reasons.append(f"conventional name '{stem}'")
    mod = py_module_name(rel) if rel.endswith(".py") else None
    if mod and mod in console_scripts:
        reasons.append("console_scripts target")
    if rel.endswith(".py") and re.search(r"^app\s*=", read_text(root / rel) or "", re.MULTILINE):
        reasons.append("module-level app object")
    return reasons


def parse_console_scripts(root: Path) -> set[str]:
    text = read_text(root / "pyproject.toml")
    if not text:
        return set()
    out: set[str] = set()
    m = re.search(r"\[project\.scripts\](.*?)(\n\[|\Z)", text, re.DOTALL)
    if m:
        for line in m.group(1).splitlines():
            mm = re.search(r'=\s*"([^:"]+)', line)
            if mm:
                out.add(mm.group(1).strip())
    return out


def build_skeleton(root: Path) -> dict:
    rels = list_files(root)
    extracted: dict[str, dict] = {}
    for rel in rels:
        text = read_text(root / rel)
        if text is None:
            continue
        info = extract_file(rel, text)
        if info is not None:
            extracted[rel] = info

    # degradation visibility: rich extraction unavailable -> say so once
    if treesitter_extract is None or not treesitter_extract.AVAILABLE:
        degraded = sum(1 for r in extracted
                       if Path(r).suffix.lower() in SOURCE_EXT
                       and Path(r).suffix.lower() not in SYMBOL_EXT)
        if degraded:
            print(f"skeleton: tree-sitter unavailable — {degraded} source "
                  "file(s) degraded to generic regex (pip install "
                  "tree-sitter-language-pack to enable)", file=sys.stderr)

    merge_decl_def(extracted)
    edges = resolve_imports(extracted, root)
    depends = compute_depends_on(edges)
    console_scripts = parse_console_scripts(root)
    manifest_entries = manifest_entry_map(extracted)

    entry_points: list[dict] = []
    components: list[dict] = []
    for rel, info in sorted(extracted.items()):
        if "merged_into" in info:
            continue
        reasons = entry_reasons(rel, info, root, console_scripts)
        if rel in manifest_entries and manifest_entries[rel] not in reasons:
            reasons.append(manifest_entries[rel])
        node = {
            "name": Path(rel).stem if Path(rel).stem != "__init__" else Path(rel).parent.name,
            "path": rel,
            "depends_on": depends.get(rel, []),
            "skeleton_doc": info.get("doc", ""),
            "symbols": info.get("symbols", [])[:25],
        }
        if reasons:
            node["is_entry_candidate"] = True
            node["entry_reasons"] = reasons
            entry_points.append(node)
        elif info.get("symbols") or info.get("doc"):
            components.append(node)

    # directories: scan.md scatter rows first (authoritative), else top-level dirs
    directories: list[dict] = []
    scan_md = root / ".claude" / "scan.md"
    if scan_md.is_file():
        from changed_dirs import parse_scatter_rows
        for d in parse_scatter_rows(scan_md):
            n_files = sum(1 for r in rels if r.startswith(d + "/"))
            directories.append({"path": d + "/", "skeleton_doc": f"{n_files} file(s)"})
    else:
        top = sorted({r.split("/", 1)[0] for r in rels if "/" in r})
        for d in top:
            n_files = sum(1 for r in rels if r.startswith(d + "/"))
            directories.append({"path": d + "/", "skeleton_doc": f"{n_files} file(s)"})

    todos = scan_todos(root, rels)
    return {
        "stats": {
            "files_scanned": len(rels),
            "todos_found": len(todos),
            "entry_candidates_found": len(entry_points),
            "components_found": len(components),
        },
        "stack": detect_stack(root, rels, extracted),
        "todos": todos,
        "candidates": {
            "entry_points": entry_points,
            "components": components,
            "directories": directories,
        },
    }


# ─── scatter mode ────────────────────────────────────────────────────

HEAD_LINES = 20


def scatter_extract(root: Path, rel_dir: str) -> str:
    """Deterministic per-directory extract for the describe agent's scatter
    mode: file list + head lines + child dirs. Replaces the old analyzer's
    Glob+Read exploration."""
    d = root / rel_dir.rstrip("/")
    if not d.is_dir():
        return f"ERROR: {rel_dir} is not a directory"
    out: list[str] = [f"===== SCATTER EXTRACT: {rel_dir.rstrip('/')}/ ====="]
    children: list[str] = []
    entries = sorted(d.iterdir(), key=lambda p: p.name)
    for entry in entries:
        if entry.name.startswith(".") or entry.name in DENY:
            continue
        if entry.is_dir():
            children.append(entry.name)
    files = [e for e in entries if e.is_file() and not e.name.startswith(".")
             and e.name != "CLAUDE.md"]
    out.append(f"children: {', '.join(children) if children else '(none)'}")
    out.append(f"files: {len(files)}")
    for f in files:
        out.append(f"\n--- {f.name} (first {HEAD_LINES} lines) ---")
        text = read_text(f)
        if text is None:
            out.append("(unreadable)")
            continue
        out.extend(text.splitlines()[:HEAD_LINES])
    return "\n".join(out)


# ─── main ────────────────────────────────────────────────────────────

def main(argv: list[str]) -> int:
    args = [a for a in argv[1:] if not a.startswith("--")]
    scatter_dir = None
    if "--scatter" in argv[1:]:
        idx = argv.index("--scatter")
        if idx + 1 >= len(argv):
            print("ERROR: --scatter requires a directory argument", file=sys.stderr)
            return 1
        scatter_dir = argv[idx + 1]
        args = [a for a in args if a != scatter_dir]
    root = Path(args[0] if args else os.getcwd()).resolve()

    if scatter_dir is not None:
        print(scatter_extract(root, scatter_dir))
        return 0

    claude_dir = root / ".claude"
    if not claude_dir.is_dir():
        print(f"ERROR: {claude_dir}/ does not exist. Run /hukuhaka-project-mapper:map-init first.",
              file=sys.stderr)
        return 1

    skeleton = build_skeleton(root)
    sync_dir = claude_dir / ".sync"
    sync_dir.mkdir(exist_ok=True)
    out_path = sync_dir / "skeleton.json"
    out_path.write_text(json.dumps(skeleton, indent=2) + "\n", encoding="utf-8")
    s = skeleton["stats"]
    print(f"# skeleton: {s['files_scanned']} files, {s['entry_candidates_found']} entry candidates, "
          f"{s['components_found']} components, {s['todos_found']} todos -> {out_path.relative_to(root)}",
          file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
