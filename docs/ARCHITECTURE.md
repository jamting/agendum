# Architecture

**Functional core, imperative shell.** All of Agendum's logic and the
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

| Module                                                         | Responsibility                                                                                                                                          |
| -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Agenda.Core`                                                  | Facade with user-level operations (add item, assign by name, add section…): a table of contents of `defdelegate`s. The UI uses this.                    |
| `Agenda.Core.Facade.*`                                         | Its areas: `Files`, `Items`, `Assignments`, `Dates`, `Alarms`, `Numbers`, `Dependencies`, `Rules`, `Categories`, `Views`, `Macros`, `Calendars`.        |
| `Agenda.Core.Facade.Changes`                                   | What every change to an item goes through: user assignments, dates from rules, settling (conditions, actions).                                          |
| `Agenda.Core.Database`                                         | The file as one immutable struct: items, categories, views, links, id counter. Primitive operations and queries (`member?/3`, `items_in/2`, hierarchy). |
| `Agenda.Core.Links`                                            | Bidirectional many-to-many relation (the patent's link structures).                                                                                     |
| `Agenda.Core.Assign`                                           | Assignment rules: exclusion, category links, text matching, ambiguity resolution.                                                                       |
| `Agenda.Core.ViewModel`                                        | Read model: projects a view to sections, rows and column cells.                                                                                         |
| `Agenda.Core.ViewColumns`                                      | Columns per section (R55): adding to one section or all, linked columns changing together, removing from one section or all.                            |
| `Agenda.Core.Datebook`                                         | Datebook views: their settings, the time slots of a period, which items a slot shows (R47).                                                             |
| `Agenda.Core.MonthCalendar`                                    | The pop-up calendar's month as weeks, and the moves of its highlight (R46).                                                                             |
| `Agenda.Core.Macro`                                            | A macro kept in the file: name, keystrokes in Agenda's notation, attached key, where it runs (R50).                                                     |
| `Agenda.Core.DateParser`                                       | Date expressions relative to a given `today`.                                                                                                           |
| `Agenda.Core.TextCondition`                                    | Agenda's "Also match" text conditions: `;` any, `,` all, `!`, `~`, `^`, wildcards (R15d).                                                               |
| `Agenda.Core.TextMatch`                                        | How a file matches text to categories: on/off, match on, strength, enclosed text, suffixes, accents (R16a), proper names (R16c).                        |
| `Agenda.Core.Recurrence`                                       | The rule of a recurring When date and the next date from a base date (R14a).                                                                            |
| `Agenda.Core.Context`                                          | The time, date languages and input format (R14c, R41b), passed wherever typed dates are read; `parser_opts/2` adds the file's `DateSettings`.           |
| `Agenda.Core.InputFormat`                                      | How one person types dates: number order, date separator, 12/24-hour clock; nil is the language's (R41b).                                               |
| `Agenda.Core.JSONFile`                                         | A whole file as JSON and back, checked on import (R44; schema in `JSON_FORMAT.md`).                                                                     |
| `Agenda.Core.ICal`                                             | Reads the events of an iCalendar (`.ics`) file: title, description, start, repeat rule, status (R45).                                                   |
| `Agenda.Core.Calendar`, `Agenda.Core.CalendarSync`             | A calendar subscription; a refresh applied to the file, mirroring the calendar (R45).                                                                   |
| `Agenda.Core.DateLanguage` (+ `English`, `Swedish`)            | Language packs for reading dates: words, phrase patterns, day/month order, clock (R14c). `DateParser` does the arithmetic.                              |
| `Agenda.Core.Search`                                           | Text search: whether an item's text or note matches (R37).                                                                                              |
| `Agenda.Core.RangeFilter`                                      | Date and numeric filter ranges: checking, matching, the value a new item gets (R28a).                                                                   |
| `Agenda.Core.NumberFormat`                                     | Reading and showing numbers, and the calculations of numeric columns (R29).                                                                             |
| `Agenda.Core.DateFormat`                                       | How a file or date column displays dates and times: order, separator, clock, Relative, Week # (R41, R41a).                                              |
| `Agenda.Core.DateRule`                                         | How a date category gets dates: Assign item date, Which one, Done and When keys (R6b).                                                                  |
| `Agenda.Core.DateSettings`                                     | How a file reads dates: week, quarter and year boundaries, month alone, morning/afternoon/evening (R14e).                                               |
| `Agenda.Core.TextSearch`                                       | Finding and replacing literal text in a note's lines (R39).                                                                                             |
| `Agenda.Core.Item`, `Agenda.Core.Category`, `Agenda.Core.View` | Plain structs.                                                                                                                                          |

### TUI (`lib/agenda/tui/*`)

Every screen, box and control-panel mode, and how each is reached, is mapped
in [`SCREENS.md`](SCREENS.md).

| Module                                        | Pure? | Responsibility                                                                                                                   |
| --------------------------------------------- | ----- | -------------------------------------------------------------------------------------------------------------------------------- |
| `Agenda.TUI.State`                            | ✔     | UI state: db, path, cursor, scroll, **mode stack**, inline edit, message, queued effects.                                        |
| `Agenda.TUI.Update`                           | ✔     | Key → state transitions: keys for every screen, the clock (`tick/2`), effect results, dispatch to the screen on top.             |
| `Agenda.TUI.Update.*`                         | ✔     | Its parts: `ViewKeys`, `Editing` (inline), `Marked` (and moves), `Prompts` (and Y/N), `Notes`, `Actions` (`perform/2`).          |
| `Agenda.TUI.Menu`                             | ✔     | The Lotus two-line menu tree.                                                                                                    |
| `Agenda.TUI.CategoryScreens`                  | ✔     | Hierarchy screens: opening them, their rows, cursor, collapsing families, inline edits, dispatch to the parts.                   |
| `Agenda.TUI.CategoryScreens.*`                | ✔     | Its parts: `Manager` (F9), `Picker`, `Profile` (F3), `Properties` (F6), `Choices` (exclusive children, moves).                   |
| `Agenda.TUI.ViewManager`                      | ✔     | View manager.                                                                                                                    |
| `Agenda.TUI.Layout`                           | ✔     | Flattens a view to cursor rows and wrapped lines; keeps the cursor anchored and visible.                                         |
| `Agenda.TUI.Completion`                       | ✔     | Automatic completion while typing a column entry: the matches (from `Core.completions/3`) and the one shown.                     |
| `Agenda.TUI.ItemProperties`                   | ✔     | The Item Properties box: text, note, statistics and the item's assignments (R34).                                                |
| `Agenda.TUI.SortBox`                          | ✔     | The Sort box: a view's or a section's sort keys (R36).                                                                           |
| `Agenda.TUI.SearchBox`                        | ✔     | The Search box and search mode (ALT-N / ALT-P / F7), and the Show View (R37).                                                    |
| `Agenda.TUI.QuestionsBox`                     | ✔     | Utilities Questions: confirming suggested assignments (R16).                                                                     |
| `Agenda.TUI.ExecuteBox`                       | ✔     | Utilities Execute: the Execute box, ALT-X and ALT-E (R15e).                                                                      |
| `Agenda.TUI.ActionBox`                        | ✔     | The Date Action / Numeric Action box (R15b).                                                                                     |
| `Agenda.TUI.RangeFilterBox`                   | ✔     | The Date Filter / Numeric Filter box (R28a).                                                                                     |
| `Agenda.TUI.ColumnBox`                        | ✔     | The Column Properties box, one for every column: head, width, link (R55); a numeric column's format (R29), a date column's (R41a). |
| `Agenda.TUI.FileProperties`                   | ✔     | The File Properties box: the date display format, with a sample (R41).                                                           |
| `Agenda.TUI.DateFormatRows`                   | ✔     | The date display settings as box rows, shared by File and Column Properties (R41a).                                              |
| `Agenda.TUI.InputFormatBox`                   | ✔     | The Input Format box: the person's number order, separator and clock, saved as preferences (R41b).                               |
| `Agenda.TUI.CustomizeBox`                     | ✔     | File ▸ Customize: the person's theme and date languages, saved as preferences (R40, R14c).                                       |
| `Agenda.TUI.CalendarBox`                      | ✔     | The pop-up calendar: F3 in a date column, ALT-C anywhere (R46).                                                                  |
| `Agenda.TUI.DatebookBox`, `Agenda.TUI.Browse` | ✔     | A datebook view's settings box; browsing it to other periods (R47).                                                              |
| `Agenda.TUI.ScheduleBox`                      | ✔     | Search ▸ Schedule: one date's items in the Show View (R49).                                                                      |
| `Agenda.TUI.MacroKeys`                        | ✔     | Key events as macro text in Agenda's notation (`{F10}vc{ENTER}`), and back (R50).                                                |
| `Agenda.TUI.Macros`                           | ✔     | The macro manager (ALT-F3), Learn mode and running macros (ALT-Z), one undo step a run (R50).                                    |
| `Agenda.TUI.MacroProps`                       | ✔     | The Macro Properties box: name, keystrokes, attached key, where it runs (R50).                                                   |
| `Agenda.TUI.SelectFile`                       | ✔     | The Select File box: F3 in a file-name prompt lists a folder (read by `Store.list_dir/1`) to pick from (R51).                    |
| `Agenda.TUI.Splash`                           | ✔     | The splash screen at start, until a key or three seconds; the startup prompt waits under it (R52).                               |
| `Agenda.TUI.CalendarsBox`                     | ✔     | File ▸ Transfer ▸ Calendars: subscribe, read now, how often and how far ahead (R45).                                             |
| `Agenda.TUI.NoteSearch`                       | ✔     | The Search/Replace box in a note, ALT-S, and confirming each replacement (R39).                                                  |
| `Agenda.TUI.AlarmList`                        | ✔     | The alarm list box: current and past alarms (R38).                                                                               |
| `Agenda.TUI.DevTools`                         | ✔     | The hidden developer screen (ESC ?): state for debugging, and a key tester.                                                      |
| `Agenda.TUI.Render`                           | ✔     | State → list of styled lines: the control panel, the body (the view or a full screen), the boxes over it, the key bar.           |
| `Agenda.TUI.Render.*`                         | ✔     | Its parts: `ControlPanel`, `View`, `Managers`, `Note`, `Help` (F1 text), `Boxes`, `CategoryBoxes`, `KeyBar`, `Text`, `Export`.   |
| `Agenda.TUI.Draw`, `Agenda.TUI.Theme`         | ✔     | Line/box primitives; symbolic style → ANSI codes in the chosen theme (classic, blue or mono, R40).                               |
| `Agenda.TUI.Template`                         | ✔     | Box layouts written as they look: `[field   ]` in brackets, filled and lined up; the fields' order is the cursor's.                |
| `Agenda.TUI.Keys`                             | ✔     | Raw input bytes → key events (xterm sequences, ALT, ESC-digit aliases).                                                          |
| `Agenda.TUI.LineEdit`, `Agenda.TUI.TextEdit`  | ✔     | Single-line and multi-line edit buffers.                                                                                         |
| `Agenda.TUI.Screen`                           | ✔     | Diffs two frames into minimal ANSI output.                                                                                       |
| `Agenda.TUI.Terminal`                         | ✘     | Raw mode, alternate screen, size, input reader process.                                                                          |
| `Agenda.TUI.App`                              | ✘     | Main loop: read → decode → update → run effects → render.                                                                        |
| `Agenda.Store`                                | ✘     | Save/load (`term_to_binary` in a versioned envelope, atomic write); folder listings for the Select File box.                     |
| `Agenda.Preferences`                          | ✘     | The person's preferences file: theme, languages, input format (with the number separators), key map, confirm mode, auto-save, name, company, last file (`key = value`, ADR 0008).               |
| `Agenda.CalendarFetch`                        | ✘     | Downloads a subscribed calendar (HTTPS, `:httpc`) and reads its events (R45).                                                    |
| `Agenda.CLI`                                  | ✘     | `main/1` for the escript.                                                                                                        |

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

## Developer tools

- `ESC ?` in the program: debugging info and a key tester (`Agenda.TUI.DevTools`).
- `tools/screenshots/`: draws screens of the TUI as PNGs (macOS), to
  compare its look with Agenda 2.0 (ADR 0018):
  `MIX_ENV=test mix run tools/screenshots/screenshots.exs [--theme NAME]`
  writes them to `tmp/screenshots/`. `screenshots.exs` drives the TUI with
  keys like the tests; `render.swift` draws each screen.

## Architecture decision records

| ADR                                                     | Decision                                                         |
| ------------------------------------------------------- | ---------------------------------------------------------------- |
| [0001](adr/0001-functional-core-imperative-shell.md)    | Functional core, imperative shell; Elm-style TUI                 |
| [0002](adr/0002-own-terminal-layer.md)                  | Our own terminal layer on OTP raw mode, no TUI library           |
| [0003](adr/0003-file-format.md)                         | File format: versioned Erlang terms, upgraded on load            |
| [0004](adr/0004-links-stored-membership-computed.md)    | Store explicit links, compute membership                         |
| [0005](adr/0005-undo-by-snapshots.md)                   | Undo by database snapshots, recorded automatically               |
| [0006](adr/0006-fidelity-and-extensions.md)             | Faithful to Agenda 2.0, with marked extensions                   |
| [0007](adr/0007-keyboard-strategy.md)                   | Agenda's keys first, with alternatives that always work          |
| [0008](adr/0008-file-settings-and-personal-settings.md) | What belongs in the file, and what belongs to the person         |
| [0009](adr/0009-date-language-packs-and-context.md)     | Date language packs, and a context passed to the core            |
| [0010](adr/0010-data-interchange.md)                    | Data interchange: JSON (built), and Agenda's structured files    |
| [0011](adr/0011-conditions-and-actions-settle.md)       | Conditions and actions run in one step after every change        |
| [0012](adr/0012-quality-gate.md)                        | The quality gate: formatter, compiler, Credo, Dialyzer, tests    |
| [0013](adr/0013-reading-dates-file-and-reader.md)       | Reading dates: the file's settings and the reader's language     |
| [0014](adr/0014-negative-links.md)                      | Negative links between any two categories (an extension)         |
| [0015](adr/0015-date-categories-dates-and-rules.md)     | Dates of date categories, and the rules that set them            |
| [0016](adr/0016-global-defaults-local-overrides.md)     | File-wide defaults, with local overrides stored as differences   |
| [0017](adr/0017-text-matching-agenda-rules.md)          | Text matching follows Agenda's word rules                        |
| [0018](adr/0018-agenda-look-from-screenshots.md)        | The look follows screenshots of the real Agenda                  |
| [0019](adr/0019-the-name-wols-agendum.md)               | The name: Wol's Agendum                                          |
| [0020](adr/0020-towards-many-users.md)                  | Towards many users: a web application on the same core           |
| [0021](adr/0021-runtime-dependencies.md)                | Runtime dependencies: only when they keep what the rule protects |
| [0022](adr/0022-themes-not-custom-colours.md)           | Themes, not custom colours                                       |
