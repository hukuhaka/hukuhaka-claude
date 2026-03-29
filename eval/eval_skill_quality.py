#!/usr/bin/env python3
"""Quality judge for authored skills and agents.

Scores skill/agent quality across 5 dimensions using LLM-as-judge.
Uses plugin-guide content as reference context for the judge.
"""
import argparse
import json
import sys
from pathlib import Path
from typing import Dict

from judge_utils import run_judge, wrap_result

DIMENSIONS = [
    {"name": "description_quality_cso", "weight": 0.30},
    {"name": "bulletproofing", "weight": 0.25},
    {"name": "progressive_disclosure", "weight": 0.20},
    {"name": "prompt_design", "weight": 0.15},
    {"name": "structural_correctness", "weight": 0.10},
]


def load_skill_files(outputs_dir: str) -> Dict[str, str]:
    """Load all skill/agent files from outputs directory."""
    docs = {}
    outputs_path = Path(outputs_dir)
    if not outputs_path.exists():
        print(f"Error: outputs directory not found: {outputs_dir}", file=sys.stderr)
        sys.exit(1)

    for f in outputs_path.rglob("*"):
        if f.is_file() and f.suffix in (".md", ".json", ".yml", ".yaml", ".sh", ".py"):
            rel = str(f.relative_to(outputs_path))
            docs[rel] = f.read_text()

    return docs


def load_rubric() -> str:
    """Load skill quality rubric."""
    rubric_path = Path(__file__).parent / "skill-quality-rubric.md"
    if rubric_path.exists():
        return rubric_path.read_text()
    return ""


def load_guide_context() -> str:
    """Load plugin-guide content as reference for the judge."""
    guide_dir = Path(__file__).parent.parent / "docs" / "plugin-guide"
    parts = []

    for name in ["skills.md", "skill-design.md", "agents-and-hooks.md"]:
        path = guide_dir / name
        if path.exists():
            content = path.read_text()
            # Truncate very long guides to fit context
            if len(content) > 15000:
                content = content[:15000] + "\n\n... (truncated)"
            parts.append(f"### {name}\n{content}")

    return "\n\n".join(parts) if parts else ""


def build_prompt(
    skill_files: Dict[str, str], rubric: str, guide_context: str
) -> str:
    """Build prompt for scoring skill quality."""
    files_text = []
    for path in sorted(skill_files.keys()):
        content = skill_files[path]
        files_text.append(f"### {path}\n```\n{content}\n```")
    files_section = "\n\n".join(files_text)

    guide_section = ""
    if guide_context:
        guide_section = f"""## Plugin Guide Reference (what "good" looks like)
{guide_context}
"""

    return f"""You are evaluating the quality of authored Claude Code skills and agents.

## Rubric
{rubric}

{guide_section}
## Authored Files
{files_section}

## Instructions

Score each dimension from 1 to 5 based on the rubric. Follow these steps:

Step 1 — Classify the skill:
- Is it discipline-enforcing (technique/process with hard steps) or reference/pattern?
- Does it define agents? If so, how many?
- What archetype? Infer from description: onboarding (<30 lines), frequent (<50 lines), standard (<500 lines, default), or router (<100 lines + refs).

Step 2 — Score each dimension:
- CSO: Trigger-condition format? Exclusions? <50 words? Keywords?
- Bulletproofing: If discipline skill — scan for structural patterns (iron law, rationalization table, red flags, hard gate, explicit negations) and enforcement signals ("You MUST", "Announce:", "Cannot proceed until", "Every project"). Count patterns: 3+ structural = score 4+, with enforcement language = score 5. If reference/pattern skill, score 3 baseline.
- Progressive disclosure: Apply archetype budget in lines. References/ or scripts/ used for heavy content? No duplication?
- Prompt design: If agents — single responsibility, output format, model selection (haiku=mechanical, sonnet=analysis, opus=architecture, inherit=valid for operator control). Independent verification preferred over self-review. If no agents, score 3 baseline.
- Structural correctness: Valid frontmatter, directory structure, naming conventions?

Respond with ONLY valid JSON:
{{
  "scores": {{
    "description_quality_cso": {{"score": <1-5>, "reason": "<brief>"}},
    "bulletproofing": {{"score": <1-5>, "reason": "<brief>"}},
    "progressive_disclosure": {{"score": <1-5>, "reason": "<brief>"}},
    "prompt_design": {{"score": <1-5>, "reason": "<brief>"}},
    "structural_correctness": {{"score": <1-5>, "reason": "<brief>"}}
  }},
  "weighted_total": <float, weighted sum>,
  "summary": "<1-2 sentence overall assessment>"
}}"""


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


def eval_skill_quality(outputs_dir: str, model: str = "sonnet") -> dict:
    """Score authored skill quality."""
    skill_files = load_skill_files(outputs_dir)
    rubric = load_rubric()
    guide_context = load_guide_context()
    prompt = build_prompt(skill_files, rubric, guide_context)
    result = run_judge(prompt, model)

    if "weighted_total" not in result and "scores" in result:
        result["weighted_total"] = compute_weighted_total(result["scores"])

    result["outputs_dir"] = outputs_dir
    result["files_evaluated"] = list(skill_files.keys())
    return wrap_result(result, "skill-quality", model)


def main():
    parser = argparse.ArgumentParser(description="Quality judge for authored skills")
    parser.add_argument("outputs_dir", help="Path to outputs directory with skill files")
    parser.add_argument("--model", default="sonnet", help="Judge model")
    parser.add_argument("--output", "-o", help="Output file path")
    args = parser.parse_args()

    result = eval_skill_quality(args.outputs_dir, args.model)

    output = json.dumps(result, indent=2)
    if args.output:
        Path(args.output).parent.mkdir(parents=True, exist_ok=True)
        Path(args.output).write_text(output + "\n")
        print(f"Result written to {args.output}")
    else:
        print(output)


if __name__ == "__main__":
    main()
