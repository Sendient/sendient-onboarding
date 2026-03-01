#!/usr/bin/env python3
"""Sendient AI — SREE Framework banner renderer.

Cross-platform, terminal-width-aware banner using Unicode box-drawing
characters and ANSI colour codes. Zero external dependencies.
"""

import os
import re
import shutil
import sys

_ANSI_RE = re.compile(r"\033\[[0-9;]*m")


def _visible_len(s):
    """Return the display width of *s* after stripping ANSI escapes."""
    return len(_ANSI_RE.sub("", s))


def _use_colour():
    """Determine whether to emit ANSI colour codes."""
    if os.environ.get("NO_COLOR"):
        return False
    if os.environ.get("TERM") == "dumb":
        return False
    if not hasattr(sys.stdout, "isatty") or not sys.stdout.isatty():
        return False
    return True


def _render_banner():
    width = shutil.get_terminal_size((80, 24)).columns
    width = max(50, min(width, 100))

    # Inner width is total width minus the two border characters
    inner = width - 2

    if _use_colour():
        DIM = "\033[2m"
        BOLD = "\033[1m"
        CYAN = "\033[36m"
        WHITE = "\033[37m"
        YELLOW = "\033[33m"
        RESET = "\033[0m"
    else:
        DIM = BOLD = CYAN = WHITE = YELLOW = RESET = ""

    def box_line(content=""):
        """Format a line inside the box with right-padding."""
        if not content:
            return f"{DIM}\u2502{RESET}{' ' * inner}{DIM}\u2502{RESET}"
        pad = inner - _visible_len(content)
        return f"{DIM}\u2502{RESET}{content}{' ' * max(pad, 0)}{DIM}\u2502{RESET}"

    top = f"{DIM}\u256d{'\u2500' * inner}\u256e{RESET}"
    bottom = f"{DIM}\u2570{'\u2500' * inner}\u256f{RESET}"

    lines = [
        "",
        top,
        box_line(f"  {BOLD}{CYAN}Sendient AI \u2014 SREE Framework{RESET}"),
        box_line(),
        box_line(f"  {BOLD}{YELLOW}/scope{RESET}    \u2192 Define what you want to achieve"),
        box_line(f"  {BOLD}{YELLOW}/refine{RESET}   \u2192 Clarify requirements & constraints"),
        box_line(f"  {BOLD}{YELLOW}/execute{RESET}  \u2192 Implement the solution"),
        box_line(f"  {BOLD}{YELLOW}/evaluate{RESET} \u2192 Review, confirm, document, merge"),
        box_line(),
        box_line(f"  {DIM}Start any session with {WHITE}/scope{DIM}, or pick up{RESET}"),
        box_line(f"  {DIM}where you left off with {WHITE}/refine{DIM}, or {WHITE}/execute{DIM}.{RESET}"),
        bottom,
    ]

    sys.stdout.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    _render_banner()
