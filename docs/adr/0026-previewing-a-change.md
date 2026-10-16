# ADR 0026 — Previewing a change before it is kept

**Status:** accepted · 2026-10-13 (recording a pattern used since browsing, R47/R48)

## Context

Some of Agenda's commands are a series of keys that ends with ENTER or ESC, and the screen follows each key:

- browsing a datebook or a date filter (ALT-B, R47 and R48): ← → show other dates;
- View ▸ Column ▸ Width (User's Guide 5-21): ← → or a typed number;
- View ▸ Column ▸ Move (User's Guide 5-20): ← → move the column, or the item column.

ENTER keeps the result and ESC goes back to how things were. Undo is automatic (ADR 0005): every key that changes the database records a step. Changing the database on each ← → would therefore record one undo step per key, and ESC would have to undo them. There would be no single step for the whole command, and a cancelled command would still leave traces.

A web front end with several people in one file (ADR 0020) adds a second reason: each change to the shared file is broadcast to everyone, so a change that is only being tried out must not reach the file.

## Decision

- While such a command runs, **the file is not changed**. Its mode (on the TUI's mode stack) holds what is being chosen: the browsed dates, the width, the place.
- **`State.view/1` shows the view as it would be.** It passes the stored view through each preview mode's `view/2` (`Browse`, `ColumnWidth`, `ColumnMove`). That function computes the result with the same core function ENTER will use (`Core.set_column_width/4`, `Core.move_column/5` and so on) and does not keep it. Everything that draws or lays out the view reads it through `State.view/1`, so the screen, the cursor rows and the widths all follow.
- **ENTER applies the core function once** to the stored database: one database change, one undo step (ADR 0005). **ESC pops the mode**: the file is as it was, with no undo step.
- What the control panel says is what ENTER will keep: a value is checked against the core's limits as it is chosen (a width read back after the core clamps it).
- A new command of this kind follows the same pattern: a mode with a `view/2`, added to `State.view/1`.

## Consequences

- Undo stays automatic, and the "one user action = one database change" rule holds for multi-key commands too. History needed no special case.
- The core functions stay plain: they do not know that a preview exists, and the same function both previews and keeps.
- Each preview recomputes the change on every redraw. Views are small, so this costs nothing that shows; a costly change would have to keep its result in the mode instead.
- In a web front end a preview belongs to one person's session and never reaches the shared file, which is what ADR 0020's commands need: only ENTER becomes a command.
- Something that reads `state.db.views` directly instead of `State.view/1` does not see the preview. That is right for what is stored (a test checks the file is unchanged), and wrong for what is drawn.
