#!/usr/bin/env python3
"""Quality judge for audit findings.

Scores audit findings quality across 5 dimensions using LLM-as-judge.
"""
import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Dict, Optional

DIMENSIONS = [
    {"name": "evidence_quality", "weight": 0.30},
    {"name": "suggestion_actionability", "weight": 0.25},
    {"name": "confidence_calibration", "weight": 0.20},
    {"name": "coverage_prioritization", "weight": 0.15},
    {"name": "presentation_fidelity", "weight": 0.10},
]


def _extract_json(text: str) -> dict:
    """Extract JSON from text (shared with eval_quality.py)."""
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    match = re.search(r"```(?:json)?\s*\n(.*?)\n```", text, re.DOTALL)
    if match:
        try:
            return json.loads(match.group(1))
        except json.JSONDecodeError:
            pass

    start = text.find("{")
    if start >= 0:
        depth = 0
        for i, c in enumerate(text[start:], start):
            if c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    try:
                        return json.loads(text[start : i + 1])
                    except json.JSONDecodeError:
                        break

    print(f"Failed to parse judge response:\n{text[:500]}", file=sys.stderr)
    sys.exit(1)


def run_judge(prompt: str, model: str = "sonnet") -> dict:
    """Call Claude CLI as judge (600s timeout for large audit prompts)."""
    model_id = {
        "sonnet": "claude-sonnet-4-6",
        "opus": "claude-opus-4-6",
        "haiku": "claude-haiku-4-5-20251001",
    }.get(model, model)

    env = os.environ.copy()
    env.pop("CLAUDECODE", None)

    result = subprocess.run(
        ["claude", "-p", prompt, "--model", model_id, "--output-format", "json"],
        capture_output=True,
        text=True,
        timeout=600,
        env=env,
    )

    if result.returncode != 0:
        print(f"Claude CLI error: {result.stderr}", file=sys.stderr)
        sys.exit(1)

    try:
        cli_output = json.loads(result.stdout)
        response_text = cli_output.get("result", result.stdout)
    except json.JSONDecodeError:
        response_text = result.stdout

    return _extract_json(response_text)


def load_findings(outputs_dir: str) -> Dict[str, Optional[str]]:
    """Load 3 audit artifacts from outputs directory."""
    outputs_path = Path(outputs_dir)
    if not outputs_path.exists():
        print(f"Error: outputs directory not found: {outputs_dir}", file=sys.stderr)
        sys.exit(1)

    artifacts = {}
    for name in ["findings.json", "formatted_output.md", "backlog_edit.md"]:
        path = outputs_path / name
        if path.exists():
            content = path.read_text()
            # Strip absolute paths from findings.json to reduce prompt size
            if name == "findings.json":
                content = re.sub(r"/[^\s\"]*?/eval/testbed/", "", content)
            artifacts[name] = content
        else:
            artifacts[name] = None
            print(f"WARNING: Missing artifact: {name}", file=sys.stderr)

    return artifacts


def load_rubric() -> str:
    """Load audit quality rubric from eval/audit-quality-rubric.md."""
    rubric_path = Path(__file__).parent / "audit-quality-rubric.md"
    if rubric_path.exists():
        return rubric_path.read_text()
    return ""


def load_analysis_guide() -> str:
    """Load analysis-guide.md for reference context."""
    guide_path = (
        Path(__file__).parent.parent
        / "marketplace/project-mapper/skills/audit/references/analysis-guide.md"
    )
    if guide_path.exists():
        return guide_path.read_text()
    return ""


def build_prompt(artifacts: Dict[str, Optional[str]], rubric: str, analysis_guide: str) -> str:
    """Build prompt for scoring audit findings quality."""
    sections = []

    if artifacts.get("findings.json"):
        sections.append(f"## Analyzer JSON Output\n```json\n{artifacts['findings.json']}\n```")

    if artifacts.get("formatted_output.md"):
        sections.append(f"## Formatted Output\n{artifacts['formatted_output.md']}")

    if artifacts.get("backlog_edit.md"):
        sections.append(f"## Backlog Edit\n```markdown\n{artifacts['backlog_edit.md']}\n```")

    artifacts_text = "\n\n".join(sections)

    return f"""You are evaluating the quality of codebase audit findings produced by an AI audit pipeline.

## Rubric
{rubric}

## Analysis Guide (reference — what the analyzer agent should follow)
{analysis_guide}

## Audit Artifacts
{artifacts_text}

## Instructions

Score each dimension from 1 to 5 based on the rubric. Consider:
- Evidence quality: Are findings backed by Grep/Read tool results with line numbers?
- Suggestion actionability: Do suggestions name specific files, techniques, and targets?
- Confidence calibration: Do confidence levels match evidence strength per the analysis guide?
- Coverage prioritization: Are multiple categories covered? Are bugs ranked above style issues?
- Presentation fidelity: Are the 3 artifacts (JSON, formatted, backlog) consistent?

Respond with ONLY valid JSON:
{{
  "scores": {{
    "evidence_quality": {{"score": <1-5>, "reason": "<brief>"}},
    "suggestion_actionability": {{"score": <1-5>, "reason": "<brief>"}},
    "confidence_calibration": {{"score": <1-5>, "reason": "<brief>"}},
    "coverage_prioritization": {{"score": <1-5>, "reason": "<brief>"}},
    "presentation_fidelity": {{"score": <1-5>, "reason": "<brief>"}}
  }},
  "weighted_total": <float, weighted sum>,
  "summary": "<1-2 sentence overall assessment>"
}}"""


def eval_audit_quality(outputs_dir: str, model: str = "sonnet") -> dict:
    """Score audit findings quality."""
    artifacts = load_findings(outputs_dir)
    rubric = load_rubric()
    analysis_guide = load_analysis_guide()
    prompt = build_prompt(artifacts, rubric, analysis_guide)
    result = run_judge(prompt, model)

    # Ensure weighted_total using our audit-specific dimensions
    if "weighted_total" not in result and "scores" in result:
        total = 0.0
        for dim in DIMENSIONS:
            name = dim["name"]
            if name in result["scores"]:
                s = result["scores"][name]
                score = s["score"] if isinstance(s, dict) else s
                total += score * dim["weight"]
        result["weighted_total"] = round(total, 2)

    result["outputs_dir"] = outputs_dir
    result["artifacts_loaded"] = [k for k, v in artifacts.items() if v is not None]
    return result


def main():
    parser = argparse.ArgumentParser(description="Quality judge for audit findings")
    parser.add_argument("outputs_dir", help="Path to outputs directory with audit artifacts")
    parser.add_argument("--model", default="sonnet", help="Judge model")
    parser.add_argument("--output", "-o", help="Output file path")
    args = parser.parse_args()

    result = eval_audit_quality(args.outputs_dir, args.model)

    output = json.dumps(result, indent=2)
    if args.output:
        Path(args.output).parent.mkdir(parents=True, exist_ok=True)
        Path(args.output).write_text(output + "\n")
        print(f"Result written to {args.output}")
    else:
        print(output)


if __name__ == "__main__":
    main()
