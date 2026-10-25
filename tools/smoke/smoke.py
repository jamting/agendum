#!/usr/bin/env python3
"""Smoke-test Agendum in a real pseudo-terminal: send keys, print the screen.

The unit tests drive `Agendum.TUI.Update` directly; this drives the whole
program (raw mode, key decoding, drawing) the way a terminal does. A small
built-in screen emulator turns the program's output back into text, so no
packages beyond Python's own are needed.

Sandboxed on purpose (CLAUDE.md, "Testing the real terminal"): the child
gets a scratch XDG_CONFIG_HOME and XDG_STATE_HOME, no AGENDUM_LOG, and
SSH_CONNECTION set so sounds ring the bell instead of playing aloud. A FILE
given with --file is copied into the scratch folder first, so a save in the
smoke test never touches the original.

Each key waits for its effect: the screen to change (up to --key-wait
seconds; a key that changes nothing costs that wait), then to stay the same
for --settle seconds, so keys sent back to back read the same every run. At
the start it waits for the splash screen to go by itself, so the first key
is not spent on it.

Usage:
    tools/smoke/smoke.py [options] [KEY ...]

Keys (case does not matter for names):
    F1 … F12, ALT-F1 … ALT-F10, SHIFT-F1 … SHIFT-F10, CTRL-F1 … CTRL-F10
    ESC ENTER TAB SHIFT-TAB BS DEL INS UP DOWN LEFT RIGHT HOME END
    PGUP PGDN SPACE, CTRL-UP and the other CTRL-arrows
    CTRL-x, ALT-x          a control or ALT letter (ALT is ESC + letter)
    text:Buy milk          typed as text (or any word that is not a name)
    wait:1.5               wait that many seconds
    snap                   print the screen now (the end always prints it)

Examples:
    tools/smoke/smoke.py F10                    # the demo file, the menu
    tools/smoke/smoke.py --size 100x30 --highlight DOWN DOWN F2
    tools/smoke/smoke.py --file my.agendum text:Call Bob ENTER snap ALT-Z
    tools/smoke/smoke.py --args "--rabbit --theme mono" F1

Without --file or --args the demo file opens (--demo); with --args alone,
only those flags are passed (no flags at all: a new, untitled file).

Exit status 1 if the program exited by itself (a crash, usually); its last
screen and output are printed.
"""

import argparse
import fcntl
import os
import pty
import re
import select
import shlex
import shutil
import signal
import struct
import sys
import tempfile
import termios
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

NAMED = {
    "ESC": "\x1b",
    "ENTER": "\r",
    "TAB": "\t",
    "SHIFT-TAB": "\x1b[Z",
    "BS": "\x7f",
    "BACKSPACE": "\x7f",
    "DEL": "\x1b[3~",
    "INS": "\x1b[2~",
    "UP": "\x1b[A",
    "DOWN": "\x1b[B",
    "RIGHT": "\x1b[C",
    "LEFT": "\x1b[D",
    "HOME": "\x1b[H",
    "END": "\x1b[F",
    "PGUP": "\x1b[5~",
    "PGDN": "\x1b[6~",
    "SPACE": " ",
}

# the xterm sequences Agendum.TUI.Terminal.Keys reads
F_CODES = {1: 11, 2: 12, 3: 13, 4: 14, 5: 15, 6: 17, 7: 18, 8: 19, 9: 20, 10: 21, 11: 23, 12: 24}
ARROWS = {"UP": "A", "DOWN": "B", "RIGHT": "C", "LEFT": "D", "HOME": "H", "END": "F"}


def key_bytes(token):
    """The bytes a terminal sends for one KEY token, or None for wait/snap."""
    if token.startswith("text:"):
        return token[5:]
    name = token.upper()
    if name in NAMED:
        return NAMED[name]
    m = re.fullmatch(r"(ALT-|SHIFT-|CTRL-)?F(\d+)", name)
    if m and int(m.group(2)) in F_CODES:
        code = F_CODES[int(m.group(2))]
        mod = {"ALT-": ";3", "SHIFT-": ";2", "CTRL-": ";5"}.get(m.group(1) or "", "")
        return f"\x1b[{code}{mod}~"
    m = re.fullmatch(r"CTRL-(UP|DOWN|RIGHT|LEFT|HOME|END)", name)
    if m:
        return f"\x1b[1;5{ARROWS[m.group(1)]}"
    if name in ("CTRL-PGUP", "CTRL-PGDN"):
        return "\x1b[5;5~" if name == "CTRL-PGUP" else "\x1b[6;5~"
    m = re.fullmatch(r"CTRL-([A-Z])", name)
    if m:
        return chr(ord(m.group(1)) - 64)
    m = re.fullmatch(r"ALT-(.)", token, re.IGNORECASE)
    if m:
        return "\x1b" + m.group(1).lower()
    return token


class Screen:
    """Just enough of a VT100 for Agendum's output: cursor moves, clears and
    colours (kept per cell, to find highlighted text)."""

    def __init__(self, cols, rows):
        self.cols, self.rows = cols, rows
        self.cells = [[" "] * cols for _ in range(rows)]
        self.bg = [[None] * cols for _ in range(rows)]
        self.r = self.c = 0
        self.cur_bg = None
        self.reverse = False
        self.bells = 0
        self.pending = b""

    def feed(self, data):
        text = (self.pending + data).decode("utf-8", errors="ignore")
        # keep an unfinished escape sequence for the next read
        cut = text.rfind("\x1b")
        if cut != -1 and not re.match(r"\x1b(\[[0-9;?]*[A-Za-z~]|[^\[])", text[cut:]):
            self.pending, text = text[cut:].encode(), text[:cut]
        else:
            self.pending = b""
        i = 0
        while i < len(text):
            ch = text[i]
            if ch == "\x1b":
                m = re.match(r"\x1b\[([0-9;?]*)([A-Za-z~])", text[i:])
                if m:
                    self.csi(m.group(1), m.group(2))
                    i += m.end()
                else:
                    i += 2
                continue
            if ch == "\r":
                self.c = 0
            elif ch == "\n":
                self.r = min(self.r + 1, self.rows - 1)
            elif ch == "\b":
                self.c = max(self.c - 1, 0)
            elif ch == "\a":
                self.bells += 1
            elif ch >= " ":
                if self.r < self.rows and self.c < self.cols:
                    self.cells[self.r][self.c] = ch
                    self.bg[self.r][self.c] = ("rev", self.cur_bg) if self.reverse else self.cur_bg
                self.c += 1
            i += 1

    def csi(self, params, final):
        if params.startswith("?"):
            return
        nums = [int(p) if p else 0 for p in params.split(";")] if params else []
        n = (nums or [1])[0] or 1
        if final in "Hf":
            self.r = min(max((nums[0] if nums else 1) - 1, 0), self.rows - 1)
            self.c = min(max((nums[1] if len(nums) > 1 else 1) - 1, 0), self.cols - 1)
        elif final == "J":
            if (nums or [0])[0] in (2, 3):
                self.cells = [[" "] * self.cols for _ in range(self.rows)]
                self.bg = [[None] * self.cols for _ in range(self.rows)]
        elif final == "K":
            for c in range(self.c, self.cols):
                self.cells[self.r][c] = " "
        elif final == "A":
            self.r = max(self.r - n, 0)
        elif final == "B":
            self.r = min(self.r + n, self.rows - 1)
        elif final == "C":
            self.c = min(self.c + n, self.cols - 1)
        elif final == "D":
            self.c = max(self.c - n, 0)
        elif final == "G":
            self.c = min(n - 1, self.cols - 1)
        elif final == "m":
            self.sgr(nums or [0])

    def sgr(self, nums):
        i = 0
        while i < len(nums):
            p = nums[i]
            if p == 0:
                self.cur_bg, self.reverse = None, False
            elif p == 7:
                self.reverse = True
            elif p == 27:
                self.reverse = False
            elif 40 <= p <= 47 or 100 <= p <= 107:
                self.cur_bg = p
            elif p == 49:
                self.cur_bg = None
            elif p in (38, 48) and i + 1 < len(nums):
                skip = 2 if nums[i + 1] == 5 else 4
                if p == 48:
                    self.cur_bg = tuple(nums[i : i + skip + 1])
                i += skip
            i += 1

    def text(self):
        return "\n".join("".join(row).rstrip() for row in self.cells)

    def highlights(self):
        """Runs of cells whose background is not the screen's usual one."""
        counts = {}
        for row in self.bg:
            for b in row:
                counts[b] = counts.get(b, 0) + 1
        usual = max(counts, key=counts.get)
        runs = []
        for r, row in enumerate(self.bg):
            c = 0
            while c < self.cols:
                if row[c] != usual:
                    start, b = c, row[c]
                    while c < self.cols and row[c] == b:
                        c += 1
                    text = "".join(self.cells[r][start:c]).strip()
                    if text:
                        runs.append((r + 1, start + 1, c, text))
                else:
                    c += 1
        return runs


def print_screen(screen, label, highlight):
    width = screen.cols
    print(f"┌─ {label} " + "─" * max(width - len(label) - 3, 0))
    for line in screen.text().split("\n"):
        print(f"│{line}")
    print("└" + "─" * width)
    if highlight:
        for r, c1, c2, text in screen.highlights():
            print(f"  highlight row {r}, cols {c1}-{c2}: {text}")
    if screen.bells:
        print(f"  bells so far: {screen.bells}")


def read_until_quiet(fd, screen, quiet, limit):
    """Feeds output to the screen until none comes for `quiet` seconds.
    Returns False if the program has exited."""
    deadline = time.time() + limit
    last = time.time()
    while time.time() < deadline:
        ready, _, _ = select.select([fd], [], [], 0.05)
        if ready:
            try:
                data = os.read(fd, 65536)
            except OSError:
                return False
            if not data:
                return False
            screen.feed(data)
            last = time.time()
        elif time.time() - last >= quiet:
            return True
    return True


def wait_for_change(fd, screen, before, limit):
    """Feeds output until the screen's text differs from `before`, or
    `limit` seconds pass (a key that changes nothing on screen). Returns
    False if the program has exited."""
    deadline = time.time() + limit
    while time.time() < deadline:
        if screen.text() != before:
            return True
        if not read_until_quiet(fd, screen, 0.05, 0.1):
            return False
    return True


def settle(fd, screen, quiet, limit):
    """Waits until the screen's text has stayed the same for `quiet`
    seconds, as agenda_driver.idle() does for Agenda: output that only
    repaints the same text (a cursor move) does not count as a change.
    Returns False if the program has exited."""
    deadline = time.time() + limit
    last_text = screen.text()
    last_change = time.time()
    while time.time() < deadline:
        if not read_until_quiet(fd, screen, 0.05, 0.1):
            return False
        text = screen.text()
        if text != last_text:
            last_text, last_change = text, time.time()
        elif time.time() - last_change >= quiet:
            return True
    return True


# The splash screen (R52) takes the first key to go away, and goes by
# itself after five seconds; keys sent while it shows would be lost.
SPLASH = "W O L ' S   A G E N D U M"


def main():
    parser = argparse.ArgumentParser(
        description=__doc__.split("\n\n")[0],
        epilog="See the top of this file for the key names.",
    )
    parser.add_argument("keys", nargs="*", help="keys to send, in order")
    parser.add_argument("--size", default="80x25", help="COLSxROWS (default 80x25)")
    parser.add_argument("--file", help="open a copy of this .agendum or .AG file")
    parser.add_argument("--args", default=None, help='Agendum flags, e.g. "--rabbit --theme mono" (instead of --demo)')
    parser.add_argument("--escript", action="store_true", help="run ./agendum, not mix run")
    parser.add_argument("--settle", type=float, default=0.4, help="seconds the screen must stay the same after a key")
    parser.add_argument("--key-wait", type=float, default=1.5, help="seconds to wait for a key to change the screen")
    parser.add_argument("--highlight", action="store_true", help="list highlighted text")
    parser.add_argument("--each", action="store_true", help="print the screen after every key")
    opts = parser.parse_args()

    cols, rows = (int(x) for x in opts.size.lower().split("x"))
    scratch = tempfile.mkdtemp(prefix="agendum-smoke-")
    app_args = shlex.split(opts.args) if opts.args else []
    if opts.file:
        copy = os.path.join(scratch, os.path.basename(opts.file))
        shutil.copy(opts.file, copy)
        app_args.append(copy)
    elif not opts.args:
        app_args.append("--demo")

    if opts.escript:
        command = [os.path.join(ROOT, "agendum"), *app_args]
    else:
        quoted = ", ".join('"' + a.replace("\\", "\\\\").replace('"', '\\"') + '"' for a in app_args)
        command = ["mix", "run", "-e", f"Agendum.CLI.main([{quoted}])"]

    env = dict(os.environ)
    env.pop("AGENDUM_LOG", None)
    env.pop("COLORTERM", None)
    env.update(
        XDG_CONFIG_HOME=os.path.join(scratch, "config"),
        XDG_STATE_HOME=os.path.join(scratch, "state"),
        SSH_CONNECTION="smoke-test",
        TERM="xterm-256color",
        COLUMNS=str(cols),
        LINES=str(rows),
    )

    pid, fd = pty.fork()
    if pid == 0:
        os.chdir(ROOT)
        os.execvpe(command[0], command, env)

    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
    screen = Screen(cols, rows)
    alive = True
    try:
        # the first draw can wait for a compile: allow a minute of silence
        start = time.time()
        while alive and not screen.text().strip() and time.time() - start < 60:
            alive = read_until_quiet(fd, screen, opts.settle, 60)
        alive = alive and settle(fd, screen, 1.0, 10)
        # wait for the splash to go by itself rather than spend a key on it
        start = time.time()
        while alive and SPLASH in screen.text() and time.time() - start < 10:
            alive = read_until_quiet(fd, screen, 0.1, 0.5)
        alive = alive and settle(fd, screen, opts.settle, 10)
        if opts.each:
            print_screen(screen, "start", opts.highlight)

        for token in opts.keys:
            if not alive:
                break
            if token.lower().startswith("wait:"):
                time.sleep(float(token[5:]))
                alive = settle(fd, screen, opts.settle, 30)
                continue
            if token.lower() == "snap":
                print_screen(screen, "snap", opts.highlight)
                continue
            # Each key waits for its effect: first for the screen to change
            # (a slow key may print nothing for a while), then for it to
            # settle, so the next key never lands on a half-drawn screen.
            before = screen.text()
            os.write(fd, key_bytes(token).encode())
            alive = wait_for_change(fd, screen, before, opts.key_wait)
            alive = alive and settle(fd, screen, opts.settle, 30)
            if opts.each:
                print_screen(screen, f"after {token}", opts.highlight)

        if not opts.each or not alive:
            print_screen(screen, "end" if alive else "program exited", opts.highlight)
    finally:
        if alive:
            os.kill(pid, signal.SIGKILL)
        try:
            os.waitpid(pid, 0)
        except ChildProcessError:
            pass
        shutil.rmtree(scratch, ignore_errors=True)

    sys.exit(0 if alive else 1)


if __name__ == "__main__":
    main()
