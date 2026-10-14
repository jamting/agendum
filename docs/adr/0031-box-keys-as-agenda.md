# ADR 0031 — Keys in a box as Agenda: the arrows move, SPACE changes

**Status:** accepted · 2026-10-14

## Context

In Agenda's boxes (User's Guide 2-16 to 2-17) the arrow keys move between
settings: → or TAB right, or on to the next setting when there is none
to the right; ← or SHIFT-TAB left; ↓ ↑ to the setting below or above.
A setting's value is changed with SPACE (the next choice), the first
letter of a choice, F3 (a list of choices), or by typing it.

Our boxes used → and ← to change values (next and previous choice, a
width one wider or narrower), and only ↑ ↓ to move, one row at a time,
even in boxes with two settings on a row (File Properties, Column
Properties, Column Add, later Category Properties).

## Decision

- In every box the arrows move between settings, as Agenda's
  (`Agendum.TUI.BoxNav`). The places come from the box's layout
  (`Agendum.TUI.Template.grid/2`): ↓ ↑ keep to the same side, onto the
  setting starting nearest the same column; a box listing one setting a
  row moves down and up with → ←. On text being typed (Search, a range
  filter, an action's value) ← → still move in the text.
- Values change with SPACE; there is no "previous choice". Numbers
  (widths, decimal places, line numbers) are typed; times (Morning,
  Afternoon, Evening, a datebook's start and end) are asked for.
- A letter picks the next choice starting with it, and F3 lists the
  choices (`Agendum.TUI.BoxChoices`). The choices are not listed again by
  each box: they are found by trying SPACE on the box, keeping nothing,
  and reading the highlighted value after each press until it comes back
  round. A setting where SPACE opens a box, asks, starts typing, or never
  comes back (a width) has no list, and its keys go to the box.

## Consequences

- Every box moves alike, and the two-column boxes can be laid out as
  Agenda's without the keys getting in the way.
- Going back one choice means SPACE round the list (Date format, the
  longest, has 20); a letter or F3 is the quick way.
- **A rule for every new box:** SPACE on a setting with choices must
  change it in place, on the box on top, and come back round to the
  first choice; its value must be drawn as the box's highlighted
  (`:box_selected`) text. A box that does otherwise loses letters and F3
  for that setting without any error, so its tests should press a
  letter on such a setting.
- Picking by letter replays SPACE, so it is one change and one undo step;
  preferences changed on the way are saved once.
