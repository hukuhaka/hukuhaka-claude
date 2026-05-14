#!/usr/bin/env python3
"""Stop hook: parse the last assistant turn for <ltm-record> blocks and
write each one as an autonomous L3 entry.

Contract (documented in using-hukuhaka-ltm/SKILL.md):

    <ltm-record kind="decision" title="We chose X over Y" supersedes="id1,id2">
    Body of the entry — the reason, the context, anything future-you
    would need.
    </ltm-record>

`kind` and `title` attributes are required; `supersedes` is optional.
Multiple blocks per turn are allowed. The hook calls append-entry.py
--autonomous for each match and accumulates the resulting file paths
to .claude/ltm/.session-digest for the next session's SessionStart inject
to surface.

This hook is the *autonomy mechanism for L3*. The IRON-LAW in
ltm-append/SKILL.md still governs manual user-driven appends; that path
is unchanged. The two mechanisms are deliberately separated — the marker
block makes auto-record explicit and visible (Claude emits it, user can
see it in the same turn), so silent unilateral appends remain impossible.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path


RECORD_RE = re.compile(
    r"<ltm-record\b([^>]*)>(.*?)</ltm-record>", re.DOTALL | re.IGNORECASE
)
ATTR_RE = re.compile(r'(\w+)="([^"]*)"')


def parse_attrs(attr_str: str) -> dict[str, str]:
    return dict(ATTR_RE.findall(attr_str))


MAX_MARKERS_PER_TURN = 5
PER_APPEND_TIMEOUT_S = 5


def find_last_assistant_text(transcript_path: str) -> tuple[str | None, str]:
    """Return (text, uuid) of the most recent assistant text message.

    UUID is used by the caller to dedup: Stop fires multiple times per
    session (once per turn, plus on stop_hook_active continuations).
    Cursoring on the message uuid prevents the same `<ltm-record>` block
    from being re-written on each fire.
    """
    try:
        with open(transcript_path, encoding="utf-8", errors="ignore") as f:
            lines = f.readlines()
    except OSError:
        return None, ""
    for line in reversed(lines):
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except Exception:
            continue
        if obj.get("type") != "assistant":
            continue
        msg = obj.get("message", {})
        content = msg.get("content", [])
        text_parts: list[str] = []
        if isinstance(content, list):
            for part in content:
                if isinstance(part, dict) and part.get("type") == "text":
                    text_parts.append(part.get("text", ""))
        elif isinstance(content, str):
            text_parts.append(content)
        if text_parts:
            return "\n".join(text_parts), obj.get("uuid", "")
    return None, ""


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0

    # Hard guard against Stop-hook-triggered continuation re-fires.
    if payload.get("stop_hook_active") is True:
        return 0

    transcript_path = payload.get("transcript_path")
    if not transcript_path or not os.path.isfile(transcript_path):
        return 0

    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())
    plugin_root = os.environ.get("CLAUDE_PLUGIN_ROOT", "")
    if not plugin_root:
        return 0

    append_helper = Path(plugin_root) / "scripts" / "append-entry.py"
    if not append_helper.is_file():
        return 0

    ltm_dir = Path(project_dir) / ".claude" / "ltm"
    if not (ltm_dir / "CLAUDE.md").is_file():
        return 0  # LTM not bootstrapped in this project

    last_text, last_uuid = find_last_assistant_text(transcript_path)
    if not last_text:
        return 0

    # UUID cursor: per-session file storing the last processed assistant
    # message uuid. If this turn was already processed (Stop re-fire on
    # the same turn, or a stale transcript scan), bail.
    cursor_path = ltm_dir / ".stop-cursor"
    try:
        prev_uuid = cursor_path.read_text(encoding="utf-8").strip() if cursor_path.exists() else ""
    except OSError:
        prev_uuid = ""
    if last_uuid and last_uuid == prev_uuid:
        return 0

    matches = RECORD_RE.findall(last_text)
    if not matches:
        return 0

    # Cap markers per turn — protects against a single overloaded reply
    # stalling the Stop hook past Claude Code's hook timeout budget.
    matches = matches[:MAX_MARKERS_PER_TURN]

    digest_path = ltm_dir / ".session-digest"
    written: list[tuple[str, str, str]] = []
    for attr_str, body in matches:
        attrs = parse_attrs(attr_str)
        kind = attrs.get("kind", "auto-record").strip() or "auto-record"
        title = attrs.get("title", "").strip()
        supersedes = attrs.get("supersedes", "").strip()
        if not title:
            # Fall back to first line of body
            first_line = body.strip().splitlines()[0] if body.strip() else "auto-record"
            title = first_line[:80]
        body_text = body.strip()
        if not body_text:
            continue
        cmd = [
            "python3",
            str(append_helper),
            "--kind", kind,
            "--title", title,
            "--autonomous",
            "--target-dir", str(ltm_dir),
        ]
        if supersedes:
            cmd.extend(["--supersedes", supersedes])
        try:
            result = subprocess.run(
                cmd,
                input=body_text,
                capture_output=True,
                text=True,
                cwd=project_dir,
                check=False,
                timeout=PER_APPEND_TIMEOUT_S,
            )
        except Exception:
            continue
        if result.returncode == 0:
            path = result.stdout.strip()
            if path:
                written.append((kind, title, path))

    if written:
        try:
            with open(digest_path, "a", encoding="utf-8") as f:
                for kind, title, path in written:
                    f.write(f"- [{kind}] {title} → {path}\n")
        except OSError:
            pass

        # Surface a hook-level systemMessage so the user sees what was
        # auto-recorded in the same turn, not just on the next session.
        # Per plugin-guide:agents-and-hooks.md:398, top-level hooks
        # (Stop included) can return systemMessage for a user-visible
        # note. This is the enforcement channel: Claude cannot suppress
        # or rephrase it.
        plural = "y" if len(written) == 1 else "ies"
        lines = [f"[hukuhaka-ltm] auto-recorded {len(written)} L3 entr{plural}:"]
        for kind, title, path in written:
            lines.append(f"  · [{kind}] {title} → {Path(path).name}")
        try:
            sys.stdout.write(json.dumps({"systemMessage": "\n".join(lines)}))
            sys.stdout.flush()
        except OSError:
            pass

    # Advance the dedup cursor regardless of write success: if we touched
    # this turn at all, we should not re-touch it on a Stop re-fire.
    if last_uuid:
        try:
            cursor_path.write_text(last_uuid, encoding="utf-8")
        except OSError:
            pass

    return 0


if __name__ == "__main__":
    sys.exit(main())
