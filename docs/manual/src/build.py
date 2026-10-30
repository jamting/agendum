"""Builds docs/manual/index.html from template.html and the captured screens.

    MIX_ENV=test mix run docs/manual/src/capture_screens.exs   # screens/*.txt, ../screens/*.png
    python3 docs/manual/src/build.py                           # ../index.html

In the template, {{name}} is replaced by the picture ../screens/name.png,
the whole 80x25 screen in Agenda's colours, every screen the same size
(meeting 2026-10-28-2214, § 5). Its alternative text is the control panel's two
lines from screens/name.txt, which say what the screen shows.
"""

import html
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCREENS = os.path.join(HERE, "screens")
PICTURES = os.path.join(HERE, "..", "screens")


def lines_of(name):
    path = os.path.join(SCREENS, name + ".txt")
    if not os.path.exists(path) or not os.path.exists(os.path.join(PICTURES, name + ".png")):
        sys.exit(f"screen {name!r}: no screens/{name}.txt or ../screens/{name}.png")
    return open(path).read().split("\n")


def screen(match):
    name = match.group(1)
    panel = " · ".join(" ".join(line.split()) for line in lines_of(name)[0:2] if line.strip())
    alt = html.escape("Agendum's screen: " + panel)
    return (f'<!-- screen: {name} -->\n<img class="screen" src="screens/{name}.png" '
            f'width="720" height="400" alt="{alt}">')


def main():
    template = open(os.path.join(HERE, "template.html")).read()
    page = re.sub(r"\{\{([\w-]+)\}\}", screen, template)
    links = set(re.findall(r'href="#([\w-]+)"', page))
    anchors = set(re.findall(r'id="([\w-]+)"', page))
    if links - anchors:
        sys.exit(f"links without anchors: {sorted(links - anchors)}")
    target = os.path.join(HERE, "..", "index.html")
    open(target, "w").write(page)
    print(f"wrote {os.path.normpath(target)}: {page.count('<img class=\"screen\"')} screens")


if __name__ == "__main__":
    main()
