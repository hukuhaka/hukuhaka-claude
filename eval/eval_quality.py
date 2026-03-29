#!/usr/bin/env python3
"""Quality judge for .claude/ documentation.

Scores documentation quality across 5 dimensions using LLM-as-judge.
Supports single-set scoring and side-by-side comparison mode.
"""
import argparse
import json
import sys
from pathlib import Path
from typing import Dict

from judge_utils import extract_json, run_judge, wrap_result

DIMENSIONS = [
    {"name": "completeness", "weight": 0.30},
    {"name": "accuracy", "weight": 0.25},
    {"name": "depth", "weight": 0.20},
    {"name": "format", "weight": 0.15},
    {"name": "coherence", "weight": 0.10},
]


def load_docs(docs_dir: str) -> Dict[str, str]:
    """Load all .claude/ files and scatter CLAUDE.md from a directory."""
    docs = {}
    docs_path = Path(docs_dir)
    if not docs_path.exists():
        print(f"Error: docs directory not found: {docs_dir}", file=sys.stderr)
        sys.exit(1)

    for f in docs_path.rglob("*"):
        if f.is_file() and (
            f.name.endswith(".md")
            or f.suffix in (".json", ".yml", ".yaml")
        ):
            rel = str(f.relative_to(docs_path))
            docs[rel] = f.read_text()

    return docs


def load_rubric() -> str:
    """Load quality rubric from eval/quality-rubric.md."""
    rubric_path = Path(__file__).parent / "quality-rubric.md"
    if rubric_path.exists():
        return rubric_path.read_text()
    return ""


def load_format_rules() -> str:
    """Load format-rules.md for reference context."""
    rules_path = (
        Path(__file__).parent.parent
        / "marketplace/project-mapper/skills/map-sync/references/format-rules.md"
    )
    if rules_path.exists():
        return rules_path.read_text()
    return ""


def _format_docs(docs: Dict[str, str], label: str) -> str:
    """Format a doc set for the prompt."""
    parts = [f"## {label}"]
    for path in sorted(docs.keys()):
        content = docs[path]
        parts.append(f"\n### {path}\n```\n{content}\n```")
    return "\n".join(parts)


def build_single_prompt(docs: Dict[str, str], rubric: str, format_rules: str) -> str:
    """Build prompt for scoring a single doc set."""
    docs_text = _format_docs(docs, "Documentation Set")

    return f"""You are evaluating the quality of .claude/ project documentation.

## Rubric
{rubric}

## Format Rules (reference)
{format_rules}

{docs_text}

## Instructions

Score each dimension from 1 to 5 based on the rubric. Provide brief reasoning.

Respond with ONLY valid JSON:
{{
  "scores": {{
    "completeness": {{"score": <1-5>, "reason": "<brief>"}},
    "accuracy": {{"score": <1-5>, "reason": "<brief>"}},
    "depth": {{"score": <1-5>, "reason": "<brief>"}},
    "format": {{"score": <1-5>, "reason": "<brief>"}},
    "coherence": {{"score": <1-5>, "reason": "<brief>"}}
  }},
  "weighted_total": <float, weighted sum>,
  "summary": "<1-2 sentence overall assessment>"
}}"""


def build_compare_prompt(
    docs_a: Dict[str, str],
    docs_b: Dict[str, str],
    label_a: str,
    label_b: str,
    rubric: str,
    format_rules: str,
) -> str:
    """Build prompt for side-by-side comparison (single call to prevent calibration drift)."""
    docs_a_text = _format_docs(docs_a, f"Set A ({label_a})")
    docs_b_text = _format_docs(docs_b, f"Set B ({label_b})")

    return f"""You are comparing two sets of .claude/ project documentation for quality.
Both sets document the same codebase. Score them on identical criteria in a SINGLE evaluation to ensure consistent calibration.

## Rubric
{rubric}

## Format Rules (reference)
{format_rules}

{docs_a_text}

{docs_b_text}

## Instructions

Score BOTH sets on each dimension (1-5). Then determine the winner per dimension.

Respond with ONLY valid JSON:
{{
  "scores_a": {{
    "completeness": {{"score": <1-5>, "reason": "<brief>"}},
    "accuracy": {{"score": <1-5>, "reason": "<brief>"}},
    "depth": {{"score": <1-5>, "reason": "<brief>"}},
    "format": {{"score": <1-5>, "reason": "<brief>"}},
    "coherence": {{"score": <1-5>, "reason": "<brief>"}}
  }},
  "scores_b": {{
    "completeness": {{"score": <1-5>, "reason": "<brief>"}},
    "accuracy": {{"score": <1-5>, "reason": "<brief>"}},
    "depth": {{"score": <1-5>, "reason": "<brief>"}},
    "format": {{"score": <1-5>, "reason": "<brief>"}},
    "coherence": {{"score": <1-5>, "reason": "<brief>"}}
  }},
  "comparison": [
    {{
      "dimension": "<name>",
      "winner": "<A|B|tie>",
      "delta": <float, absolute difference>,
      "reason": "<brief>"
    }}
  ],
  "weighted_total_a": <float>,
  "weighted_total_b": <float>,
  "overall_winner": "<A|B|tie>",
  "overall_delta": <float>,
  "summary": "<1-2 sentence comparison summary>"
}}"""



# run_judge and extract_json imported from judge_utils


def compute_weighted_total(scores: dict) -> float:
    """Compute weighted total from dimension scores."""
    total = 0.0
    for dim in DIMENSIONS:
        name = dim["name"]
        if name in scores:
            s = scores[name]
            score = s["score"] if isinstance(s, dict) else s
            total += score * dim["weight"]
    return round(total, 2)


def eval_quality_single(docs_dir: str, model: str = "sonnet") -> dict:
    """Score a single doc set."""
    docs = load_docs(docs_dir)
    rubric = load_rubric()
    format_rules = load_format_rules()
    prompt = build_single_prompt(docs, rubric, format_rules)
    result = run_judge(prompt, model)

    # Ensure weighted_total
    if "weighted_total" not in result and "scores" in result:
        result["weighted_total"] = compute_weighted_total(result["scores"])

    result["docs_dir"] = docs_dir
    result["files_evaluated"] = list(docs.keys())
    return wrap_result(result, "quality", model)


def eval_quality_compare(
    docs_dir_a: str,
    docs_dir_b: str,
    label_a: str = "MCP-ON",
    label_b: str = "MCP-OFF",
    model: str = "sonnet",
) -> dict:
    """Compare two doc sets side-by-side in a single prompt."""
    docs_a = load_docs(docs_dir_a)
    docs_b = load_docs(docs_dir_b)
    rubric = load_rubric()
    format_rules = load_format_rules()
    prompt = build_compare_prompt(docs_a, docs_b, label_a, label_b, rubric, format_rules)
    result = run_judge(prompt, model)

    # Ensure weighted totals
    if "weighted_total_a" not in result and "scores_a" in result:
        result["weighted_total_a"] = compute_weighted_total(result["scores_a"])
    if "weighted_total_b" not in result and "scores_b" in result:
        result["weighted_total_b"] = compute_weighted_total(result["scores_b"])

    result["docs_dir_a"] = docs_dir_a
    result["docs_dir_b"] = docs_dir_b
    result["label_a"] = label_a
    result["label_b"] = label_b
    return wrap_result(result, "quality-compare", model)


def main():
    parser = argparse.ArgumentParser(description="Quality judge for .claude/ docs")
    parser.add_argument("docs_dir", help="Path to extracted docs directory")
    parser.add_argument("--docs-dir-b", help="Second docs directory for comparison mode")
    parser.add_argument("--label-a", default="MCP-ON", help="Label for first set")
    parser.add_argument("--label-b", default="MCP-OFF", help="Label for second set")
    parser.add_argument("--model", default="sonnet", help="Judge model")
    parser.add_argument("--output", "-o", help="Output file path")
    args = parser.parse_args()

    if args.docs_dir_b:
        result = eval_quality_compare(
            args.docs_dir, args.docs_dir_b,
            args.label_a, args.label_b, args.model,
        )
    else:
        result = eval_quality_single(args.docs_dir, args.model)

    output = json.dumps(result, indent=2)
    if args.output:
        Path(args.output).parent.mkdir(parents=True, exist_ok=True)
        Path(args.output).write_text(output + "\n")
        print(f"Result written to {args.output}")
    else:
        print(output)


if __name__ == "__main__":
    main()
