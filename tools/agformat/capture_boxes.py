r"""Capture Lotus Agenda 2.0's settings boxes from the real program (DOSBox).

For each box in BOXES, goes from the view to the box with the keys given
and reads it as Agenda draws it: its title, its rows (the text between the
borders), its bottom edge, and the key bar under it (the ten F-key slots'
labels, "" for an empty slot; with the box's first field highlighted). Writes them to a JSON reference (default
docs/reference/agenda_boxes.json), which Agendum's box label test compares
with its own boxes (AGENDA_PARITY.md, the texts step; meeting 2026-10-21,
§ 8). Run by hand, never by the tests:

    AGENDA_DOS_ROOT=<scratch copy holding APPS/AGENDA> \
        python3 -u tools/agformat/capture_boxes.py [FILE.AG] [out.json] [box ...]

FILE.AG (default: PLANNER.AG of the copy) is copied to BX.AG and opened.
Naming boxes captures only those, merged into the existing output file.

A step is a key name (as agenda_driver.keys takes it), or ("goto", label):
move to the box field with that label, as agenda_driver.goto does; F3
then opens a "..." field's box. Every box is reached afresh from the view
(home()), and the program is killed at the end, so the copy is never saved.
"""
import json, os, re, subprocess, sys
import agenda_driver as d

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "docs", "reference", "agenda_boxes.json")

# On PLANNER's first view (People): the highlight starts on the first section
# head; DOWN reaches its item, RIGHT then the Priority column, RIGHT again When.
ITEM = ["DOWN"]
FILE = ["F10", "f", "p"]
VIEW = ["F10", "v", "v", "p"]
CATMGR = ["F9"]


def cat(name):
    return CATMGR + [("select", name), "F6"]


def sub(path, label):
    return path + [("goto", label), "F3"]


# name: (steps, title of the box to read)
BOXES = {
    "file_properties": (FILE, "File Properties"),
    "global_date_settings": (sub(FILE, "Global date settings"), None),
    # goto() does not reach these right-hand fields: → from the one beside
    "auto_assign_settings": (FILE + [("goto", "Global date settings"), "RIGHT", "F3"], None),
    "global_protection": (sub(FILE, "Global protection"), None),
    "file_statistics": (FILE + [("goto", "Global protection"), "RIGHT", "F3"], None),
    "item_properties": (ITEM + ["F6"], None),
    "category_properties": (cat("Calls"), "Category Properties"),
    "category_properties_date": (cat("When"), "Category Properties"),
    "category_properties_numeric": (cat("Amount"), "Category Properties"),
    "category_text_matching": (sub(cat("Calls"), "Advanced settings"), None),
    "category_date_settings": (sub(cat("When"), "Advanced settings"), None),
    "category_statistics": (sub(cat("Calls"), "Statistics"), None),
    # the title holds the name, short name and Also match, cut short
    "category_text_matching_long": (sub(cat("Miscellaneous Activity"), "Advanced settings"), None),
    "category_add": (["F10", "c", "a"], None),
    "view_properties": (VIEW, "View Properties"),
    "sort": (sub(VIEW, "Item sorting"), None),
    "view_statistics": (sub(VIEW, "View statistics"), None),
    "view_add": (["F10", "v", "v", "a"], None),
    "section_properties": (["F10", "v", "v", "s", "p"], None),
    "section_sort": (["F10", "v", "v", "s", "p", ("goto", "Item sorting"), "F3"], None),
    "section_add": (["F10", "v", "v", "s", "a"], None),
    "column_properties": (ITEM + ["RIGHT", "F10", "v", "v", "c", "p"], None),
    "column_properties_date": (ITEM + ["RIGHT", "RIGHT", "F10", "v", "v", "c", "p"], None),
    "column_add": (["F10", "v", "v", "c", "a"], None),
    "customize": (["F10", "u", "c"], None),
    "execute": (["F10", "u", "e"], None),
    "alarm": (ITEM + ["F10", "i", "a"], None),
    "display_format": (sub(FILE, "Global date settings") + [("goto", "Display format"), "F3"], None),
    "input_format": (
        sub(FILE, "Global date settings") + [("goto", "Display format"), "RIGHT", "F3"],
        None,
    ),
    "item_column_properties": (ITEM + ["F10", "v", "v", "c", "p"], None),
    "search": (["AF6"], None),
    # PLANNER already has a Show view: Agenda asks to replace it first
    "show_schedule": (["F10", "u", "s", "s", "ENTER"], None),
    "macro_properties": (["AF3", "F6"], None),
    # Confirm assignments Always, then an item whose text matches three
    # categories: Questions lists them
    "questions": (
        FILE
        + [("goto", "Global date settings"), "RIGHT", "F3", ("goto", "Confirm assignments")]
        + ["SPACE", "ENTER", "ENTER", "HOME"]
        + list("Telephone Mattias")
        + ["ENTER", "F10", "u", "q"],
        None,
    ),
    # a datebook view's settings are in its View Properties, Type Datebook
    "view_properties_datebook": (["F8", ("select", "This Week"), "ENTER"] + VIEW, None),
}

BOTTOM = re.compile(r"#{2,} ?(Press [^#]*?) ?#{2,}")


def boxes_on(screen):
    """every box drawn on the screen, found from its bottom edge ("Press
    ENTER when done …"): (top, bottom, left, right). A box drawn over
    another meets its edges, and Agenda draws a statistics box on the top
    edge of the box beneath it, so the box is followed up its side edges
    from the bottom until a row of its width is all edge"""
    found = []
    for rb, line in enumerate(screen[:23]):
        for m in BOTTOM.finditer(line):
            left, right = m.start(), m.end() - 1
            while left > 0 and line[left - 1] == "#":
                left -= 1
            while right + 1 < len(line) and line[right + 1] == "#":
                right += 1
            # the box beneath may end next to this one: its edge is the one
            # with a blank inside it
            inside = screen[rb - 1]
            while right > left and inside[right - 1] == "#":
                right -= 1
            while left < right and inside[left + 1] == "#":
                left += 1
            top = rb - 1
            while top > 0 and not (
                screen[top][left : left + 2] == "##" and screen[top][right - 1 : right + 1] == "##"
            ):
                top -= 1
            found.append((top, rb, left, right))
    return found


def read_box(screen, title):
    boxes = boxes_on(screen)
    titled = [(b, _title(screen, b)) for b in boxes]
    if title:
        titled = [(b, t) for b, t in titled if t == title]
    if not titled:
        raise RuntimeError("no box:\n" + "\n".join(screen))
    # the box on top is the one drawn inside the others: the narrowest
    (top, bottom, left, right), title = min(titled, key=lambda bt: bt[0][3] - bt[0][2])
    rows = [line[left + 1 : right].rstrip() for line in screen[top + 1 : bottom]]
    edge = screen[bottom][left : right + 1].strip("#").strip()
    return {"title": title, "rows": rows, "bottom": edge, "keys": key_bar(screen)}


def key_bar(screen):
    """the labels of the ten F-key slots on the last line ("Help", "Edit",
    "" …); the slots are separated by # (CP437 box lines read as #)"""
    return [slot.strip() for slot in screen[-1].split("#")][:10]


def _title(screen, box):
    top, _bottom, left, right = box
    return screen[top][left : right + 1].strip("#").strip() or None


def go(steps):
    d.home()
    for step in steps:
        if isinstance(step, tuple) and step[0] == "goto":
            d.goto(step[1])
        elif isinstance(step, tuple) and step[0] == "select":
            d.select(step[1])
        else:
            d.keys(step)
        d.idle()


def main():
    args = sys.argv[1:]
    base = args.pop(0) if args and args[0].upper().endswith(".AG") else os.path.join(d.AG, "PLANNER.AG")
    out = args.pop(0) if args and args[0].endswith(".json") else OUT
    names = args or list(BOXES)
    captured = {}
    if args and os.path.exists(out):
        captured = json.load(open(out))["boxes"]
    d.fresh("BX", base)
    d.idle()
    try:
        for name in names:
            steps, title = BOXES[name]
            try:
                go(steps)
                if os.environ.get("SHOW"):
                    d.show()
                box = read_box(d.screen(), title)
                captured[name] = box
                print(name, json.dumps(box, ensure_ascii=False))
            except Exception as e:  # one box failing should not lose the rest
                print("FAILED", name, e)
                d.show()
    finally:
        subprocess.run(["pkill", "-f", "DOSBox Staging"])
    with open(out, "w") as f:
        json.dump(
            {
                "source": "Lotus Agenda 2.0, PLANNER.AG, read by capture_boxes.py",
                "boxes": dict(sorted(captured.items())),
            },
            f,
            indent=2,
            ensure_ascii=False,
        )
        f.write("\n")


if __name__ == "__main__":
    main()
