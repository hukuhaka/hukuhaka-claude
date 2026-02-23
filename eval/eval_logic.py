#!/usr/bin/env python3
"""Logic judge for map-sync pipeline compliance.

Loads transcript JSONL, truncates aggressively, sends to Claude with
spec rules for pass/fail judgment per rule.
"""
import argparse
import json
import os
import subprocess
import sys
from pathlib import Path


def truncate_transcript(transcript_path: str) -> str:
    """Load and aggressively truncate transcript for judge context.

    Removes thinking blocks, truncates tool inputs to 200 chars,
    tool results to 300 chars, text to 500 chars.
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

    truncated = []
    for obj in lines:
        t = obj.get("type")

        if t == "system":
            # Keep init line (has cwd, tools, mcp_servers)
            if obj.get("subtype") == "init":
                slim = {
                    "type": "system",
                    "subtype": "init",
                    "cwd": obj.get("cwd"),
                    "mcp_servers": obj.get("mcp_servers"),
                    "tools": obj.get("tools"),
                }
                truncated.append(json.dumps(slim))
            continue

        if t == "assistant":
            msg = obj.get("message", {})
            content = msg.get("content", [])
            slim_content = []
            for block in content:
                bt = block.get("type")
                if bt == "thinking":
                    # Remove thinking entirely
                    continue
                elif bt == "tool_use":
                    slim_block = {
                        "type": "tool_use",
                        "id": block.get("id"),
                        "name": block.get("name"),
                    }
                    inp = block.get("input", {})
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
                else:
                    slim_content.append(block)

            if slim_content:
                truncated.append(json.dumps({
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
                        result_content = result_content[:300] + "..." if len(result_content) > 300 else result_content
                    slim_content.append({
                        "type": "tool_result",
                        "tool_use_id": block.get("tool_use_id"),
                        "content": result_content,
                    })
                elif isinstance(block, dict) and block.get("type") == "text":
                    text = block.get("text", "")
                    slim_content.append({
                        "type": "text",
                        "text": text[:500] + "..." if len(text) > 500 else text,
                    })
                else:
                    slim_content.append(block)

            parent = obj.get("parent_tool_use_id")
            entry = {"type": "user", "message": {"content": slim_content}}
            if parent:
                entry["parent_tool_use_id"] = parent
            truncated.append(json.dumps(entry))

    return "\n".join(truncated)


def load_spec(spec_path: str) -> dict:
    """Load logic spec JSON."""
    with open(spec_path) as f:
        return json.load(f)


def build_judge_prompt(spec: dict, transcript: str, mcp_mode: str) -> str:
    """Build the prompt for Claude judge."""
    rules_text = []
    skip_rules = []
    for rule in spec["rules"]:
        if rule.get("mcp_required") and mcp_mode == "off":
            skip_rules.append(rule["rule_id"])
            continue
        rules_text.append(
            f"- {rule['rule_id']} ({rule['severity']}, {rule['type']}): {rule['description']}"
        )

    prompt = f"""You are evaluating a Claude Code transcript for compliance with the map-sync pipeline rules.

## Rules to evaluate

{chr(10).join(rules_text)}

{f"## Skipped rules (MCP off)" if skip_rules else ""}
{chr(10).join(f"- {r}: auto-skipped (mcp_required, MCP is off)" for r in skip_rules) if skip_rules else ""}

## Instructions

For each rule, determine: pass, fail, or unclear.
Provide specific evidence (tool_use IDs, message ordering, file paths).

Respond with ONLY valid JSON in this exact format:
{{
  "score": <float 0.0-1.0, fraction of non-skipped rules that passed>,
  "summary": {{
    "total_rules": <int>,
    "passed": <int>,
    "failed": <int>,
    "skipped": <int>,
    "unclear": <int>,
    "critical_violations": [<list of rule_ids that failed with severity=critical>],
    "notable_observations": [<list of 2-4 brief observations>]
  }},
  "results": [
    {{
      "rule_id": "<id>",
      "severity": "<critical|major>",
      "type": "<must|must_not>",
      "status": "<pass|fail|skip|unclear>",
      "evidence": "<specific evidence string>"
    }}
  ]
}}

## Transcript

{transcript}"""

    return prompt


def run_judge(prompt: str, model: str = "sonnet") -> dict:
    """Call Claude CLI as judge and parse JSON response."""
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
        timeout=300,
        env=env,
    )

    if result.returncode != 0:
        print(f"Claude CLI error: {result.stderr}", file=sys.stderr)
        sys.exit(1)

    # Parse CLI output (JSON with "result" field)
    try:
        cli_output = json.loads(result.stdout)
        response_text = cli_output.get("result", result.stdout)
    except json.JSONDecodeError:
        response_text = result.stdout

    # Extract JSON from response
    return _extract_json(response_text)


def _extract_json(text: str) -> dict:
    """Extract JSON object from text, handling markdown code blocks."""
    # Try direct parse
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    # Try extracting from code block
    import re
    match = re.search(r"```(?:json)?\s*\n(.*?)\n```", text, re.DOTALL)
    if match:
        try:
            return json.loads(match.group(1))
        except json.JSONDecodeError:
            pass

    # Try finding JSON object boundaries
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
                        return json.loads(text[start:i + 1])
                    except json.JSONDecodeError:
                        break

    print(f"Failed to parse judge response:\n{text[:500]}", file=sys.stderr)
    sys.exit(1)


def eval_logic(
    transcript_path: str,
    spec_path: str,
    scenario: dict,
    model: str = "sonnet",
) -> dict:
    """Run logic evaluation on a transcript.

    Returns result dict compatible with existing eval format.
    """
    spec = load_spec(spec_path)
    mcp_mode = scenario.get("mcp_mode", "on")

    transcript = truncate_transcript(transcript_path)
    prompt = build_judge_prompt(spec, transcript, mcp_mode)
    result = run_judge(prompt, model)

    # Add scenario metadata
    result["scenario_id"] = scenario.get("scenario_id", "")
    result["scenario_name"] = scenario.get("scenario_name", "")
    result["skill"] = scenario.get("skill", spec.get("skill", ""))

    # Ensure score fields exist
    if "score" in result:
        result["weighted_score"] = result["score"]

    return result


def main():
    parser = argparse.ArgumentParser(description="Logic judge for map-sync compliance")
    parser.add_argument("transcript", help="Path to transcript JSONL file")
    parser.add_argument("--spec", required=True, help="Path to logic spec JSON")
    parser.add_argument("--scenario", help="Path to scenario JSON (for metadata + mcp_mode)")
    parser.add_argument("--mcp-mode", choices=["on", "off"], default="on",
                        help="MCP mode (overrides scenario)")
    parser.add_argument("--model", default="sonnet", help="Judge model")
    parser.add_argument("--output", "-o", help="Output file path")
    args = parser.parse_args()

    scenario = {}
    if args.scenario:
        with open(args.scenario) as f:
            scenario = json.load(f)

    if args.mcp_mode:
        scenario["mcp_mode"] = args.mcp_mode

    result = eval_logic(args.transcript, args.spec, scenario, args.model)

    output = json.dumps(result, indent=2)
    if args.output:
        Path(args.output).parent.mkdir(parents=True, exist_ok=True)
        Path(args.output).write_text(output + "\n")
        print(f"Result written to {args.output}")
    else:
        print(output)


if __name__ == "__main__":
    main()
