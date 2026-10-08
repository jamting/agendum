# CLAUDE.md — working on the Lotus Agenda clone

A clone of Lotus Agenda (1988, DOS) in Elixir: a **pure functional core** plus a
**terminal UI** that resembles the original. Read `docs/SPEC.md` (what Agenda
does) and `docs/ARCHITECTURE.md` (how the code is laid out) before larger changes.
For anything touching stored data or queries, also read `docs/DATA_MODEL.md`
and `docs/DATA_ACCESS.md`, and keep them up to date (Mermaid diagrams included).

## Commands

```sh
mix check                 # THE quality gate: format check + warnings-as-errors + tests
mix test                  # tests only
mix test test/agenda/core # one directory
mix run -e 'Agenda.CLI.main(["--demo"])'   # run the TUI with sample data (needs a real terminal)
mix escript.build && ./agenda my.agenda    # build and run the standalone binary
```

A change is done when `mix check` passes. Do not leave warnings.

## Architecture rules (do not break these)

1. **`lib/agenda/core/**` and `lib/agenda/core.ex` are pure.** No I/O, no
   processes, no clock (`Date.utc_today/0` etc.), no randomness. Anything
   external, like today's date, is passed in as an argument.
2. **The TUI is Elm-style.** `Agenda.TUI.Update.handle(state, key)` is pure and
   returns `{state, effects}`; `Agenda.TUI.Render.render(state)` is pure and
   returns styled lines. Only `Terminal`, `App`, `Store` and `CLI` touch the
   outside world. New side effects become new effect tuples handled in `App`.
3. The TUI calls the core through `Agenda.Core` (the facade) and reads the
   database through `Agenda.Core.Database` queries. It never calls
   `Database` write functions; `test/agenda/architecture_test.exs` fails if
   it does. Add a facade function instead. Assignment rules live
   only in `Agenda.Core.Assign`; never re-implement them in the UI.
4. Subsumption (membership in ancestors) is **computed, never stored**. Only
   explicit links are stored (`Agenda.Core.Links`).
5. No runtime dependencies. The terminal layer uses OTP 28+ raw mode, not a
   TUI library (see `docs/adr/0002-own-terminal-layer.md`).
6. Keep everything a second front end (e.g. web) would need in `Agenda.Core`;
   the TUI only handles keys and drawing. A web app on the same core is a
   planned idea (`docs/ROADMAP.md`).

## Workflow for a feature

1. Find or add the behaviour in `docs/SPEC.md` (rules are numbered, e.g. `R7`).
2. Write a failing test first:
   - core rules → `test/agenda/core/*_test.exs` (use `Agenda.Fixtures`)
   - UI behaviour → `test/agenda/tui/*_test.exs`: drive keys with
     `Agenda.TUIHelpers.press/2` and assert on `screen/1` text
3. Implement it in the core first, then wire it into the TUI.
4. Run `mix check`. Update `docs/ROADMAP.md` (tick the box) and the help text
   in `Agenda.TUI.Render` if keys changed.

Keep changes small and focused; one feature per commit.

## Conventions

- Match the surrounding style: small pure functions, pattern matching,
  `@spec` on public core functions, `@moduledoc` on every module.
- Core functions that can fail return `{:ok, ...} | {:error, atom}`; the UI
  turns error atoms into messages.
- Ids are positive integers from one shared counter (`db.next_id`).
- Dates display as ISO 8601 (`DateParser.format/1` is the single place).
- Keys are decoded in `Agenda.TUI.Keys`. Function keys may be awkward in
  some terminals, so every F-key also works as ESC + digit, and ALT-Fn as
  ESC + shifted digit. Keep an alternative whenever you add a key: Mac
  keyboards lack INS/HOME/END and terminals never pass ⌘, so every command
  needs a CTRL (or ESC-prefixed) key. Document it in `docs/KEYBOARD.md` and
  the F1 help. CTRL-I/M/H/[ are unusable (they are TAB/ENTER/BACKSPACE/ESC).
- Undo is automatic: any key that changes `state.db` records one step in
  `TUI.History`. Do not record history by hand. Keep one user action = one
  database change, so one undo reverses it.

## Testing the real terminal

Unit tests cover everything except the raw terminal. To smoke-test it without
a human, drive the app through a pseudo-terminal (Python `pty`), send keys,
and look at the output. In raw mode the tty must not intercept control keys;
`Terminal` turns off `ixon`, `isig` and `iexten` for that reason.

## Reference material

- `docs/AGENDA_HISTORY.md`: why people used Agenda and what made it unique;
  read it to judge which behaviours matter most to users.
- `docs/reference/US5115504.pdf`: the Agenda patent (data model).
- Lotus Agenda 2.0 manuals (User's Guide, Quick Start) on archive.org:
  https://archive.org/details/lotus-agenda-users-guide. The `_djvu.txt`
  files are searchable plain text and are good for checking original behaviour.
