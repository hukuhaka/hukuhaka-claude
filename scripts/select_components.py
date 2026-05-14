#!/usr/bin/env python3
"""
Universal arrow-key checkbox selector. Pure Python stdlib.

Reads a TSV discovery file (NAME<TAB>TYPE<TAB>DESC<TAB>DEFAULT_ON)
and a CSV of pre-checked names (= currently installed). Renders a TUI on
/dev/tty (so it works inside `curl ... | bash` where stdin is the
script body) and writes selected names to stdout, one per line.

Items are grouped by TYPE (plugin / skill / feature / template). Group
headers are navigable; toggling a group header toggles every member.

Per-item state vs the original (currently-installed) snapshot is shown
inline:
  install (was off, now on)   → green '+'
  keep    (was on,  now on)   → no marker
  remove  (was on,  now off)  → red '-'
  skip    (was off, now off)  → dim

When the user activates [ Apply ] and any items would be removed, a
confirm screen lists every operation and requires explicit Confirm.
Pure-install applies (no removes) skip the confirm.

Exit 0 = applied, 1 = cancelled.

Keys:
  ↑/↓/k/j        navigate
  Space / Enter  toggle item; toggle-all on group header; activate on button
  a              global toggle-all
  q / Esc        quick cancel
"""

import json
import os
import sys
import termios
import tty
import signal


CHECKED = "[x]"
UNCHECKED = "[ ]"

GROUP_FULL = "[✓]"
GROUP_PARTIAL = "[▪]"
GROUP_EMPTY = "[ ]"

ESC = "\x1b"
CSI = ESC + "["
RESET = CSI + "0m"
INVERT = CSI + "7m"
DIM = CSI + "2m"
BOLD = CSI + "1m"
GREEN = CSI + "32m"
RED = CSI + "31m"
YELLOW = CSI + "33m"
HIDE_CURSOR = CSI + "?25l"
SHOW_CURSOR = CSI + "?25h"
CLEAR_BELOW = CSI + "J"


GROUP_DEFS = [
    ("plugin",   "Plugins",  "~/.claude/plugins/hukuhaka-plugin/<name>/"),
    ("skill",    "Skills",   "~/.claude/skills/<name>/"),
    ("feature",  "Features", "~/.claude/settings.json (+statusline.sh)"),
    ("template", "Template", "~/.claude/CLAUDE.md"),
]


def read_discovery(path):
    items = []
    with open(path) as f:
        for line in f:
            line = line.rstrip("\n")
            if not line:
                continue
            parts = line.split("\t")
            while len(parts) < 4:
                parts.append("")
            items.append({
                "name": parts[0],
                "type": parts[1],
                "desc": parts[2],
                "default": parts[3] == "true",
            })
    return items


def load_preflight(path, item_names):
    """Parse preflight JSON, return (host_status, component_reqs).

    host_status: dict req_name -> bool found
    component_reqs: dict component_name -> list of (req_name, found_bool, required_bool)
    """
    if not path or not os.path.isfile(path):
        return {}, {}
    try:
        with open(path) as f:
            data = json.load(f)
    except Exception:
        return {}, {}
    host_status = {}
    component_reqs = {}
    name_set = set(item_names)
    for r in data.get("requirements", []):
        host_status[r["name"]] = bool(r.get("found", False))
        for needer in r.get("needed_by", []):
            if needer in name_set:
                component_reqs.setdefault(needer, []).append(
                    (r["name"], bool(r.get("found", False)), bool(r.get("required", False)))
                )
    return host_status, component_reqs


def main():
    if len(sys.argv) < 2:
        print("usage: select_components.py <discovery_tsv> [prechecked_csv] [preflight_json]", file=sys.stderr)
        sys.exit(2)

    discovery_path = sys.argv[1]
    prechecked = set()
    if len(sys.argv) > 2 and sys.argv[2]:
        prechecked = {n for n in sys.argv[2].split(",") if n}

    preflight_path = sys.argv[3] if len(sys.argv) > 3 else ""

    items = read_discovery(discovery_path)
    if not items:
        print("no components discovered", file=sys.stderr)
        sys.exit(2)

    state = [it["name"] in prechecked for it in items]
    original = list(state)

    host_status, component_reqs = load_preflight(preflight_path, [it["name"] for it in items])

    groups = []
    for key, name, path in GROUP_DEFS:
        member_indices = [i for i, it in enumerate(items) if it["type"] == key]
        if member_indices:
            groups.append({"key": key, "name": name, "path": path, "members": member_indices})

    positions = []
    for g_idx, g in enumerate(groups):
        positions.append(("group", g_idx))
        for it_idx in g["members"]:
            positions.append(("item", it_idx))
    APPLY_POS = len(positions); positions.append(("apply",))
    QUIT_POS = len(positions);  positions.append(("quit",))
    n_positions = len(positions)

    try:
        tty_in = open("/dev/tty", "rb", buffering=0)
        tty_out = open("/dev/tty", "w")
    except OSError as e:
        print(f"Error: cannot open /dev/tty: {e}", file=sys.stderr)
        sys.exit(2)

    fd = tty_in.fileno()
    old_attrs = termios.tcgetattr(fd)

    cursor = 0
    cancelled = False
    apply_now = False

    # Confirm-screen state
    mode = "select"  # or "confirm"
    confirm_cursor = 0  # 0 = Confirm, 1 = Back

    def write(s):
        tty_out.write(s)
        tty_out.flush()

    def diff_kind(i):
        was = original[i]
        now = state[i]
        if was and now:
            return "keep"
        if not was and now:
            return "install"
        if was and not now:
            return "remove"
        return "skip"

    def diff_summary():
        n_install = n_remove = n_keep = 0
        for i in range(len(items)):
            k = diff_kind(i)
            if k == "install": n_install += 1
            elif k == "remove": n_remove += 1
            elif k == "keep": n_keep += 1
        return n_install, n_remove, n_keep

    def render_lines_select():
        # 2 header (title + help)
        # + 1 host status bar (if preflight loaded) + 1 blank after
        # + 1 blank
        # + per-group: 1 header + N items + 1 blank
        # + 1 button row + 1 status line + 1 trailing blank
        host_bar = 2 if host_status else 0
        return 2 + host_bar + 1 + sum(1 + len(g["members"]) + 1 for g in groups) + 3

    def render_lines_confirm():
        n_install, n_remove, _keep = diff_summary()
        n_ops = n_install + n_remove
        # 2 header + 1 blank + 1 "summary heading" + 1 blank
        # + n_ops op lines + 1 blank
        # + 1 button row + 1 trailing blank
        return 2 + 1 + 1 + 1 + n_ops + 1 + 1 + 1

    last_render_lines = [0]  # mutable holder for trampoline up-count

    def render(initial=False):
        if not initial:
            write(CSI + f"{last_render_lines[0]}F")
        else:
            write("\r")
        write(CLEAR_BELOW)
        if mode == "select":
            _render_select()
            last_render_lines[0] = render_lines_select()
        else:
            _render_confirm()
            last_render_lines[0] = render_lines_confirm()

    def group_state(g):
        member_states = [state[i] for i in g["members"]]
        if all(member_states):
            return GROUP_FULL
        if any(member_states):
            return GROUP_PARTIAL
        return GROUP_EMPTY

    def toggle_group(g):
        target = not all(state[i] for i in g["members"])
        for i in g["members"]:
            state[i] = target

    def _render_select():
        write(BOLD + "hukuhaka-claude — select components" + RESET + "\r\n")
        write(DIM + "  ↑/↓ navigate • Space/Enter select • a toggle-all • q cancel" + RESET + "\r\n")

        if host_status:
            # Display host capability summary in a fixed order — most useful first.
            order = ["python3", "bash", "curl", "tar", "jq", "git", "whiptail"]
            present = [n for n in order if n in host_status]
            extras = [n for n in host_status if n not in order]
            parts = []
            for name in present + sorted(extras):
                if host_status[name]:
                    parts.append(GREEN + f"✓ {name}" + RESET)
                else:
                    parts.append(RED + f"✗ {name}" + RESET)
            write("  " + DIM + "Host: " + RESET + "  ".join(parts) + "\r\n")
            write("\r\n")

        write("\r\n")

        for g_idx, g in enumerate(groups):
            g_check = group_state(g)
            on_count = sum(state[i] for i in g["members"])
            total = len(g["members"])
            head_left = f"  {g_check} {g['name']} ({on_count}/{total})"
            pad_to = 30
            pad = max(1, pad_to - len(head_left))
            head_path = f"→ {g['path']}"
            is_focused = positions[cursor] == ("group", g_idx)
            if is_focused:
                line = INVERT + f" {g_check} {g['name']} ({on_count}/{total}){' ' * pad}{head_path} " + RESET
                write(line + "\r\n")
            else:
                write(head_left + (" " * pad) + DIM + head_path + RESET + "\r\n")

            for it_idx in g["members"]:
                it = items[it_idx]
                kind = diff_kind(it_idx)
                check = CHECKED if state[it_idx] else UNCHECKED

                if kind == "install":
                    marker = GREEN + "+" + RESET
                    name_colored = GREEN + it["name"] + RESET
                elif kind == "remove":
                    marker = RED + "-" + RESET
                    name_colored = RED + it["name"] + RESET
                elif kind == "keep":
                    marker = " "
                    name_colored = it["name"]
                else:
                    marker = " "
                    name_colored = DIM + it["name"] + RESET

                desc_colored = DIM + it["desc"][:40] + RESET

                # Per-component req tags
                reqs = component_reqs.get(it["name"], [])
                tag_parts = []
                for req_name, found, _required in reqs:
                    if found:
                        tag_parts.append(GREEN + f"{req_name}✓" + RESET)
                    else:
                        tag_parts.append(RED + f"{req_name}✗" + RESET)
                req_tag = ""
                if tag_parts:
                    req_tag = "  " + DIM + "needs: " + RESET + " ".join(tag_parts)

                name_pad = max(1, 18 - len(it["name"]))
                row = f"   {marker} {check} {name_colored}{' ' * name_pad} {desc_colored}{req_tag}"
                if positions[cursor] == ("item", it_idx):
                    # Plain (no per-req colors) + INVERT for clean highlight
                    raw_marker = "+" if kind == "install" else ("-" if kind == "remove" else " ")
                    plain_reqs = ""
                    if reqs:
                        plain_parts = [
                            f"{n}{'✓' if f else '✗'}" for n, f, _ in reqs
                        ]
                        plain_reqs = "  needs: " + " ".join(plain_parts)
                    row = INVERT + f"  {raw_marker} {check} {it['name']:<18} {it['desc'][:40]}{plain_reqs} " + RESET
                write(row + "\r\n")
            write("\r\n")

        n_install, n_remove, n_keep = diff_summary()
        apply_label = "[ Apply ]"
        quit_label = "[ Quit ]"
        apply_str = INVERT + apply_label + RESET if cursor == APPLY_POS else apply_label
        quit_str = INVERT + quit_label + RESET if cursor == QUIT_POS else quit_label
        write("  " + apply_str + "    " + quit_str + "\r\n")

        # Live status line
        if n_install == 0 and n_remove == 0:
            status = DIM + "(no changes)" + RESET
        else:
            parts = []
            if n_install:
                parts.append(GREEN + f"+{n_install} install" + RESET)
            if n_remove:
                parts.append(RED + f"-{n_remove} remove" + RESET)
            if n_keep:
                parts.append(DIM + f"{n_keep} keep" + RESET)
            status = "Changes: " + "  ".join(parts)

        # Missing-host-reqs warning for currently selected items
        if component_reqs:
            missing = set()
            for i, on in enumerate(state):
                if not on:
                    continue
                for req_name, found, required in component_reqs.get(items[i]["name"], []):
                    if required and not found:
                        missing.add(req_name)
            if missing:
                status += "  " + RED + "Missing: " + ",".join(sorted(missing)) + RESET

        write("  " + status + "\r\n")

    def _render_confirm():
        n_install, n_remove, _keep = diff_summary()
        write(BOLD + "hukuhaka-claude — confirm changes" + RESET + "\r\n")
        write(DIM + "  Review the operations below. Remove is destructive — files will be deleted." + RESET + "\r\n")
        write("\r\n")
        write(BOLD + f"  Apply changes ({n_install} install, {n_remove} remove):" + RESET + "\r\n")
        write("\r\n")
        for i, it in enumerate(items):
            k = diff_kind(i)
            if k == "install":
                write(f"    {GREEN}+ {it['name']:<18}{RESET} {DIM}install{RESET}\r\n")
            elif k == "remove":
                write(f"    {RED}- {it['name']:<18}{RESET} {RED}REMOVE — files will be deleted{RESET}\r\n")
        write("\r\n")
        confirm_label = "[ Confirm ]"
        back_label = "[ Back ]"
        confirm_str = INVERT + confirm_label + RESET if confirm_cursor == 0 else confirm_label
        back_str = INVERT + back_label + RESET if confirm_cursor == 1 else back_label
        write("  " + confirm_str + "    " + back_str + "\r\n")

    def restore():
        write(SHOW_CURSOR)
        try:
            termios.tcsetattr(fd, termios.TCSADRAIN, old_attrs)
        except Exception:
            pass

    def handle_sigint(signum, frame):
        nonlocal cancelled
        cancelled = True

    signal.signal(signal.SIGINT, handle_sigint)

    def activate_current():
        nonlocal apply_now, cancelled, mode, confirm_cursor
        kind = positions[cursor][0]
        if kind == "item":
            it_idx = positions[cursor][1]
            state[it_idx] = not state[it_idx]
        elif kind == "group":
            g_idx = positions[cursor][1]
            toggle_group(groups[g_idx])
        elif kind == "apply":
            n_install, n_remove, _keep = diff_summary()
            if n_install == 0 and n_remove == 0:
                # Nothing to do — let install.sh decide what to do with
                # an empty diff (currently: re-deploys same selection).
                apply_now = True
                return "stop"
            if n_remove > 0:
                mode = "confirm"
                confirm_cursor = 1  # default to Back (safer)
                return "continue"
            apply_now = True
            return "stop"
        elif kind == "quit":
            cancelled = True
            return "stop"
        return "continue"

    try:
        tty.setcbreak(fd)
        write(HIDE_CURSOR)
        render(initial=True)

        while True:
            if cancelled:
                break
            try:
                ch = tty_in.read(1)
            except Exception:
                cancelled = True
                break
            if not ch:
                cancelled = True
                break

            if mode == "confirm":
                if ch == b"\x1b":
                    seq2 = tty_in.read(1)
                    if seq2 != b"[":
                        # Esc → back to select
                        mode = "select"
                        render()
                        continue
                    seq3 = tty_in.read(1)
                    if seq3 in (b"A", b"B", b"C", b"D"):
                        confirm_cursor = (confirm_cursor + 1) % 2
                elif ch in (b"h", b"l", b"j", b"k"):
                    confirm_cursor = (confirm_cursor + 1) % 2
                elif ch == b" " or ch in (b"\r", b"\n"):
                    if confirm_cursor == 0:
                        apply_now = True
                        break
                    else:
                        mode = "select"
                elif ch in (b"q", b"Q"):
                    cancelled = True
                    break
                render()
                continue

            # mode == "select"
            if ch == b"\x1b":
                seq2 = tty_in.read(1)
                if seq2 != b"[":
                    cancelled = True
                    break
                seq3 = tty_in.read(1)
                if seq3 == b"A":
                    cursor = (cursor - 1) % n_positions
                elif seq3 == b"B":
                    cursor = (cursor + 1) % n_positions
            elif ch in (b"k", b"K"):
                cursor = (cursor - 1) % n_positions
            elif ch in (b"j", b"J"):
                cursor = (cursor + 1) % n_positions
            elif ch == b" " or ch in (b"\r", b"\n"):
                if activate_current() == "stop":
                    break
            elif ch in (b"a", b"A"):
                if not all(state):
                    state = [True] * len(items)
                else:
                    state = [False] * len(items)
            elif ch in (b"q", b"Q"):
                cancelled = True
                break

            render()
    finally:
        restore()

    if cancelled or not apply_now:
        sys.exit(1)

    selected = [items[i]["name"] for i, on in enumerate(state) if on]
    for name in selected:
        print(name)


if __name__ == "__main__":
    main()
