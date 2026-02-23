#!/usr/bin/env python3
"""Extract .claude/ docs from a Claude Code transcript.

Parses transcript JSONL, finds Write tool_use calls targeting .claude/ files
or scatter CLAUDE.md, and saves them to eval/outputs/{ID}/ preserving paths.
"""
import argparse
import json
import os
import sys
from pathlib import Path
from typing import Dict, List, Optional


def extract_docs(transcript_path: str, output_id: str, cwd: Optional[str] = None) -> dict:
    """Extract .claude/ files from transcript JSONL.

    Args:
        transcript_path: Path to transcript JSONL file.
        output_id: ID for output directory (e.g., SYNC-QUAL-MCP-ON).
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

                # Filter: only .claude/ files and scatter CLAUDE.md
                if not _is_doc_file(file_path, detected_cwd):
                    continue

                # Convert absolute path to relative
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


def _is_doc_file(file_path: str, cwd: Optional[str]) -> bool:
    """Check if file is a .claude/ doc or scatter CLAUDE.md."""
    # Normalize
    if cwd and file_path.startswith(cwd):
        rel = file_path[len(cwd):].lstrip("/")
    else:
        rel = file_path

    # .claude/ directory files
    if rel.startswith(".claude/"):
        return True

    # Scatter CLAUDE.md (subdirectory, not root)
    if rel.endswith("/CLAUDE.md") and "/" in rel.rsplit("/CLAUDE.md", 1)[0]:
        return True
    if rel.count("/") >= 1 and rel.endswith("CLAUDE.md"):
        return True

    return False


def _to_relative(file_path: str, cwd: Optional[str]) -> Optional[str]:
    """Convert absolute path to relative path from cwd."""
    if cwd and file_path.startswith(cwd):
        return file_path[len(cwd):].lstrip("/")
    # Already relative or unknown cwd
    return os.path.basename(file_path) if "/" not in file_path else file_path


def main():
    parser = argparse.ArgumentParser(description="Extract .claude/ docs from transcript")
    parser.add_argument("transcript", help="Path to transcript JSONL file")
    parser.add_argument("--id", required=True, help="Output ID (directory name)")
    parser.add_argument("--cwd", help="Override working directory detection")
    args = parser.parse_args()

    result = extract_docs(args.transcript, args.id, args.cwd)

    print(json.dumps(result, indent=2))
    if result["files_extracted"] == 0:
        print("WARNING: No .claude/ files extracted", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
