#!/usr/bin/env python3
"""Extract authored skill/agent files from a Claude Code transcript.

Parses transcript JSONL, finds Write tool_use calls targeting skill directories
(SKILL.md, agents/*.md, references/), and saves them to eval/outputs/{ID}/.
"""
import argparse
import json
import os
import sys
from pathlib import Path
from typing import Dict, List, Optional


def extract_skill_files(
    transcript_path: str, output_id: str, cwd: Optional[str] = None
) -> dict:
    """Extract skill/agent files from transcript JSONL.

    Args:
        transcript_path: Path to transcript JSONL file.
        output_id: ID for output directory.
        cwd: Working directory used during capture (auto-detected from init line).

    Returns:
        dict with extracted file count and paths.
    """
    eval_dir = Path(__file__).parent
    output_dir = eval_dir / "outputs" / output_id
    output_dir.mkdir(parents=True, exist_ok=True)

    detected_cwd = cwd
    files_written = []

    with open(transcript_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue

            # Auto-detect cwd from init line
            if obj.get("type") == "system" and obj.get("subtype") == "init":
                if not detected_cwd:
                    detected_cwd = obj.get("cwd", "")
                continue

            # Look for assistant messages with Write tool_use
            if obj.get("type") != "assistant":
                continue

            msg = obj.get("message", {})
            for block in msg.get("content", []):
                if block.get("type") != "tool_use" or block.get("name") != "Write":
                    continue

                inp = block.get("input", {})
                file_path = inp.get("file_path", "")
                content = inp.get("content", "")

                if not file_path or not content:
                    continue

                if not _is_skill_file(file_path, detected_cwd):
                    continue

                rel_path = _to_relative(file_path, detected_cwd)
                if not rel_path:
                    continue

                dest = output_dir / rel_path
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_text(content)
                files_written.append(rel_path)

    return {
        "output_id": output_id,
        "output_dir": str(output_dir),
        "cwd": detected_cwd,
        "files_extracted": len(files_written),
        "files": files_written,
    }


def _is_skill_file(file_path: str, cwd: Optional[str]) -> bool:
    """Check if file is a skill, agent, or related resource."""
    if cwd and file_path.startswith(cwd):
        rel = file_path[len(cwd) :].lstrip("/")
    else:
        rel = file_path

    # SKILL.md anywhere
    if rel.endswith("/SKILL.md") or rel == "SKILL.md":
        return True

    # .claude/skills/ directory
    if ".claude/skills/" in rel:
        return True

    # skills/ directory (plugin structure)
    if rel.startswith("skills/") or "/skills/" in rel:
        return True

    # agents/ directory
    if rel.startswith("agents/") or "/agents/" in rel:
        if rel.endswith(".md"):
            return True

    # references/ within a skill directory
    if "/references/" in rel:
        return True

    # scripts/ within a skill directory
    if "/scripts/" in rel and ("/skills/" in rel or ".claude/skills/" in rel):
        return True

    return False


def _to_relative(file_path: str, cwd: Optional[str]) -> Optional[str]:
    """Convert absolute path to relative path from cwd."""
    if cwd and file_path.startswith(cwd):
        return file_path[len(cwd) :].lstrip("/")
    return os.path.basename(file_path) if "/" not in file_path else file_path


def main():
    parser = argparse.ArgumentParser(
        description="Extract skill/agent files from transcript"
    )
    parser.add_argument("transcript", help="Path to transcript JSONL file")
    parser.add_argument("--id", required=True, help="Output ID (directory name)")
    parser.add_argument("--cwd", help="Override working directory detection")
    args = parser.parse_args()

    result = extract_skill_files(args.transcript, args.id, args.cwd)

    print(json.dumps(result, indent=2))
    if result["files_extracted"] == 0:
        print("WARNING: No skill files extracted", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
