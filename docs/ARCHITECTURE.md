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
               │                      │ Agendum.Core (facade)                │  │
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

### Core (`lib/agendum/core*`) — pure

| Module                                                         | Responsibility                                                                                                                                          |
| -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Agendum.Core`                                                  | Facade with user-level operations (add item, assign by name, add section…): a table of contents of `defdelegate`s. The UI uses this.                    |
| `Agendum.Core.Facade.*`                                         | Its areas: `Files`, `Items`, `Assignments`, `Dates`, `Alarms`, `Numbers`, `Dependencies`, `Rules`, `Categories`, `Views`, `Macros`, `Calendars`.        |
| `Agendum.Core.Facade.Changes`                                   | What every change to an item goes through: user assignments, dates from rules, settling (conditions, actions).                                          |
| `Agendum.Core.Database`                                         | The file as one immutable struct: items, categories, views, links, id counter. Primitive operations and queries (`member?/3`, `items_in/2`, hierarchy). |
| `Agendum.Core.Invariants`                                       | The data model's invariants as one check (`violations/1`), run after every key by the fuzz walks (DATA_MODEL.md, "Invariants").                    |
| `Agendum.Core.Links`                                            | Bidirectional many-to-many relation (the patent's link structures).                                                                                     |
| `Agendum.Core.Assign`                                           | Assignment rules: exclusion, category links, text matching, ambiguity resolution.                                                                       |
| `Agendum.Core.ViewModel`                                        | Read model: projects a view to sections, rows and column cells.                                                                                         |
| `Agendum.Core.ViewColumns`                                      | Columns per section (R55): adding to one section or all, linked columns changing together, removing from one section or all.                            |
| `Agendum.Core.Datebook`                                         | Datebook views: their settings, the time slots of a period, which items a slot shows (R47).                                                             |
| `Agendum.Core.MonthCalendar`                                    | The pop-up calendar's month as weeks, and the moves of its highlight (R46).                                                                             |
| `Agendum.Core.Macro`                                            | A macro kept in the file: name, keystrokes in Agenda's notation, attached key, where it runs (R50).                                                     |
| `Agendum.Core.DateParser`                                       | Date expressions relative to a given `today`.                                                                                                           |
| `Agendum.Core.TextCondition`                                    | Agenda's "Also match" text conditions: `;` any, `,` all, `!`, `~`, `^`, wildcards (R15d).                                                               |
| `Agendum.Core.TextMatch`                                        | How a file matches text to categories: on/off, match on, strength, enclosed text, suffixes, accents (R16a), proper names (R16c).                        |
| `Agendum.Core.Recurrence`                                       | The rule of a recurring When date and the next date from a base date (R14a).                                                                            |
| `Agendum.Core.Context`                                          | The time, date languages and input format (R14c, R41b), passed wherever typed dates are read; `parser_opts/2` adds the file's `DateSettings`; `prepare/1` carries the date rules compiled once (ADR 0035). |
| `Agendum.Core.InputFormat`                                      | How one person types dates: number order, date separator, 12/24-hour clock; nil is the language's (R41b).                                               |
| `Agendum.Core.JSONFile`                                         | A whole file as JSON and back, checked on import (R44; schema in `JSON_FORMAT.md`).                                                                     |
| `Agendum.Core.ICal`                                             | Reads the events of an iCalendar (`.ics`) file: title, description, start, repeat rule, status (R45).                                                   |
| `Agendum.Core.ICal.TimeZone`                                    | A calendar's own time zones (VTIMEZONE): a time in a named zone to UTC, without a time-zone database (R45).                                             |
| `Agendum.Core.Calendar`, `Agendum.Core.CalendarSync`             | A calendar subscription; a refresh applied to the file, mirroring the calendar (R45).                                                                   |
| `Agendum.Core.DateLanguage` (+ `English`, `Swedish`)            | Language packs for reading dates: words, phrase patterns, day/month order, clock (R14c). `DateParser` does the arithmetic.                              |
| `Agendum.Core.Search`                                           | Text search: whether an item's text or note matches (R37).                                                                                              |
| `Agendum.Core.RangeFilter`                                      | Date and numeric filter ranges: checking, matching, the value a new item gets (R28a).                                                                   |
| `Agendum.Core.NumberFormat`                                     | Reading and showing numbers, and the calculations of numeric columns (R29).                                                                             |
| `Agendum.Core.DateFormat`                                       | How a file or date column displays dates and times: order, separator, clock, Relative, Week # (R41, R41a).                                              |
| `Agendum.Core.DateRule`                                         | How a date category gets dates: Assign item date, Which one, Done and When keys (R6b).                                                                  |
| `Agendum.Core.DateSettings`                                     | How a file reads dates: week, quarter and year boundaries, month alone, morning/afternoon/evening (R14e).                                               |
| `Agendum.Core.TextSearch`                                       | Finding and replacing literal text in a note's lines (R39).                                                                                             |
| `Agendum.Core.Item`, `Agendum.Core.Category`, `Agendum.Core.View` | Plain structs.                                                                                                                                          |

### TUI (`lib/agendum/tui/*`)

Every screen, box and control-panel mode, and how each is reached, is mapped
in [`SCREENS.md`](SCREENS.md).

The folder keeps at its top what everything goes through (`State`,
`Update`, `Render`, `App`, `Layout`, `Menu`, `History`, the macros, the
splash and developer screens, `DebugLog`, `CategoryScreens`), and groups
the rest by what it is for:

- `tui/boxes/` (`Agendum.TUI.Boxes.*`): every box, and the machinery they
  share: `Box` (the behaviour a box module implements, and the registry
  from mode type to module), `Template` (layouts), `BoxNav` (moving),
  `BoxCancel` (ESC), `BoxChoices` (letters and F3), `FieldHelp`,
  `FieldTyping`. Every box keeps everything about it in its own module:
  keys, drawing, key bar, help, how it ends (docs/plans/REFACTORING.md, step 3).
  `Update` sends a box its keys, and `Render.Boxes` draws its frame, through
  the registry. A new box is a module with `use Agendum.TUI.Boxes.Box` and
  its options (`finish:`, `indicator:`, `cancels:`, `choices:`), the
  callbacks (`handle/3`, `title/2`, `content/4`, `keys/2`, `help/0`;
  `field/2`, `width/2`, `finish/1` where needed), and a line in
  `Box.registry/0`. A box with fixed settings is drawn from a `Template`
  layout; the lists (pickers, profiles, calendar, macros, files, views)
  draw their own rows;
- `tui/terminal/` (`Agendum.TUI.Terminal.*`): keys in, screen out: `Keys`,
  `Screen`, `Draw`, `Theme` and its palettes (`Agendum.TUI.Terminal` itself,
  the raw terminal, is the folder's parent module);
- `tui/typing/` (`Agendum.TUI.Typing.*`): typing text: `LineEdit`,
  `TextEdit`, `Completion`, `NoteSearch`;
- `tui/moves/` (`Agendum.TUI.Moves.*`): the control-panel modes that move
  something: `Browse`, `ColumnMove`, `ColumnWidth`, `SectionMove`;
- `tui/render/`, `tui/update/`, `tui/category_screens/`: the parts of
  `Render`, `Update` and `CategoryScreens`.

| Module                                        | Pure? | Responsibility                                                                                                                   |
| --------------------------------------------- | ----- | -------------------------------------------------------------------------------------------------------------------------------- |
| `Agendum.TUI.State`                            | ✔     | UI state: db, path, cursor, scroll, **mode stack**, inline edit, message, queued effects.                                        |
| `Agendum.TUI.Update`                           | ✔     | Key → state transitions: keys for every screen, the clock (`tick/2`), effect results, dispatch to the screen on top.             |
| `Agendum.TUI.Update.*`                         | ✔     | Its parts: `ViewKeys` (the view's keymap lookup and `run`), `Editing` (inline), `Marked` (and moves), `Prompts` (and Y/N), `Notes`, `Actions` (`perform/2`).          |
| `Agendum.TUI.Command`, `Agendum.TUI.Commands`, `Agendum.TUI.CommandDocs`  | ✔     | The commands keys can run, as data: id, name, summary, a longer text (R65b), what a count does; by place: the view's, a note's, the menu's, the category and view managers', every box's shared ones and the global ones so far; a box's own are in its module (`Box.keymap/1`, `commands/1`, `run/3`, `typing?/2`) (R65, ADR 0033).          |
| `Agendum.TUI.Keymap`                           | ✔     | Which command a key runs, by place (the view, a note, the menu, the moves and searching, typing on a line and in a note, the category and view managers, the keys every box shares, the global keys), the keys that stand for others (CTRL-N = INS) and key names (R65, ADR 0033). |
| `Agendum.TUI.HelpScreen`                       | ✔     | The help screen (F1): a text about where you are, `c` the command list, `d` describe key, `a` all keys (R65).                                               |
| `Agendum.TUI.Menu`                             | ✔     | The Lotus two-line menu tree.                                                                                                    |
| `Agendum.TUI.Boxes.Box`                              | ✔     | The behaviour of a box module (handle, title, content, keys, help, width; finish, indicator, cancels, choices) and the registry of box modules. |
| `Agendum.TUI.Boxes.BoxNav`                           | ✔     | Moving between a box's settings as Agenda: → ← along a row, ↓ ↑ keeping to the side (`Template.grid/2`).                         |
| `Agendum.TUI.Boxes.BoxChoices`                       | ✔     | A setting's choices (what SPACE goes through): the first letter picks one, F3 lists them.                                        |
| `Agendum.TUI.Boxes.ChoiceListBox`                    | ✔     | The list of a setting's choices that F3 opens.                                                                                   |
| `Agendum.TUI.Boxes.BoxCancel`                        | ✔     | ESC cancels a settings box: the file and preferences as they were when it opened (ADR 0030).                                     |
| `Agendum.TUI.Boxes.FieldHelp`                        | ✔     | Help for a box's highlighted field, in the control panel (SPEC §5).                                                              |
| `Agendum.TUI.CategoryScreens`                  | ✔     | Hierarchy screens: opening them, their rows, cursor, collapsing families, inline edits, dispatch to the parts.                   |
| `Agendum.TUI.CategoryScreens.*`                | ✔     | Its parts: `Manager` (F9), `Picker`, `Profile` (F3), `Properties` (F6), `Choices` (exclusive children, moves).                   |
| `Agendum.TUI.Boxes.ViewManager`                      | ✔     | View manager.                                                                                                                    |
| `Agendum.TUI.Layout`                           | ✔     | Flattens a view to cursor rows and wrapped lines; keeps the cursor anchored and visible.                                         |
| `Agendum.TUI.Typing.Completion`                       | ✔     | Automatic completion while typing a column entry: the matches (from `Core.completions/3`) and the one shown.                     |
| `Agendum.TUI.Boxes.ItemProperties`                   | ✔     | The Item Properties box: text, note, statistics and the item's assignments (R34).                                                |
| `Agendum.TUI.Boxes.SortBox`                          | ✔     | The Sort box: a view's or a section's sort keys (R36).                                                                           |
| `Agendum.TUI.Boxes.SearchBox`                        | ✔     | The Search box and search mode (ALT-N / ALT-P / F7), and the Show View (R37).                                                    |
| `Agendum.TUI.Boxes.GoTo`                             | ✔     | ALT-F5 GO TO: a box listing the view's section heads (R42).                                                                       |
| `Agendum.TUI.Boxes.CopyBox`                          | ✔     | ALT-F9 COPY: the view's sections, to put the item in one as well (R42).                                                           |
| `Agendum.TUI.Boxes.QuestionsBox`                     | ✔     | Utilities Questions: confirming suggested assignments (R16).                                                                     |
| `Agendum.TUI.Boxes.ExecuteBox`                       | ✔     | Utilities Execute: the Execute box, ALT-X and ALT-E (R15e).                                                                      |
| `Agendum.TUI.Boxes.ActionBox`                        | ✔     | The Date Action / Numeric Action box (R15b).                                                                                     |
| `Agendum.TUI.Boxes.RangeFilterBox`                   | ✔     | The Date Filter / Numeric Filter box (R28a).                                                                                     |
| `Agendum.TUI.Boxes.CategoryStatsBox`                 | ✔     | Category Statistics: how much of the file uses a category (Category Properties ▸ Statistics).                                     |
| `Agendum.TUI.Boxes.FileStatsBox`                     | ✔     | File Statistics: the items, those with notes, the categories, and the averages (File Properties ▸ File statistics).               |
| `Agendum.TUI.Boxes.CategoryMatchBox`                 | ✔     | A standard category's Advanced settings: its own text matching (R16b).                                                            |
| `Agendum.TUI.Boxes.DateRuleBox`                      | ✔     | A date category's Advanced settings: Assign item date, Which one, Done and When keys (R6b).                                       |
| `Agendum.TUI.Boxes.AutoAssignBox`                    | ✔     | File Properties ▸ Auto-assign settings: the file's text matching and confirming (R16, R16a).                                       |
| `Agendum.TUI.Boxes.ColumnAddBox`                     | ✔     | The Column Add box: a new column's head, width, position and Insert in (R55).                                                      |
| `Agendum.TUI.Boxes.ItemColumnBox`                    | ✔     | Item Column Properties: a section's item column, automatic or by hand, linked (R55).                                               |
| `Agendum.TUI.Boxes.SectionBox`                       | ✔     | The Section Properties box: head, sorting, statistics, filter and the section's columns (R61).                                    |
| `Agendum.TUI.Boxes.NumericFunctionsBox`              | ✔     | Select Numeric Functions: the calculations of a section's numeric columns (R61, R29).                                             |
| `Agendum.TUI.Boxes.FieldTyping`                      | ✔     | Typing text into a box's field: a column head's name (an existing category or a new one), a column title.                          |
| `Agendum.TUI.Boxes.ColumnBox`                        | ✔     | The Column Properties box, one for every column: head, width, link (R55); a numeric column's format (R29), a date column's (R41a). |
| `Agendum.TUI.Boxes.FileProperties`                   | ✔     | The File Properties box: Insert new columns in, and the boxes of date and auto-assign settings (R55).                             |
| `Agendum.TUI.Boxes.DateFormatRows`                   | ✔     | The date display settings as box rows, shared by File and Column Properties (R41a).                                              |
| `Agendum.TUI.Boxes.DateSettingsBox`                  | ✔     | Global Date Settings: the file's week, quarter, year and times of day (R14e).                                                     |
| `Agendum.TUI.Boxes.DisplayFormatBox`                 | ✔     | Display Format: how the file shows dates and times, with a sample (R41).                                                          |
| `Agendum.TUI.Boxes.InputFormatBox`                   | ✔     | The Input Format box: the person's number order, separator and clock, saved as preferences (R41b).                               |
| `Agendum.TUI.Boxes.CustomizeBox`                     | ✔     | File ▸ Customize: the person's theme and date languages, saved as preferences (R40, R14c).                                       |
| `Agendum.TUI.Boxes.CalendarBox`                      | ✔     | The pop-up calendar: F3 in a date column, ALT-C anywhere (R46).                                                                  |
| `Agendum.TUI.Boxes.DatebookBox`, `Agendum.TUI.Moves.Browse` | ✔     | A datebook view's settings box; browsing it to other periods (R47).                                                              |
| `Agendum.TUI.Boxes.ScheduleBox`                      | ✔     | Search ▸ Schedule: one date's items in the Show View (R49).                                                                      |
| `Agendum.TUI.MacroKeys`                        | ✔     | Key events as macro text in Agenda's notation (`{F10}vc{ENTER}`), and back (R50).                                                |
| `Agendum.TUI.Macros`                           | ✔     | The macro manager (ALT-F3), Learn mode and running macros (ALT-Z), one undo step a run (R50).                                    |
| `Agendum.TUI.Boxes.MacroProps`                       | ✔     | The Macro Properties box: name, keystrokes, attached key, where it runs (R50).                                                   |
| `Agendum.TUI.Boxes.SelectFile`                       | ✔     | The Select File box: F3 in a file-name prompt lists a folder (read by `Store.list_dir/1`) to pick from (R51).                    |
| `Agendum.TUI.Splash`                           | ✔     | The splash screen at start, until a key or three seconds; the startup prompt waits under it (R52).                               |
| `Agendum.Sample`                                | ✔     | The built-in files: `--demo` (the patent's example, used by the tests) and `--rabbit` (Rabbit's file from the manual).            |
| `Agendum.TUI.Boxes.CalendarsBox`                     | ✔     | File ▸ Transfer ▸ Calendars: subscribe, read now, how often and how far ahead (R45).                                             |
| `Agendum.TUI.Typing.NoteSearch`                       | ✔     | The Search/Replace box in a note, ALT-S, and confirming each replacement (R39).                                                  |
| `Agendum.TUI.Boxes.AlarmList`                        | ✔     | The alarm list box: current and past alarms (R38).                                                                               |
| `Agendum.TUI.DevTools`                         | ✔     | The hidden developer screen (ESC ?): state for debugging, and a key tester.                                                      |
| `Agendum.Starters.Planner`                     | ✔     | The Activities Planner starter file, built through `Agendum.Core` (R60, ADR 0028); `Planner.Views`, `Planner.Macros`, `Planner.Samples` (sample data). |
| `Agendum.Starters.Clinic`                      | ✔     | An Easter egg and showcase (`agendum --clinic`): Christopher Robin's psychotherapy clinic, mid-work, dated from today; `Clinic.Items`, `Clinic.Views`. |
| `Agendum.Starters.Golden`                      | ✔     | The golden file of the format: the Planner with samples plus everything it leaves unused, so every stored field is set; `facts/1` (DATA_MODEL.md, "On disk"). |
| `Mix.Tasks.Agendum.Golden`                    | ✘     | `mix agendum.golden`: writes the current format version's golden file and its facts to `test/fixtures/formats/`, never over an existing one. |
| `Mix.Tasks.Agendum.Starters`                  | ✘     | `mix agendum.starters [--samples]`: writes the starter file (a build tool, not part of the program).                             |
| `Agendum.TUI.Render`                           | ✔     | State → list of styled lines: the control panel, the body (the view or a full screen), the boxes over it, the key bar.           |
| `Agendum.TUI.Render.*`                         | ✔     | Its parts: `ControlPanel`, `View`, `Managers`, `Note`, `Help` (F1 then a: all keys, from the keymaps), `Boxes`, `KeyBar`, `Text`, `Export`.   |
| `Agendum.TUI.Terminal.Draw`, `Agendum.TUI.Terminal.Theme`         | ✔     | Line/box primitives; symbolic style → ANSI codes in the chosen theme (classic, mono and the terminal schemes, R40).                               |
| `Agendum.TUI.Terminal.Theme.Palettes`                 | ✔     | The themes made from terminal colour schemes (`THEMES.md`, R40).                                                                 |
| `Agendum.TUI.Boxes.Template`                         | ✔     | Box layouts written as they look: `[field   ]` in brackets, filled and lined up; the fields' order is the cursor's.                |
| `Agendum.TUI.Terminal.Keys`                             | ✔     | Raw input bytes → key events (xterm sequences, ALT; ESC + a key arriving together is ALT, as Option as Meta sends it, ADR 0032).                                                          |
| `Agendum.TUI.Typing.LineEdit`, `Agendum.TUI.Typing.TextEdit`  | ✔     | Single-line and multi-line edit buffers.                                                                                         |
| `Agendum.TUI.Typing.Wrap`                             | ✔     | Word wrap in the note editor, for the screen only: a note's lines as rows (R64).                                                  |
| `Agendum.TUI.Terminal.Screen`                           | ✔     | Diffs two frames into minimal ANSI output.                                                                                       |
| `Agendum.TUI.Terminal`                         | ✘     | Raw mode, alternate screen, size, input reader process.                                                                          |
| `Agendum.TUI.App`                              | ✘     | Main loop: read → decode → update → run effects → render.                                                                        |
| `Agendum.TUI.DebugLog`                         | ✘     | The debug log when `AGENDUM_LOG` is set: build, input, timed effects, file fingerprints, slow answers with view and memory, crashes with the state; five kept (ADR 0027). |
| `Agendum.Store`                                | ✘     | Save/load (`term_to_binary` in a versioned envelope, atomic write); folder listings for the Select File box.                     |
| `Agendum.Preferences`                          | ✘     | The person's preferences file: theme, languages, input format (with the number separators), key map, confirm mode, auto-save, name, company, last file (`key = value`, ADR 0008).               |
| `Agendum.CalendarFetch`                        | ✘     | Downloads a subscribed calendar (HTTPS, `:httpc`) and reads its events (R45).                                                    |
| `Agendum.CLI`                                  | ✘     | `main/1` for the escript.                                                                                                        |

## Key design decisions

- **Mode stack.** Overlays (menu, managers, pickers, prompts) are pushed
  on `state.modes`; ESC pops. Full-screen modes (category manager, view
  manager, note) replace the body; boxes (picker, profile,
  properties) draw over it. Help is a full-screen mode drawn as a large
  box over the faded screen it was opened from, boxes and all (R65c).
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

- `ESC ?` in the program: debugging info and a key tester (`Agendum.TUI.DevTools`).
- `AGENDUM_LOG=1`: a debug log of each session in `~/.local/state/agendum/logs`
  (or `AGENDUM_LOG=FOLDER`), the last five kept; a crash writes its stack
  trace and the state (`Agendum.TUI.DebugLog`, ADR 0027).
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
| [0023](adr/0023-core-facade-over-area-modules.md)       | The core facade: one entry point over area modules               |
| [0024](adr/0024-boxes-drawn-from-layouts.md)            | Settings boxes are drawn from layouts written as they look       |
| [0025](adr/0025-columns-per-section.md)                 | Columns belong to sections, linked by a shared number            |
| [0026](adr/0026-previewing-a-change.md)                 | Previewing a change before it is kept                            |
| [0027](adr/0027-debug-log.md)                           | A debug log of each session, on by an environment variable       |
| [0028](adr/0028-starter-files-built-from-code.md)       | Starter files are built from code, the committed file kept equal |
| [0029](adr/0029-stored-date-phrases-read-in-english-too.md) | Stored date phrases are read in the reader's languages, then English |
| [0030](adr/0030-enter-done-esc-cancels-in-boxes.md)     | In a settings box, ENTER is done and ESC cancels                 |
| [0031](adr/0031-box-keys-as-agenda.md)                  | Keys in a box as Agenda: the arrows move, SPACE changes          |
| [0032](adr/0032-function-keys-required.md)              | Function keys are required: no ESC + digit stand-in              |
| [0033](adr/0033-commands-and-keymaps.md)               | Keys run named commands through keymaps; a count with ALT-digits |
| [0034](adr/0034-format-of-record.md)                   | The format of record: Erlang terms now, a database for many users, JSON for people |
| [0035](adr/0035-caches-travel-in-values.md)            | Caches travel in values the shell keeps                          |
