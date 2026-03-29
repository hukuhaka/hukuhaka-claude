#!/usr/bin/env python3
"""Shared utilities for eval judges.

Provides JSON extraction, Claude CLI invocation, model mapping,
and result envelope used by all eval judge scripts.
"""
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone

MODEL_MAP = {
    "sonnet": "claude-sonnet-4-6",
    "opus": "claude-opus-4-6",
    "haiku": "claude-haiku-4-5-20251001",
}


def extract_json(text: str) -> dict:
    """Extract JSON object from text, handling markdown code blocks.

    Tries in order: direct parse, code block extraction, brace-matching.
    """
    # Direct parse
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    # Code block extraction
    match = re.search(r"```(?:json)?\s*\n(.*?)\n```", text, re.DOTALL)
    if match:
        try:
            return json.loads(match.group(1))
        except json.JSONDecodeError:
            pass

    # Brace-matching
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


def run_judge(prompt: str, model: str = "sonnet", timeout: int = 300) -> dict:
    """Call Claude CLI as judge and parse JSON response.

    Args:
        prompt: Judge prompt text.
        model: Model shortname (sonnet/opus/haiku) or full model ID.
        timeout: Subprocess timeout in seconds (default 300, use 600 for large prompts).

    Returns:
        Parsed JSON dict from judge response.
    """
    model_id = MODEL_MAP.get(model, model)

    env = os.environ.copy()
    env.pop("CLAUDECODE", None)

    result = subprocess.run(
        ["claude", "-p", prompt, "--model", model_id, "--output-format", "json"],
        capture_output=True,
        text=True,
        timeout=timeout,
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

    return extract_json(response_text)


def wrap_result(result: dict, eval_type: str, model: str) -> dict:
    """Add common envelope to judge result for unified schema.

    Adds: eval_type, score (normalized 0-1), model, model_id, timestamp.
    Logic type: score already 0-1, kept as-is.
    Quality types: score = weighted_total / 5.0 (normalize 1-5 to 0-1).
    """
    model_id = MODEL_MAP.get(model, model)

    # Normalize score to 0-1
    if eval_type == "logic":
        score = result.get("score", 0.0)
    else:
        weighted = result.get("weighted_total", 0.0)
        score = round(weighted / 5.0, 4)

    result["eval_type"] = eval_type
    result["score"] = score
    result["model"] = model
    result["model_id"] = model_id
    result["timestamp"] = datetime.now(timezone.utc).isoformat()

    return result
