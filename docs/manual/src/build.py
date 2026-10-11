"""Builds docs/manual/index.html from template.html and the captured screens.

    MIX_ENV=test mix run docs/manual/src/capture_screens.exs   # screens/*.txt
    python3 docs/manual/src/build.py                           # ../index.html

In the template, {{name}} is replaced by screens/name*.txt as a
<pre class="screen">: the title bar and key bar styled, section heads
highlighted, runs of blank lines shortened. {{name|box}} keeps the screen down
to the bottom of its box; {{name|rows:2-6,17-19}} keeps those lines (counted
from the title bar as line 1).
"""

import html
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCREENS = os.path.join(HERE, "screens")
HEADS = ["Garden", "Notices", "Friends and Relations"]


def lines_of(name):
    files = [f for f in os.listdir(SCREENS) if f.startswith(name) and f.endswith(".txt")]
    if len(files) != 1:
        sys.exit(f"screen {name!r}: found {files}")
    return open(os.path.join(SCREENS, files[0])).read().split("\n")


def screen(name, rows=None):
    lines = lines_of(name)
    title, body, keys = lines[0], lines[1:-1], lines[-1]
    if rows:
        body = [body[i - 2] for a, b in rows for i in range(a, b + 1) if 0 <= i - 2 < len(body)]
    out = []
    for line in body:
        if line.strip() == "" and out and out[-1].strip() == "":
            continue
        out.append(line)
    while out and out[-1].strip() == "":
        out.pop()

    def fmt(line):
        text = html.escape(line.rstrip(), quote=False)
        if any(re.match(r"^ " + re.escape(h) + r"\s{2,}", line) for h in HEADS):
            return '<span class="h">' + text + "</span>"
        return text

    bar = lambda s: '<span class="t">' + html.escape(s.ljust(80)[:80], quote=False) + "</span>"
    body = "\n".join([bar(title)] + [fmt(l) for l in out] + [bar(keys)])
    return f'<!-- screen: {name} -->\n<pre class="screen">{body}</pre>'


def box_rows(name):
    lines = lines_of(name)
    end = next((i for i, l in enumerate(lines) if "└" in l), len(lines) - 2)
    return [(2, end + 1)]


def expand(match):
    name, option = match.group(1), match.group(2)
    if option == "box":
        return screen(name, box_rows(name))
    if option and option.startswith("rows:"):
        ranges = [tuple(int(x) for x in r.split("-")) for r in option[5:].split(",")]
        return screen(name, ranges)
    return screen(name)


def main():
    template = open(os.path.join(HERE, "template.html")).read()
    page = re.sub(r"\{\{([\w-]+)(?:\|([\w:,-]+))?\}\}", expand, template)
    links = set(re.findall(r'href="#([\w-]+)"', page))
    anchors = set(re.findall(r'id="([\w-]+)"', page))
    if links - anchors:
        sys.exit(f"links without anchors: {sorted(links - anchors)}")
    target = os.path.join(HERE, "..", "index.html")
    open(target, "w").write(page)
    print(f"wrote {os.path.normpath(target)}: {page.count('<pre class=\"screen\">')} screens")


if __name__ == "__main__":
    main()
