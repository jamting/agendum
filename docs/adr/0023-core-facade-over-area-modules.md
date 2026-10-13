# ADR 0023 — The core facade: one entry point over area modules

**Status:** accepted · 2026-10-13

## Context

The TUI calls the core only through `Agenda.Core` (CLAUDE.md rule 3), and
the architecture test fails if it calls `Database` write functions. That
kept the UI thin, but `lib/agenda/core.ex` had grown to about 2,300 lines:
every user-level operation (items, assignments, dates, alarms, numbers,
rules, categories, views, macros, calendars, files), with its docs and
specs, plus the helpers they share. `tui/render.ex` (~2,300 lines),
`tui/update.ex` (~2,000) and `tui/category_screens.ex` (~1,200) had the
same problem. Big files were hard to find things in, hard to review, and
a lot to read for the owner, who is new to Elixir.

There were two ways to split the facade:

- let the TUI call the area modules directly, with no facade, or
- keep `Agenda.Core` as the only entry point and move the code behind it.

A second front end, the web application (ADR 0020), will need the same
entry point, and later a command layer on top of it.

## Decision

- `Agenda.Core` stays the one entry point for front ends. It becomes a
  table of contents: a list of `defdelegate`s, grouped by area.
- The functions, with their `@doc` and `@spec`, live in area modules
  under `lib/agenda/core/facade/`: `Files`, `Items`, `Assignments`,
  `Dates`, `Alarms`, `Numbers`, `Dependencies`, `Rules`, `Categories`,
  `Views`, `Macros`, `Calendars`.
- What every change to an item goes through (user assignments, dates from
  rules, settling conditions and actions, ADR 0011) is in
  `Agenda.Core.Facade.Changes`, which the area modules share. Front ends
  do not call it.
- A new user-level operation goes into the area module it belongs to and
  gets a `defdelegate` in `Agenda.Core`. The front end calls
  `Agenda.Core.f`, never `Agenda.Core.Facade.Area.f`.
- The large TUI files are split the same way, by the sections they
  already had: `tui/render/`, `tui/update/` and `tui/category_screens/`.
  `Render.render/1` and `Update.handle/2` stay where they were and
  dispatch to the new modules.
- The splits only moved code. Behaviour and public functions stayed the
  same, and each file was split in a commit of its own.

## Consequences

- Rule 3 and its architecture test did not change, and no caller had to
  change. A front end still sees one module, now short enough to read as
  a list of what the core can do.
- Each area can be read, documented (`mix docs`) and reviewed on its own.
  The learning comments started with the facade's area modules.
- Adding an operation now takes two edits (the area module and the
  `defdelegate`). A forgotten `defdelegate` shows up at once: the compiler
  warns about the undefined function, and `mix check` fails.
- The command layer planned in ADR 0020 has natural places to start: one
  area module at a time, and `Update.Actions` on the TUI side.
- Grouping the small TUI modules into subfolders waits for the code
  rename (ADR 0019), so that module names change only once.
