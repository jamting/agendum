# ADR 0030 — In a settings box, ENTER is done and ESC cancels

**Status:** accepted · 2026-10-14; amended 2026-10-22 (below); applying on ENTER built 2026-10-24 (below)

## Context

Agenda's boxes said in their bottom edge "Press ENTER when done, ESC to cancel" (screenshots 130, 138): ENTER kept what was set in the box, ESC threw it away. In a box, F2 edited a text field and SPACE or F3 chose.

Our settings boxes apply each change at once, so the screen behind a box shows it, and ESC closed the box keeping the changes. In six boxes (Category, Item, Macro and Section Properties, Sort, Datebook settings) ENTER acted on the highlighted field instead of closing. Agenda's frame text would have been untrue in all of them.

## Decision

- Every settings box finishes with ENTER, which keeps its changes, and ESC, which cancels them; the frame says so in Agenda's words.
- Changes still apply at once while the box is open. When a settings box opens, the file and the person's preferences are kept with its mode; ESC puts them back (`Agendum.TUI.Boxes.BoxCancel`), as one change, so one undo brings the cancelled changes back. Preferences that were saved are saved again as they were.
- A box opened from a box keeps its own snapshot, so ESC there cancels only its own changes. Work done in a full screen opened from a box (a note, the macro edit screen) is kept: the box starts a new snapshot when it shows again.
- In a box, SPACE (or → ←) changes or opens the highlighted field, F2 edits text, F3 picks, F4 sets an item's date or number; ENTER no longer does any of these.
- Boxes that only act on ENTER (Column Add, the range filters, actions, Execute, Schedule, Search) already cancelled on ESC and keep doing so. Category lists where ENTER switches a category's choice (filters, conditions, actions, Excludes) finish with ESC and say "Press ESC when done".

## Consequences

- The frame text is true everywhere, and ENTER and ESC mean the same in every box, as in Agenda.
- People used to ENTER on a field in the six boxes press SPACE (or F2) instead; the help in the control panel (`Agendum.TUI.Boxes.FieldHelp`) and the key bar say so.
- Cancelling restores whole snapshots, so it is simple and covers every setting, present and future, without per-box code.
- A box must keep its mode map when it changes it (`%{mode | …}`), or it loses its snapshot; none replaces it.

## Amendment, 2026-10-22: two points changed back to Agenda's

The tagging sitting of 2026-10-22 (ADR 0043; meeting 2026-10-22, § 5b) checked boxes in Agenda 2.0 run headless, on a copy of PLANNER:

- With Hide empty sections set to Yes in View Properties, the empty section stayed behind the box until ENTER; then it went and `[Hide empty]` appeared on the view line. **Agenda applies a box's changes on ENTER.**
- A category list opened from a box (a view's Filter, an item's Assignment Profile) says "Press ENTER to accept"; SPACE switches a category; ESC closes it **keeping** the change, as ENTER does.
- ESC in the outer box did not undo what was changed in such a list (the filter stayed `[-Contact List,Type,Lodging]`; an assignment made in the profile stayed).

Decided by the owner:

- **Changed back:** a settings box applies its changes when ENTER closes it, not while it is open. Category lists take Agenda's frame text and keys: "Press ENTER to accept", SPACE switches, ENTER and ESC both close keeping the change. The "Press ESC when done" lists and ENTER switching a category go.
- **Kept, tagged *work*:** ESC in a box puts back everything done since the box opened, the changes made in its category lists included. Agenda kept those, a surprise ESC should not hold.

Both changes back are roadmap items (Towards parity), settled with the owner before they are built.

## Built, 2026-10-24: applying on ENTER

Settled with the owner before it was built:

- **The screen behind a box is drawn as it was when the outermost settings box opened** (`BoxCancel.behind/2`, from the snapshot the box already kept for ESC; the place in the view too while it is the same view, and the view as it is now when the box's own key made it, View ▸ Add). The boxes themselves still apply each change at once and show the new values, so none of their code changed, and every box present and future behaves the same.
- **One undo step per box:** the steps recorded while it is open are folded into one when the outermost box closes with ENTER (`BoxCancel.settle/2`, `History.squash/3`), and dropped when it closes with ESC, which now leaves no step: a cancelled box changed nothing (the earlier "one undo brings the cancelled changes back" goes). Within a macro run the run is the step already.
- **No auto-save while a settings box is open:** its changes reach the file on ENTER; a save that came due waits until the box has closed.

