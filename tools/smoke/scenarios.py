#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-only
"""Real-terminal scenarios: smoke.py runs with what their screen must show.

The unit tests drive the pure TUI; these run the real program in a
pseudo-terminal (smoke.py, sandboxed from the person's preferences), so
they reach what the unit tests cannot: the key decoder, raw mode, UTF-8
cut between reads, the terminal's own drawing. Each scenario sends its
keys and checks the last screen against patterns that must and must not
be there. They run one after another (each starts the program, and two
compiles at once would trip over each other in _build).

Usage:
    tools/smoke/scenarios.py            # every scenario
    tools/smoke/scenarios.py cjk f9     # those whose name holds a word given
    mix agendum.smoke                   # the same, from Mix

Exit status 0 when every scenario passed. Run nightly in CI and before a
release; slower than the unit tests (a few seconds each), and timing
can make one flaky, so a failure is run once more before it counts.
"""

import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SMOKE = os.path.join(HERE, "smoke.py")
ROOT = os.path.dirname(os.path.dirname(HERE))

# name, smoke.py arguments, patterns the last screen must hold, and must not
SCENARIOS = [
    ("startup demo", [], [r"View: Activities", r"F10\s*\n.*Menu"], [r"W O L ' S"]),
    (
        "named file opens without splash",
        ["--file", "starters/planner.agendum"],
        [r"View: Tasks"],
        [r"W O L ' S"],
    ),
    ("typed item", ["text:Plant carrots Friday", "ENTER"], [r"Plant carrots Friday"], []),
    (
        "cjk item typed whole",
        ["text:会議の準備 🎉 Kaigi", "ENTER"],
        [r"会議の準備 🎉 Kaigi"],
        [],
    ),
    (
        "cjk long item wraps without loss",
        ["text:会議の準備をする前に資料を読んで日本語の文章を確認する"],
        [r"会議の準備をする前に資料を読ん\s*\n.*で日本語の文章を確認する"],
        [],
    ),
    ("f9 category manager", ["F9"], [r"Category Manager", r"MAIN"], []),
    ("f10 menu", ["F10"], [r"File\s+Item\s+Category\s+View"], []),
    ("f10 menu and esc", ["F10", "ESC"], [r"View: Activities"], [r"File\s+Item\s+Category\s+View"]),
    ("alt-f3 macro manager", ["ALT-F3"], [r"Macro Manager"], []),
    ("f1 help", ["F1"], [r"─ Help ─", r"PURPOSE"], []),
    (
        "f5 note typed",
        ["DOWN", "F5", "text:Ask about the budget"],
        [r"Note for:", r"Ask about the budget"],
        [],
    ),
    ("ctrl-n new item", ["CTRL-N", "text:From control N", "ENTER"], [r"From control N"], []),
]


def run(name, args, must, must_not):
    """One scenario: True when its last screen holds every `must` and no `must_not`."""
    out = subprocess.run(
        [sys.executable, SMOKE, *args], cwd=ROOT, capture_output=True, text=True, timeout=240
    ).stdout
    # the last screen smoke.py printed (its frame starts "┌─ end")
    last = out[out.rfind("┌─ end") :] if "┌─ end" in out else out
    missing = [p for p in must if not re.search(p, last)]
    unwanted = [p for p in must_not if re.search(p, last)]
    return not missing and not unwanted, missing, unwanted, last


def main(words):
    chosen = [s for s in SCENARIOS if not words or any(w.lower() in s[0] for w in words)]
    failed = []
    for name, args, must, must_not in chosen:
        ok, missing, unwanted, last = run(name, args, must, must_not)
        if not ok:
            # timing in a pseudo-terminal can make a run flaky: once more
            ok, missing, unwanted, last = run(name, args, must, must_not)
        print(("ok    " if ok else "FAIL  ") + name, flush=True)
        if not ok:
            failed.append(name)
            for p in missing:
                print(f"      missing: {p}")
            for p in unwanted:
                print(f"      unwanted: {p}")
            print(last)
    print(f"{len(chosen) - len(failed)} of {len(chosen)} scenarios passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
