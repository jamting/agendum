# ADR 0036 — User actions are core commands on ids, returning what changed

**Status:** accepted · 2026-10-16

## Context

A user action was defined in the TUI: `Agendum.TUI.Update` and its modules called the core's facade, sometimes several functions with logic of their own between them (done on every marked item was a loop in `Agendum.TUI.Update.Marked`), and every view command acted on "the highlighted row" (`ViewKeys.run/3` passes `Layout.current_row/1`). The TUI called 141 `Agendum.Core` functions directly. A web front end, customizable keys, a modern mode and an agent (Wol) all need the action itself, without a keyboard or a cursor: the expert reviews of 2026-10-16 named this the change everything else waits for (`docs/reviews/2026-10-16.md`, Architecture 1; `docs/reviews/2026-10-16-2.md`). `docs/plans/MULTIUSER.md` §6 and §7 plan it, and ADR 0033 (named TUI commands through keymaps) was its first half.

The owner settled the choices before any code (2026-10-16): a command is a tagged tuple, not a struct per command; the first slice is the view's item commands (marking, done, discarding), with no new behaviour; what changed is reported as ids, without reasons for now.

## Decision

- **A command is data**: a tagged tuple naming what to do and the ids it acts on, such as `{:toggle_mark, 42}`, `{:mark_done, [42, 43]}`, `:unmark_all`. Never the highlighted row: the front end turns the highlight and the marks into ids (ADR 0033 already said a core command would carry its ids explicitly).
- **One function runs it**: `Agendum.Core.run(db, command, clock)` (in `Agendum.Core.Command`) returns `{:ok, db, changes}` or `{:error, reason}`. It checks first that the command is known and that every id it names is an item of the file; a refused command changes nothing. A command made of several steps loops in the core.
- **What changed is computed**, by comparing the database before and after (`Agendum.Core.Command.Changes.between/2`): the ids of items, categories, views, macros and calendars added, changed and removed, and the names of the file's other fields that changed. An item counts as changed when anything stored about it changed (its assignments, column numbers and dates, dependencies, conditional marks, suggestions). Comparing is right for every command without each one reporting by hand, as undo is (ADR 0005), and cheap: the parts a command did not touch are the same terms before and after.
- **Commands describe themselves**: `Command.describe/1` gives a name, a one-line summary and the kinds of argument, written once for every front end and for an agent's list of tools.
- **Two levels** (MULTIUSER §6): a core command changes the database. Moving the cursor, opening a box or switching views stay the front end's own commands (`Agendum.TUI.Commands`, ADR 0033). A TUI command runs a core command through `State.run/2,3` (`run_with_changes/2` when it needs what changed, such as F4 telling the date of a recurring item's next occurrence), which also words a refusal.
- **Undo is unchanged**: the TUI still records a snapshot when the database changed (ADR 0005). A command is one step, so one undo reverses it.
- **Kept honest by tests**: `test/agendum/architecture_test.exs` fails if the TUI calls an `Agendum.Core` function that a command now does (the list grows with each step), and counts the `Agendum.Core` functions the TUI still calls (139 after the first slice), a number that may only go down.

## Consequences

- Existing actions move over a few at a time (ROADMAP, Towards many users); each step adds commands, the functions they replace to the test's list, and lowers the count. The layer is done when only reads are left and `Agendum.TUI.Update` only turns keys into commands.
- Done on several marked items now passes the moment, as done on one item always did: where a date category stamps the done time, marked items get it too (before, they got the date only).
- Reasons ("filed by condition X") are not in `Changes` yet; an agent will want them. They need hooks in `Agendum.Core.Assign` and settling, and can be added beside the ids without changing a command's shape.
- Comparing walks the maps that changed, once per command: for items, O(items) when an item changed. Measured by the debug log's slow-answer lines if it ever shows (the view cache, ADR 0035, waits for the same evidence).
- Typed UI modes (a struct per mode, ROADMAP) are done place by place as each place's commands move; the first slice touched the view, which has no mode.
