# SPDX-License-Identifier: AGPL-3.0-only
"""Find documents that have drifted from the code (tidy-docs skill, step 2).

Run from the repository root:  python3 .claude/skills/tidy-docs/check_docs.py

Prints, per check, what looks stale. Every hit is a lead to look at, not a
verdict: a placeholder name (`Facade.Area`) or a test helper is fine.
"""
import glob
import os
import re

DOCS = (["README.md", "CONTRIBUTING.md", "CLAUDE.md"]
        + glob.glob("docs/*.md") + glob.glob("docs/plans/*.md") + glob.glob("docs/plans/archive/*.md")
        + glob.glob("docs/adr/*.md") + glob.glob("tools/**/*.md", recursive=True)
        + glob.glob(".claude/skills/*/SKILL.md"))
LIB = glob.glob("lib/**/*.ex", recursive=True)


def modules_and_functions():
    modules, functions = set(), set()
    for f in LIB + glob.glob("test/support/*.ex"):
        for line in open(f).read().split("\n"):
            m = re.match(r"\s*defmodule\s+([\w.]+)", line)
            if m:
                modules.add(m.group(1))
            m = re.match(r"\s*(?:def|defp|defdelegate|defmacro)\s+([a-z_][\w?!]*)", line)
            if m:
                functions.add(m.group(1))
    return modules, functions


def broken_references(modules):
    print("## Links, paths and modules that do not exist")
    for f in DOCS:
        s, d, bad = open(f).read(), os.path.dirname(f), []
        for p in set(re.findall(r"\]\(([^)#\s]+)", s)):
            if not p.startswith("http") and not os.path.exists(os.path.join(d, p)):
                bad.append("link " + p)
        for p in set(re.findall(r"`((?:docs|lib|test|tools|starters|\.claude)/[^`\s*]+)`", s)):
            p = p.split(":")[0]
            if not glob.glob(p) and not os.path.exists(p):
                bad.append("path " + p)
        for m in set(re.findall(r"(Agendum(?:\.[A-Z]\w*)+)", s)):
            known = m in modules or any(x.startswith(m + ".") for x in modules)
            if not known and m.rsplit(".", 1)[0] not in modules:
                bad.append("module " + m)
        if bad:
            print(f, sorted(bad))


def unknown_functions(functions):
    print("\n## name/arity references with no such function")
    for f in ["docs/DATA_ACCESS.md", "docs/DATA_MODEL.md", "docs/ARCHITECTURE.md",
              "docs/SPEC.md", "CLAUDE.md", "CONTRIBUTING.md"]:
        names = set(re.findall(r"([a-z_][\w?!]*)/\d", open(f).read()))
        bad = sorted(n for n in names if n not in functions and n not in ("adr",))
        if bad:
            print(f, bad)


def modules_missing_from_architecture():
    print("\n## Modules ARCHITECTURE.md does not mention")
    arch = open("docs/ARCHITECTURE.md").read()
    for f in sorted(LIB):
        m = re.search(r"defmodule\s+([\w.]+)", open(f).read())
        if not m:
            continue
        name = m.group(1)
        short = name.split(".")[-1]
        mentioned = (f"`{short}`", f" {short}", f".{short}`")
        if name not in arch and not any(m in arch for m in mentioned):
            print(name, "(" + f + ")")


def struct_fields_missing():
    print("\n## Core struct fields not named in DATA_MODEL.md / JSON_FORMAT.md")
    dm, js = open("docs/DATA_MODEL.md").read(), open("docs/JSON_FORMAT.md").read()
    for f in glob.glob("lib/agendum/core/**/*.ex", recursive=True):
        s = open(f).read()
        mod = re.search(r"defmodule\s+([\w.]+)", s).group(1)
        for st in re.findall(r"defstruct\s*(\[.*?\]|\w[^\n]*)\n", s, re.S):
            fields = set(re.findall(r"(\w+):", st) + re.findall(r":(\w+)", st))
            miss_dm = sorted(x for x in fields if x not in dm)
            miss_js = sorted(x for x in fields if x not in js)
            if miss_dm or miss_js:
                print(mod, "DATA_MODEL:", miss_dm, "| JSON:", miss_js)


def format_version():
    print("\n## Stored format version")
    store = open("lib/agendum/store.ex").read()
    v = re.search(r"@format_version (\d+)", store).group(1)
    dm = open("docs/DATA_MODEL.md").read()
    print("Store:", v, "| DATA_MODEL's table has a row for it:", f"| {v} |" in dm)


def planned_claims():
    print("\n## 'Planned / not done' claims to check against the code")
    pat = re.compile(r"on the roadmap|not yet|is planned|are planned|not done|not started|⏳|TODO",
                     re.I)
    for f in ["README.md", "CONTRIBUTING.md"] + glob.glob("docs/*.md"):
        for n, line in enumerate(open(f).read().split("\n"), 1):
            if pat.search(line):
                print(f"{f}:{n}: {line.strip()[:160]}")


if __name__ == "__main__":
    mods, funs = modules_and_functions()
    broken_references(mods)
    unknown_functions(funs)
    modules_missing_from_architecture()
    struct_fields_missing()
    format_version()
    planned_claims()
