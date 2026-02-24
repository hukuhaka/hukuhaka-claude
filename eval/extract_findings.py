#!/usr/bin/env python3
"""Extract audit findings artifacts from a Claude Code transcript.

Parses transcript JSONL, extracts 3 artifacts:
- findings.json: analyzer Task tool_result JSON (structured findings)
- formatted_output.md: assistant text containing "## Audit Results"
- backlog_edit.md: Edit tool_use new_string targeting backlog.md
"""
import argparse
import json
import re
import sys
from pathlib import Path
from typing import Optional


def extract_findings(transcript_path: str, output_id: str) -> dict:
    """Extract audit artifacts from transcript JSONL.

    Strategy:
    1. Find Task tool_use where subagent_type contains 'analyzer'
    2. Match its tool_use_id to the tool_result in a subsequent user message
    3. Extract JSON from that tool_result text
    4. Find assistant text containing '## Audit Results'
    5. Find Edit tool_use targeting backlog.md
    """
    eval_dir = Path(__file__).parent
    output_dir = eval_dir / "outputs" / output_id
    output_dir.mkdir(parents=True, exist_ok=True)

    with open(transcript_path) as f:
        lines = [json.loads(l) for l in f if l.strip()]

    # Step 1: Find analyzer Task tool_use_id
    analyzer_tool_use_id = None
    for obj in lines:
        if obj.get("type") != "assistant":
            continue
        for block in obj.get("message", {}).get("content", []):
            if (
                block.get("type") == "tool_use"
                and block.get("name") == "Task"
                and "analyzer" in block.get("input", {}).get("subagent_type", "")
            ):
                analyzer_tool_use_id = block["id"]
                break
        if analyzer_tool_use_id:
            break

    # Step 2: Extract findings JSON from analyzer tool_result
    findings_json = None
    if analyzer_tool_use_id:
        for obj in lines:
            if obj.get("type") != "user":
                continue
            msg = obj.get("message", {})
            content = msg.get("content", []) if isinstance(msg, dict) else []
            if not isinstance(content, list):
                continue
            for block in content:
                if (
                    isinstance(block, dict)
                    and block.get("type") == "tool_result"
                    and block.get("tool_use_id") == analyzer_tool_use_id
                ):
                    result_content = block.get("content", "")
                    if isinstance(result_content, list):
                        for rc in result_content:
                            if rc.get("type") == "text":
                                findings_json = _extract_json_from_text(rc["text"])
                                if findings_json:
                                    break
                    elif isinstance(result_content, str):
                        findings_json = _extract_json_from_text(result_content)

    # Step 3: Find formatted output (## Audit Results)
    formatted_output = None
    for obj in lines:
        if obj.get("type") != "assistant":
            continue
        for block in obj.get("message", {}).get("content", []):
            if block.get("type") == "text" and "## Audit Results" in block.get("text", ""):
                formatted_output = block["text"]
                break
        if formatted_output:
            break

    # Step 4: Find backlog Edit
    backlog_edit = None
    for obj in lines:
        if obj.get("type") != "assistant":
            continue
        for block in obj.get("message", {}).get("content", []):
            if (
                block.get("type") == "tool_use"
                and block.get("name") == "Edit"
                and "backlog" in block.get("input", {}).get("file_path", "").lower()
            ):
                backlog_edit = block["input"].get("new_string", "")
                break
        if backlog_edit:
            break

    # Write artifacts
    artifacts = {}
    if findings_json:
        dest = output_dir / "findings.json"
        dest.write_text(json.dumps(findings_json, indent=2) + "\n")
        artifacts["findings.json"] = True

    if formatted_output:
        dest = output_dir / "formatted_output.md"
        dest.write_text(formatted_output)
        artifacts["formatted_output.md"] = True

    if backlog_edit:
        dest = output_dir / "backlog_edit.md"
        dest.write_text(backlog_edit)
        artifacts["backlog_edit.md"] = True

    return {
        "output_id": output_id,
        "output_dir": str(output_dir),
        "artifacts_extracted": len(artifacts),
        "artifacts": list(artifacts.keys()),
        "analyzer_tool_use_id": analyzer_tool_use_id,
    }


def _extract_json_from_text(text: str) -> Optional[dict]:
    """Extract JSON object from text (may be wrapped in ```json blocks)."""
    # Try code block first
    match = re.search(r"```(?:json)?\s*\n(.*?)\n```", text, re.DOTALL)
    if match:
        try:
            return json.loads(match.group(1))
        except json.JSONDecodeError:
            pass

    # Try raw JSON
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
    return None


def main():
    parser = argparse.ArgumentParser(description="Extract audit findings from transcript")
    parser.add_argument("transcript", help="Path to transcript JSONL file")
    parser.add_argument("--id", required=True, help="Output ID (directory name)")
    args = parser.parse_args()

    result = extract_findings(args.transcript, args.id)
    print(json.dumps(result, indent=2))

    if result["artifacts_extracted"] == 0:
        print("ERROR: No artifacts extracted", file=sys.stderr)
        sys.exit(1)
    elif result["artifacts_extracted"] < 3:
        missing = {"findings.json", "formatted_output.md", "backlog_edit.md"} - set(result["artifacts"])
        print(f"WARNING: Missing artifacts: {missing}", file=sys.stderr)


if __name__ == "__main__":
    main()
