# SPDX-License-Identifier: AGPL-3.0-only
r"""Capture Lotus Agenda 2.0's key bars from the real program (DOSBox).

For a view, a note, the category manager and the view manager, reads the
bar's ten slots as Agenda draws them with no key held and with ALT, CTRL or
SHIFT held, and writes the labels to a JSON reference (default
docs/reference/agenda_key_bars.json), which Agendum's key bar test compares
with the bars it makes from its keymaps (ADR 0045; meeting 2026-10-24-2057, § 5).
Run by hand, never by the tests:

    AGENDA_DOS_ROOT=<scratch copy holding APPS/AGENDA> \
        python3 -u tools/agformat/capture_key_bars.py [FILE.AG] [out.json]

FILE.AG (default: PLANNER.AG of the copy) is copied to KB.AG and opened.

Holding a key: Agenda reads the BIOS shift flags (0040:0017), so setting a
flag's bit there by hand is a held key to it (ALT 0x08, CTRL 0x04, left
SHIFT 0x02). No key is typed while one is "held", and each place is reached
afresh from the view (home()). The program is killed at the end, so the
copy is never saved.
"""
import json, os, subprocess, sys, time
import agenda_driver as d

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "docs", "reference", "agenda_key_bars.json")

# how to reach each place from the view, and the text that says it is there
PLACES = {
    "view": ([], lambda s: s[1].strip().startswith("View:")),
    "note": (["F5"], lambda s: s[0].strip().startswith("Note for:")),
    "catmgr": (["F9"], lambda s: s[1].strip() == "Category Manager"),
    "viewmgr": (["F8"], lambda s: "To display a view" in s[0]),
}
HELD = {"none": 0x00, "alt": 0x08, "ctrl": 0x04, "shift": 0x02}


def slots(screen):
    """the ten labels of the bar's bottom line (the slots are 8 columns)"""
    line = screen[24]
    return [line[8 * n : 8 * n + 7].strip() for n in range(10)]


def held(bits):
    d.wr(0x417, bytes([bits]))
    time.sleep(0.6)
    d.idle()


def main():
    base = sys.argv[1] if len(sys.argv) > 1 else os.path.join(d.AG, "PLANNER.AG")
    out = sys.argv[2] if len(sys.argv) > 2 else OUT
    d.fresh("KB", base)
    d.idle()
    bars = {}
    try:
        for place, (keys, here) in PLACES.items():
            d.home()
            if keys:
                d.keys(*keys)
            d.idle()
            if not here(d.screen()):
                raise SystemExit(f"could not reach {place}: {d.screen()[:2]}")
            bars[place] = {}
            for name, bits in HELD.items():
                held(bits)
                bars[place][name] = slots(d.screen())
                held(0)
            print(place, json.dumps(bars[place]))
    finally:
        held(0)
        subprocess.run(["pkill", "-f", "DOSBox Staging"])
    with open(out, "w") as f:
        json.dump(
            {"source": "Lotus Agenda 2.0, PLANNER.AG, read by capture_key_bars.py", "bars": bars},
            f,
            indent=2,
            ensure_ascii=False,
        )
        f.write("\n")


if __name__ == "__main__":
    main()
