# ADR 0030 — In a settings box, ENTER is done and ESC cancels

**Status:** accepted · 2026-10-14

## Context

Agenda's boxes said in their bottom edge "Press ENTER when done, ESC to
cancel" (screenshots 130, 138): ENTER kept what was set in the box, ESC
threw it away. In a box, F2 edited a text field and SPACE or F3 chose.

Our settings boxes apply each change at once, so the screen behind a box
shows it, and ESC closed the box keeping the changes. In six boxes
(Category, Item, Macro and Section Properties, Sort, Datebook settings)
ENTER acted on the highlighted field instead of closing. Agenda's frame
text would have been untrue in all of them.

## Decision

- Every settings box finishes with ENTER, which keeps its changes, and
  ESC, which cancels them; the frame says so in Agenda's words.
- Changes still apply at once while the box is open. When a settings box
  opens, the file and the person's preferences are kept with its mode;
  ESC puts them back (`Agenda.TUI.BoxCancel`), as one change, so one undo
  brings the cancelled changes back. Preferences that were saved are
  saved again as they were.
- A box opened from a box keeps its own snapshot, so ESC there cancels
  only its own changes. Work done in a full screen opened from a box (a
  note, the macro edit screen) is kept: the box starts a new snapshot when
  it shows again.
- In a box, SPACE (or → ←) changes or opens the highlighted field, F2
  edits text, F3 picks, F4 sets an item's date or number; ENTER no longer
  does any of these.
- Boxes that only act on ENTER (Column Add, the range filters, actions,
  Execute, Schedule, Search) already cancelled on ESC and keep doing so.
  Category lists where ENTER switches a category's choice (filters,
  conditions, actions, Excludes) finish with ESC and say "Press ESC when
  done".

## Consequences

- The frame text is true everywhere, and ENTER and ESC mean the same in
  every box, as in Agenda.
- People used to ENTER on a field in the six boxes press SPACE (or F2)
  instead; the help in the control panel (`Agenda.TUI.FieldHelp`) and the
  key bar say so.
- Cancelling restores whole snapshots, so it is simple and covers every
  setting, present and future, without per-box code.
- A box must keep its mode map when it changes it (`%{mode | …}`), or it
  loses its snapshot; none replaces it.
