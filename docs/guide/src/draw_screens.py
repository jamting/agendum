"""Draws the user guide's screens as pictures (meeting 2026-10-28-2214, § 5).

    python3 docs/guide/src/draw_screens.py     # src/screens/*.txt -> ../screens/*.png

The guide's screens are mock-ups of Piglet's party file, written by hand in
src/screens/NAME.txt as the screen's lines, with Agenda's colours marked as
the old HTML marked them: <span class="t"> white on blue (the control panel and
the key bar), <span class="h"> blue (a section head), <span class="c"> white on
red (the highlight). Each is drawn as the whole 80x25 screen, the key bar at
the bottom as the program has it, by the renderer the manual and the
screenshots use (tools/screenshots/render.swift; macOS only), at twice
720x400 for sharp text on a high-density display. The page shows
<img class="screen" src="screens/NAME.png">.
"""

import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
SOURCES = os.path.join(HERE, "screens")
PICTURES = os.path.join(HERE, "..", "screens")
RENDERER = os.path.join(ROOT, "tmp", "render-screen")
SWIFT = os.path.join(ROOT, "tools", "screenshots", "render.swift")

# Agenda 2.0's colours on a VGA screen (the program's classic theme)
PLAIN = ("000000", "aaaaaa")
STYLES = {"t": ("ffffff", "0000aa"), "h": ("0000aa", "aaaaaa"), "c": ("ffffff", "aa0000")}


def segments(line):
    """A marked-up line as (foreground, background, text) runs, 80 wide."""
    runs, pos, width = [], 0, 0
    for m in re.finditer(r'<span class="(\w)">(.*?)</span>', line):
        if m.start() > pos:
            runs.append((*PLAIN, line[pos : m.start()]))
        runs.append((*STYLES[m.group(1)], m.group(2)))
        pos = m.end()
    runs.append((*PLAIN, line[pos:]))
    runs = [r for r in runs if r[2]]
    width = sum(len(r[2]) for r in runs)
    if width < 80:
        # a control panel or key bar line runs on in its colour, the body in grey
        fill = runs[-1][:2] if runs and runs[-1][:2] == STYLES["t"] and width >= 79 else PLAIN
        runs.append((*fill, " " * (80 - width)))
    return runs


def draw(name):
    lines = open(os.path.join(SOURCES, name + ".txt")).read().rstrip("\n").split("\n")
    # the key bar is the last two lines; the body is padded to fill 25 rows
    screen = lines[:-2] + [""] * (25 - len(lines)) + lines[-2:]
    cells = os.path.join(PICTURES, name + ".cells")
    with open(cells, "w") as f:
        f.write("\n".join("\x1f".join("\t".join(r) for r in segments(l)) for l in screen))
    subprocess.run([RENDERER, cells, os.path.join(PICTURES, name + ".png"), "2"], check=True)
    os.remove(cells)


def main():
    if not os.path.exists(RENDERER) or os.path.getmtime(RENDERER) < os.path.getmtime(SWIFT):
        os.makedirs(os.path.dirname(RENDERER), exist_ok=True)
        subprocess.run(["swiftc", "-O", SWIFT, "-o", RENDERER], check=True)
    os.makedirs(PICTURES, exist_ok=True)
    names = sorted(f[:-4] for f in os.listdir(SOURCES) if f.endswith(".txt"))
    for name in names:
        draw(name)
    print(f"drew {len(names)} screens in {os.path.normpath(PICTURES)}")


if __name__ == "__main__":
    sys.exit(main())
