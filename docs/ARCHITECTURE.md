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
| `Core.Search` | Text search: whether an item's text or note matches (R37). |
| `Core.RangeFilter` | Date and numeric filter ranges: checking, matching, the value a new item gets (R28a). |
| `Core.NumberFormat` | Reading and showing numbers, and the calculations of numeric columns (R29). |
| `Core.DateFormat` | How a file displays dates and times: date order, separator, clock, day of week (R41). |
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
