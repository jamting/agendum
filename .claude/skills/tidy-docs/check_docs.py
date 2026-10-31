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


def private_side():
    """The owner's private repository, the Wolery, beside this public one
    (only where `CLAUDE.local.md` or $AGENDUM_PRIVATE_DOCS says where it is;
    a contributor's checkout skips this). Its rule: the public file is the
    only full text, the Wolery keeps only the private passages."""
    print("\n## The private side (the Wolery)")
    docs = os.environ.get("AGENDUM_PRIVATE_DOCS")
    if not docs and os.path.exists("CLAUDE.local.md"):
        m = re.search(r"`(~/[^`]*wolery[^`]*)`", open("CLAUDE.local.md").read())
        docs = m and os.path.join(m.group(1), "docs")
    docs = docs and os.path.expanduser(docs)
    if not docs or not os.path.isdir(docs):
        print("(no private repository here: skipped)")
        return
    wolery = os.path.dirname(docs.rstrip("/"))
    creek = "soaked in the creek"

    # 1. a whole public document copied into the Wolery: two texts that drift.
    # The old minutes and reviews are kept whole on purpose (the real names).
    for f in sorted(glob.glob(os.path.join(docs, "**", "*.md"), recursive=True)):
        rel = os.path.relpath(f, wolery)
        if re.match(r"docs/(meetings|reviews|summaries|study|reference)/", rel):
            continue
        if os.path.exists(rel):
            print(f"full copy: {rel} is in both repositories (keep only its passages, {rel[:-3]}.private.md)")

    # 2. each passage file: its public twin, a creek line per passage, and
    # the public line each passage follows still there
    for f in sorted(glob.glob(os.path.join(docs, "**", "*.private.md"), recursive=True)):
        rel = os.path.relpath(f, wolery)
        twin = rel.replace(".private.md", ".md")
        if not os.path.exists(twin):
            print(f"{rel}: no public {twin}")
            continue
        text, public = open(f).read(), open(twin).read()
        passages = len(re.findall(r"^## \d+\.", text, re.M))
        creeks = public.count(creek)
        if creeks < passages:
            print(f"{rel}: {passages} passages, but {twin} has {creeks} creek lines")
        lines = [l.strip() for l in public.split("\n")]
        for anchor in re.findall(r"^After: «(.*?)…?»$", text, re.M):
            if not any(l.startswith(anchor) for l in lines):
                print(f"{rel}: the public line it follows has changed: «{anchor[:70]}»")

    # 3. a meeting's private passages without its public minutes (a secret
    # meeting keeps its agenda and minutes in the Wolery, so it is not one)
    for f in sorted(glob.glob(os.path.join(docs, "meetings", "*", "private.md"))):
        folder = os.path.relpath(os.path.dirname(f), wolery)
        if not os.path.isdir(folder):
            print(f"{folder}/private.md: no public {folder}/")

    # 4. markers left in a public text: a private passage not moved out
    for f in glob.glob("docs/**/*.md", recursive=True) + ["README.md", "CLAUDE.md"]:
        for n, line in enumerate(open(f).read().split("\n"), 1):
            if line.strip() == "<!-- private -->":
                print(f"{f}:{n}: a private marker in a public text")

    # 5. a real name behind a pseudonym in a public text (the names are read
    # from the Wolery's list, never written here)
    names = os.path.join(wolery, "tools", "public", "names.py")
    if os.path.exists(names):
        ns = {}
        exec(open(names).read(), ns)
        real = [r for r, _ in ns.get("FULL", [])]
        files = (glob.glob("docs/**/*.md", recursive=True) + glob.glob(".claude/**/*.md", recursive=True)
                 + ["README.md", "CLAUDE.md", "CONTRIBUTING.md"])
        for f in files:
            if f.startswith("docs/reference/"):
                continue
            text = open(f).read()
            keep = ns.get("KEEP_REAL", {}).get(f, set())  # Agenda's designers, by name
            for r in real:
                if r in text and not any(k in r for k in keep):
                    print(f"{f}: a real name ({len(r)} letters) behind a pseudonym")


if __name__ == "__main__":
    mods, funs = modules_and_functions()
    broken_references(mods)
    unknown_functions(funs)
    modules_missing_from_architecture()
    struct_fields_missing()
    format_version()
    planned_claims()
    private_side()
