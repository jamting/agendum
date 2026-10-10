# Architecture

**Functional core, imperative shell.** All of Agenda's logic and the
whole UI state machine are pure functions over immutable values. A thin
shell does terminal I/O and file I/O.

```
               ┌────────────────────── imperative shell ──────────────────────┐
  keyboard ──► │ Terminal (raw mode) ─► App loop ─► Keys.decode ─┐            │
               │                                                 ▼            │
               │                      ┌──────────── pure ──────────────────┐  │
               │                      │ TUI.Update.handle(state, key)      │  │
               │                      │   → {state, effects}               │  │
               │                      │        │ calls                      │  │
               │                      │        ▼                            │  │
               │                      │ Agenda.Core (facade)                │  │
               │                      │   Database · Assign · Links ·       │  │
               │                      │   ViewModel · DateParser            │  │
               │                      │                                     │  │
               │                      │ TUI.Render.render(state) → lines    │  │
               │                      └──────────────┬──────────────────────┘  │
               │ effects: Store.save/load, File.write │ Screen.frame (diff)    │
  screen ◄──── │ ◄────────────────────────────────────┘                        │
               └───────────────────────────────────────────────────────────────┘
```

## Modules

### Core (`lib/agenda/core*`) — pure

| Module                                    | Responsibility                                                                                                                                          |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Agenda.Core`                             | Facade with user-level operations (add item, assign by name, add section…). The UI uses this.                                                           |
| `Core.Database`                           | The file as one immutable struct: items, categories, views, links, id counter. Primitive operations and queries (`member?/3`, `items_in/2`, hierarchy). |
| `Core.Links`                              | Bidirectional many-to-many relation (the patent's link structures).                                                                                     |
| `Core.Assign`                             | Assignment rules: exclusion, category links, text matching, ambiguity resolution.                                                                       |
| `Core.ViewModel`                          | Read model: projects a view to sections, rows and column cells.                                                                                         |
| `Core.DateParser`                         | Date expressions relative to a given `today`.                                                                                                           |
| `Core.TextCondition` | Agenda's "Also match" text conditions: `;` any, `,` all, `!`, `~`, wildcards (R15d). |
| `Core.Recurrence` | The rule of a recurring When date and the next date from a base date (R14a). |
| `Core.Context` | The current time and the date languages, passed to the core wherever it reads typed dates (R14c); `parser_opts/2` adds the file's `DateSettings`. |
| `Core.DateLanguage` (+ `English`, `Swedish`) | Language packs for reading dates: words, phrase patterns, day/month order, clock (R14c). `DateParser` does the arithmetic. |
| `Core.Search` | Text search: whether an item's text or note matches (R37). |
| `Core.RangeFilter` | Date and numeric filter ranges: checking, matching, the value a new item gets (R28a). |
| `Core.NumberFormat` | Reading and showing numbers, and the calculations of numeric columns (R29). |
| `Core.DateFormat` | How a file displays dates and times: date order, separator, clock, day of week (R41). |
| `Core.DateSettings` | How a file reads dates: week, quarter and year boundaries, month alone, morning/afternoon/evening (R14e). |
| `Core.TextSearch` | Finding and replacing literal text in a note's lines (R39). |
| `Core.Item`, `Core.Category`, `Core.View` | Plain structs.                                                                                                                                          |

### TUI (`lib/agenda/tui/*`)

| Module                         | Pure? | Responsibility                                                                                                                   |
| ------------------------------ | ----- | -------------------------------------------------------------------------------------------------------------------------------- |
| `TUI.State`                    | ✔     | UI state: db, path, cursor, scroll, **mode stack**, inline edit, message, queued effects.                                        |
| `TUI.Update`                   | ✔     | Key → state transitions for the view, prompts, confirmations, notes, item moves; `perform/2` named actions shared with the menu. |
| `TUI.Menu`                     | ✔     | The Lotus two-line menu tree.                                                                                                    |
| `TUI.CategoryScreens`          | ✔     | Category manager, category picker box, assignment profile, category properties.                                                  |
| `TUI.ViewManager`              | ✔     | View manager.                                                                                                                    |
| `TUI.Layout`                   | ✔     | Flattens a view to cursor rows and wrapped lines; keeps the cursor anchored and visible.                                         |
| `TUI.Completion` | ✔ | Automatic completion while typing a column entry: the matches (from `Core.completions/3`) and the one shown. |
| `TUI.ItemProperties` | ✔ | The Item Properties box: text, note, statistics and the item's assignments (R34). |
| `TUI.SortBox` | ✔ | The Sort box: a view's or a section's sort keys (R36). |
| `TUI.SearchBox` | ✔ | The Search box and search mode (ALT-N / ALT-P / F7), and the Show View (R37). |
| `TUI.QuestionsBox` | ✔ | Utilities Questions: confirming suggested assignments (R16). |
| `TUI.ExecuteBox` | ✔ | Utilities Execute: the Execute box, ALT-X and ALT-E (R15e). |
| `TUI.ActionBox` | ✔ | The Date Action / Numeric Action box (R15b). |
| `TUI.RangeFilterBox` | ✔ | The Date Filter / Numeric Filter box (R28a). |
| `TUI.ColumnProperties` | ✔ | The Numeric Column Properties box: number format and calculations (R29). |
| `TUI.FileProperties` | ✔ | The File Properties box: the date display format, with a sample (R41). |
| `TUI.NoteSearch` | ✔ | The Search/Replace box in a note, ALT-S, and confirming each replacement (R39). |
| `TUI.AlarmList` | ✔ | The alarm list box: current and past alarms (R38). |
| `TUI.Render`                   | ✔     | State → list of styled lines (title bar, control panel, body, key bar, boxes).                                                   |
| `TUI.Draw`, `TUI.Theme`        | ✔     | Line/box primitives; symbolic style → ANSI codes in the chosen theme (classic or mono, R40).                                     |
| `TUI.Keys`                     | ✔     | Raw input bytes → key events (xterm sequences, ALT, ESC-digit aliases).                                                          |
| `TUI.LineEdit`, `TUI.TextEdit` | ✔     | Single-line and multi-line edit buffers.                                                                                         |
| `TUI.Screen`                   | ✔     | Diffs two frames into minimal ANSI output.                                                                                       |
| `TUI.Terminal`                 | ✘     | Raw mode, alternate screen, size, input reader process.                                                                          |
| `TUI.App`                      | ✘     | Main loop: read → decode → update → run effects → render.                                                                        |
| `Agenda.Store`                 | ✘     | Save/load (`term_to_binary` in a versioned envelope, atomic write).                                                              |
| `Agenda.CLI`                   | ✘     | `main/1` for the escript.                                                                                                        |

## Key design decisions

- **Mode stack.** Overlays (menu, managers, pickers, prompts) are pushed
  on `state.modes`; ESC pops. Full-screen modes (category manager, view
  manager, note, help) replace the body; boxes (picker, profile,
  properties) draw over it.
- **Effects as data.** `Update` never performs I/O. It queues effects
  (`{:save, path}`, `{:load, path}`, `{:write_text, path, text}`, `:quit`)
  that `App` executes, feeding results back through `Update.saved/3` and
  similar. This keeps every UI behaviour testable with plain key sequences.
- **The clock comes in from outside.** On every pass of its loop `App`
  calls the pure `Update.tick(state, now)`, which updates the clock, rings
  due alarms and asks for a `:bell` effect. Tests drive time the same way.
- **Cursor anchoring.** The cursor is stored as a stable key
  (`{:item, section_index, item_id}` or `{:section, index}`) and re-found
  after every change (`Layout.settle/1`), so it follows an item when
  automatic assignment or edits reshuffle the view.
- **Subsumption is computed.** Only explicit links are stored. Deleting a
  category therefore needs no cascade logic beyond dropping its links (R4).
- **One id space.** Items, categories and views share `next_id`, like the
  patent's single object file.

See [`DATA_MODEL.md`](DATA_MODEL.md) for the data structures and
[`DATA_ACCESS.md`](DATA_ACCESS.md) for the query/update API and its
algorithms. See `docs/adr/` for the reasoning behind the larger choices.

## Architecture decision records

| ADR                                                              | Decision                                                      |
| ---------------------------------------------------------------- | ------------------------------------------------------------- |
| [0001](adr/0001-functional-core-imperative-shell.md)             | Functional core, imperative shell; Elm-style TUI               |
| [0002](adr/0002-own-terminal-layer.md)                           | Our own terminal layer on OTP raw mode, no TUI library         |
| [0003](adr/0003-file-format.md)                                  | File format: versioned Erlang terms, upgraded on load          |
| [0004](adr/0004-links-stored-membership-computed.md)             | Store explicit links, compute membership                       |
| [0005](adr/0005-undo-by-snapshots.md)                            | Undo by database snapshots, recorded automatically             |
| [0006](adr/0006-fidelity-and-extensions.md)                      | Faithful to Agenda 2.0, with marked extensions                 |
| [0007](adr/0007-keyboard-strategy.md)                            | Agenda's keys first, with alternatives that always work        |
| [0008](adr/0008-file-settings-and-personal-settings.md)          | What belongs in the file, and what belongs to the person       |
| [0009](adr/0009-date-language-packs-and-context.md)              | Date language packs, and a context passed to the core          |
| [0010](adr/0010-data-interchange.md)                             | Data interchange: JSON, and Agenda's structured files (proposed) |
| [0011](adr/0011-conditions-and-actions-settle.md)                | Conditions and actions run in one step after every change      |
| [0012](adr/0012-quality-gate.md)                                 | The quality gate: formatter, compiler, Credo, Dialyzer, tests  |
| [0013](adr/0013-reading-dates-file-and-reader.md)                | Reading dates: the file's settings and the reader's language   |
| [0014](adr/0014-negative-links.md)                               | Negative links between any two categories (an extension)       |
