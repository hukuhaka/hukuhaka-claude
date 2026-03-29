#!/usr/bin/env python3
"""Quality judge for multi-agent orchestration effectiveness.

Evaluates how well agents were orchestrated: model selection,
parallelization, verification, stage isolation, and clarity.
Operates on truncated transcripts (like logic eval).
"""
import argparse
import json
import sys
from pathlib import Path

from judge_utils import run_judge, wrap_result

DIMENSIONS = [
    {"name": "model_stratification", "weight": 0.25},
    {"name": "parallelization_effectiveness", "weight": 0.25},
    {"name": "verification_independence", "weight": 0.20},
    {"name": "stage_isolation", "weight": 0.15},
    {"name": "orchestration_clarity", "weight": 0.15},
]


def extract_orchestration_events(transcript_path: str) -> str:
    """Extract orchestration-relevant events from transcript.

    Keeps: agent/task dispatches, model assignments, tool_use names per agent,
    parallel groupings (multiple tool_use in same message), verification steps.
    Strips: file contents, thinking blocks, long tool results.
    """
    lines = []
    with open(transcript_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            lines.append(obj)

    events = []
    for obj in lines:
        t = obj.get("type")

        if t == "system" and obj.get("subtype") == "init":
            events.append(json.dumps({
                "type": "system",
                "subtype": "init",
                "cwd": obj.get("cwd"),
                "tools": obj.get("tools"),
            }))
            continue

        if t == "assistant":
            msg = obj.get("message", {})
            content = msg.get("content", [])
            slim_content = []
            for block in content:
                bt = block.get("type")
                if bt == "thinking":
                    continue
                elif bt == "tool_use":
                    name = block.get("name", "")
                    inp = block.get("input", {})
                    slim_block = {
                        "type": "tool_use",
                        "id": block.get("id"),
                        "name": name,
                    }
                    # Keep orchestration-relevant fields, truncate the rest
                    if name in ("Agent", "Task", "TaskCreate", "TeamCreate"):
                        slim_inp = {}
                        for k, v in inp.items():
                            s = str(v)
                            if k == "prompt":
                                slim_inp[k] = s[:1500] + "..." if len(s) > 1500 else v
                            else:
                                slim_inp[k] = s[:500] + "..." if len(s) > 500 else v
                        slim_block["input"] = slim_inp
                    else:
                        # For non-orchestration tools, just keep name + brief input
                        slim_inp = {}
                        for k, v in inp.items():
                            s = str(v)
                            slim_inp[k] = s[:200] + "..." if len(s) > 200 else v
                        slim_block["input"] = slim_inp
                    slim_content.append(slim_block)
                elif bt == "text":
                    text = block.get("text", "")
                    slim_content.append({
                        "type": "text",
                        "text": text[:500] + "..." if len(text) > 500 else text,
                    })

            if slim_content:
                events.append(json.dumps({
                    "type": "assistant",
                    "message": {"content": slim_content},
                }))

        elif t == "user":
            msg = obj.get("message", {})
            content = msg.get("content", [])
            slim_content = []
            for block in content:
                if isinstance(block, dict) and block.get("type") == "tool_result":
                    result_content = block.get("content", "")
                    if isinstance(result_content, str):
                        result_content = (
                            result_content[:400] + "..."
                            if len(result_content) > 400
                            else result_content
                        )
                    slim_content.append({
                        "type": "tool_result",
                        "tool_use_id": block.get("tool_use_id"),
                        "content": result_content,
                    })
                elif isinstance(block, dict) and block.get("type") == "text":
                    text = block.get("text", "")
                    slim_content.append({
                        "type": "text",
                        "text": text[:300] + "..." if len(text) > 300 else text,
                    })

            parent = obj.get("parent_tool_use_id")
            entry = {"type": "user", "message": {"content": slim_content}}
            if parent:
                entry["parent_tool_use_id"] = parent
            events.append(json.dumps(entry))

    return "\n".join(events)


def load_rubric() -> str:
    """Load orchestration quality rubric."""
    rubric_path = Path(__file__).parent / "orchestration-quality-rubric.md"
    if rubric_path.exists():
        return rubric_path.read_text()
    return ""


def load_guide_context() -> str:
    """Load orchestration patterns from plugin-guide."""
    guide_path = (
        Path(__file__).parent.parent / "docs" / "plugin-guide" / "agents-and-hooks.md"
    )
    if guide_path.exists():
        content = guide_path.read_text()
        if len(content) > 15000:
            content = content[:15000] + "\n\n... (truncated)"
        return content
    return ""


def build_prompt(transcript: str, rubric: str, guide_context: str) -> str:
    """Build prompt for scoring orchestration quality."""
    guide_section = ""
    if guide_context:
        guide_section = f"""## Orchestration Patterns Reference
{guide_context}
"""

    return f"""You are evaluating the quality of multi-agent orchestration in a Claude Code transcript.

## Rubric
{rubric}

{guide_section}
## Transcript
{transcript}

## Instructions

Score each dimension from 1 to 5 based on the rubric. Follow these steps:

Step 1 — Identify orchestration pattern:
- Pipeline (sequential stages with structured handoff)?
- Parallel dispatch (independent tasks simultaneously)?
- Team (TeamCreate with multiple agents)?
- Mixed?

Step 2 — For each agent/task spawned, note:
- Model assigned (haiku/sonnet/opus/inherit/none)
- Task type (validation, analysis, generation, architecture)
- Whether dispatched in parallel or sequentially
- Scope boundaries in prompt

Step 3 — Score each dimension:
- Model stratification: Does each agent's model match its task complexity?
- Parallelization: Were independent tasks dispatched together? File boundaries respected?
- Verification independence: Was verification separate from implementation? Evidence-based?
- Stage isolation: Did stages maintain input/output boundaries and scope?
- Orchestration clarity: Were agent prompts specific with scope, boundaries, and output format?

Respond with ONLY valid JSON:
{{
  "orchestration_pattern": "<pipeline|parallel|team|mixed>",
  "agents_observed": [
    {{"name": "<agent description>", "model": "<model>", "task_type": "<type>"}}
  ],
  "scores": {{
    "model_stratification": {{"score": <1-5>, "reason": "<brief>"}},
    "parallelization_effectiveness": {{"score": <1-5>, "reason": "<brief>"}},
    "verification_independence": {{"score": <1-5>, "reason": "<brief>"}},
    "stage_isolation": {{"score": <1-5>, "reason": "<brief>"}},
    "orchestration_clarity": {{"score": <1-5>, "reason": "<brief>"}}
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


def eval_orchestration_quality(
    transcript_path: str, model: str = "sonnet"
) -> dict:
    """Score orchestration quality from a transcript."""
    transcript = extract_orchestration_events(transcript_path)
    rubric = load_rubric()
    guide_context = load_guide_context()
    prompt = build_prompt(transcript, rubric, guide_context)
    result = run_judge(prompt, model, timeout=600)

    if "weighted_total" not in result and "scores" in result:
        result["weighted_total"] = compute_weighted_total(result["scores"])

    result["transcript_path"] = transcript_path
    return wrap_result(result, "orchestration-quality", model)


def main():
    parser = argparse.ArgumentParser(
        description="Quality judge for multi-agent orchestration"
    )
    parser.add_argument("transcript", help="Path to transcript JSONL file")
    parser.add_argument("--model", default="sonnet", help="Judge model")
    parser.add_argument("--output", "-o", help="Output file path")
    args = parser.parse_args()

    result = eval_orchestration_quality(args.transcript, args.model)

    output = json.dumps(result, indent=2)
    if args.output:
        Path(args.output).parent.mkdir(parents=True, exist_ok=True)
        Path(args.output).write_text(output + "\n")
        print(f"Result written to {args.output}")
    else:
        print(output)


if __name__ == "__main__":
    main()
