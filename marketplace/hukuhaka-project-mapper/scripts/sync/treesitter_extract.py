#!/usr/bin/env python3
"""Optional tree-sitter symbol extraction for skeleton.py.

Single optional-dependency gate for the sync pipeline: when
tree-sitter-language-pack is not installed (AVAILABLE = False), a language
has no vendored query, or parsing fails, extract() returns None and
skeleton.py falls through to its stdlib generic-regex extractor.

Symbol strings follow extract_python's conventions: the definition node's
first source line (whitespace-normalized, truncated), members indented two
spaces. Queries live in queries/<lang>-tags.scm (see queries/ATTRIBUTION).
"""
from __future__ import annotations

from pathlib import Path

try:
    from tree_sitter_language_pack import get_language, get_parser
    AVAILABLE = True
except ImportError:
    AVAILABLE = False

QUERY_DIR = Path(__file__).resolve().parent / "queries"
MAX_SYMBOL_LEN = 100

# ext -> (parser key, query name). tsx parses with the tsx grammar but reuses
# the typescript query (TS superset; see ATTRIBUTION). C headers parse under
# the cpp grammar. .m/.mm (Objective-C) omitted -> generic fallback (no
# upstream query; recorded R3 deviation).
EXT_TO_LANG = {
    ".ts": ("typescript", "typescript"),
    ".tsx": ("tsx", "typescript"),
    ".js": ("javascript", "javascript"),
    ".jsx": ("javascript", "javascript"),
    ".mjs": ("javascript", "javascript"),
    ".cjs": ("javascript", "javascript"),
    ".kt": ("kotlin", "kotlin"),
    ".kts": ("kotlin", "kotlin"),
    ".swift": ("swift", "swift"),
    ".go": ("go", "go"),
    ".rs": ("rust", "rust"),
    ".dart": ("dart", "dart"),
    ".cpp": ("cpp", "cpp"),
    ".cc": ("cpp", "cpp"),
    ".cxx": ("cpp", "cpp"),
    ".hpp": ("cpp", "cpp"),
    ".h": ("cpp", "cpp"),
    ".c": ("c", "c"),
    ".java": ("java", "java"),
    ".scala": ("scala", "scala"),
    ".rb": ("ruby", "ruby"),
    ".php": ("php", "php"),
}

_QUERY_CACHE: dict[str, object] = {}


def _load_query(lang: str, qname: str):
    """Compile queries/<qname>-tags.scm against <lang>; None on any failure."""
    if lang in _QUERY_CACHE:
        return _QUERY_CACHE[lang]
    query = None
    path = QUERY_DIR / f"{qname}-tags.scm"
    if path.is_file():
        try:
            query = get_language(lang).query(path.read_text(encoding="utf-8"))
        except Exception:
            query = None
    _QUERY_CACHE[lang] = query
    return query


def _captures(query, root) -> dict:
    """Normalize capture results across py-tree-sitter versions."""
    try:
        from tree_sitter import QueryCursor  # 0.25+
        raw = QueryCursor(query).captures(root)
    except ImportError:
        raw = query.captures(root)  # <= 0.24
    if isinstance(raw, dict):
        return raw
    out: dict[str, list] = {}  # 0.21-style list[(node, name)]
    for node, name in raw:
        out.setdefault(name, []).append(node)
    return out


def _leading_doc(lines: list[str]) -> str:
    """First line comment at the top of the file, markers stripped.
    Shebangs and php/preprocessor openers are skipped, not treated as doc;
    '#' counts as a comment only with a trailing space (ruby '# text'),
    so C-family '#include'/'#pragma' lines never leak into doc."""
    for line in lines[:5]:
        s = line.strip()
        if not s:
            continue
        if s.startswith("#!") or s.startswith("<?"):
            continue
        for marker in ("///", "//", "/*", "# ", "*"):
            if s.startswith(marker):
                return s[len(marker):].strip(" *!/").strip()
        return ""
    return ""


def extract(rel: str, text: str) -> dict | None:
    """Tree-sitter extraction; None means 'caller should use its fallback'."""
    if not AVAILABLE:
        return None
    pair = EXT_TO_LANG.get(Path(rel).suffix.lower())
    if pair is None:
        return None
    lang, qname = pair
    query = _load_query(lang, qname)
    if query is None:
        return None
    try:
        tree = get_parser(lang).parse(text.encode("utf-8"))
    except Exception:
        return None

    lines = text.splitlines()
    found: list[tuple[int, str]] = []  # (row, symbol string)
    seen_rows: set[int] = set()
    entry_reasons: list[str] = []
    for cap_name, nodes in _captures(query, tree.root_node).items():
        if not cap_name.startswith("name.definition."):
            continue
        kind = cap_name.rsplit(".", 1)[-1]
        for node in nodes:
            row = node.start_point[0]
            if row in seen_rows or row >= len(lines):
                continue
            seen_rows.add(row)
            first = " ".join(lines[row].split())[:MAX_SYMBOL_LEN]
            found.append((row, ("  " if kind == "method" else "") + first))
            name = text[node.start_byte:node.end_byte]
            if kind == "function" and name == "main":
                entry_reasons.append("main function")
    found.sort()
    return {
        "symbols": [sym for _, sym in found],
        "doc": _leading_doc(lines),
        "imports": [],  # populated by skeleton.py's regex table (always-on)
        "entry_reasons": entry_reasons,
    }
