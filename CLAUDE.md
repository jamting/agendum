# CLAUDE.md — working on Wol's Agendum

**Wol's Agendum** (short: **Agendum**) is a clone of Lotus Agenda (1988, DOS) in
Elixir: a **pure functional core** plus a **terminal UI** that resembles the
original. Read `docs/SPEC.md` (what Agenda
does) and `docs/ARCHITECTURE.md` (how the code is laid out) before larger changes,
and the ADRs in `docs/adr/` (why); record new lasting decisions as ADRs.
For anything touching stored data or queries, also read `docs/DATA_MODEL.md`
and `docs/DATA_ACCESS.md`, and keep them up to date (Mermaid diagrams included);
a new stored field also needs a place in the JSON schema (`Agendum.Core.JSONFile`,
`docs/JSON_FORMAT.md`), or the round-trip tests fail.
`docs/INDEX.md` lists every document, what it is for, and which ones a
change must update.

## Commands

```sh
mix check                 # THE quality gate: format, warnings-as-errors, Credo, Dialyzer, tests
mix test                  # tests only
mix test test/agendum/core # one directory
mix run -e 'Agendum.CLI.main(["--demo"])'   # run the TUI with sample data (needs a real terminal)
mix escript.build && ./agendum my.agendum  # build (always for prod: no dev tools inside) and run the binary
mix docs --open           # API docs, design documents, guide and manual (doc/index.html), in the browser
```

A change is done when `mix check` passes. Do not leave warnings. Credo
(`.credo.exs`) and Dialyzer are dev/test-only tools; fix what they report
rather than silencing it, and keep `@spec`s true. An exception needs an
inline `# credo:disable-for-next-line` with the reason.

## Architecture rules (do not break these)

1. **`lib/agendum/core/**` and `lib/agendum/core.ex` are pure.** No I/O, no
   processes, no clock (`Date.utc_today/0` etc.), no randomness. Anything
   external, like today's date, is passed in as an argument
   (`test/agendum/architecture_test.exs` checks for clock and I/O calls).
2. **The TUI is Elm-style.** `Agendum.TUI.Update.handle(state, key)` is pure and
   returns `{state, effects}`; `Agendum.TUI.Render.render(state)` is pure and
   returns styled lines. Only `Terminal`, `App`, `DebugLog`, `Store`, `Preferences`, `CalendarFetch` and `CLI` touch the
   outside world. New side effects become new effect tuples handled in `App`.
3. The TUI calls the core through `Agendum.Core` (the facade) and reads the
   database through `Agendum.Core.Database` queries. It never calls
   `Database` write functions; `test/agendum/architecture_test.exs` fails if
   it does. Add a facade function instead (written in an area module under
   `lib/agendum/core/facade/`, delegated from `Agendum.Core`). Assignment
   rules live only in `Agendum.Core.Assign`; never re-implement them in the UI.
4. Subsumption (membership in ancestors) is **computed, never stored**. Only
   explicit links are stored (`Agendum.Core.Links`).
5. No runtime dependencies in the core and the TUI unless a package meets
   the criteria of `docs/adr/0021-runtime-dependencies.md` (pure Elixir/Erlang,
   no runtime files, keeps the single-file escript); none so far. The
   terminal layer uses OTP 28+ raw mode, not a TUI library (ADR 0002).
6. Keep everything a second front end (e.g. web) would need in `Agendum.Core`;
   the TUI only handles keys and drawing. A multi-user web app on the same
   core is planned (`docs/plans/MULTIUSER.md`, ADR 0020): keep the logic of a
   user action in the core, not in `Agendum.TUI.Update`.

## Workflow for a feature

0. Before any code, list for the owner every key or behaviour the item
   would change for someone already using Agendum (what ENTER or ESC does,
   which key changes a value…), and settle them first. A habit change
   found halfway costs the most: it spreads through the tests.
1. Find or add the behaviour in `docs/SPEC.md` (rules are numbered, e.g. `R7`).
2. Write a failing test first:
   - core rules → `test/agendum/core/*_test.exs` (use `Agendum.Fixtures`)
   - UI behaviour → `test/agendum/tui/*_test.exs`: drive keys with
     `Agendum.TUIHelpers.press/2` and assert on `screen/1` text
   - in a box, reach a setting by its label, not by counting ↓ presses:
     `Agendum.TUIHelpers.to_setting(state, "Also match")`; layouts and keys
     change, labels rarely do
3. Implement it in the core first, then wire it into the TUI.
4. Run `mix check`. After a large TUI change, also run the fuzz property
   longer than the suite's 300 runs (`FUZZ_RUNS=3000 mix test
   test/agendum/tui/fuzz_test.exs`): it finds crashes the short run misses. Update `docs/ROADMAP.md`
   (tick the box and move it under Done), the rule index at the top of
   `docs/SPEC.md` for a new rule (a test checks), `docs/SCREENS.md` if a box or screen was added (a test
   checks), and the help text in `Agendum.TUI.Render.Help` if keys changed.
   - A box or screen with an Agenda screenshot: draw ours as a PNG
     (`tools/screenshots/`) and compare it with Agenda's side by side,
     for spacing and layout the text tests cannot see.
   - Keys, ESC or drawing changed: smoke-test the real terminal (below)
     and say in the summary what was seen. When a change alters habits,
     the owner tries it before the next one is built on it.
5. Do not update the user guide (`docs/guide/index.html`) or the manual
   (`docs/manual/`, generated from `docs/manual/src/`) per feature; the owner
   asks for them from time to time (the `update-guide` and `update-manual`
   skills).

Keep changes small and focused; one feature per commit.

## Conventions

- Names: in text the user sees, our program is **Wol's Agendum** (titles,
  headings, the splash screen) or **Agendum** (menus, help, running text);
  **Agenda** means the original Lotus Agenda ("as Agenda does"). The code is
  `Agendum` too: the Mix app `:agendum`, the `Agendum.*` modules in
  `lib/agendum` (ADR 0019); a file's format tag stays `:agenda`, and files
  saved with the old `Agenda.*` struct names still load. Files are `.agendum`, the
  preferences `~/.config/agendum/`, the JSON format `agendum-json`; the old
  names are still read.
- Match the surrounding style: small pure functions, pattern matching,
  `@spec` on public core functions, `@moduledoc` on every module.
- Core functions that can fail return `{:ok, ...} | {:error, atom}`; the UI
  turns error atoms into messages.
- Ids are positive integers from one shared counter (`db.next_id`).
- Date words and phrases live in language packs (`Core.DateLanguage.*`),
  never in `DateParser`, which only does date arithmetic. Core functions
  that read typed dates take a clock: a `Date`, `NaiveDateTime` or
  `Agendum.Core.Context` (which also carries the date languages); the TUI passes
  `State.context(state)`.
- Dates display in the file's `Agendum.Core.DateFormat` (default ISO 8601): use
  `DateFormat.date/2`, `time/2` or `date_time/3` with `db.date_format`. Dates
  offered for editing stay ISO 8601 (`DateParser.format/1`), which the parser reads back.
- Keys are decoded in `Agendum.TUI.Terminal.Keys`. Function keys are
  required, as in Agenda: there is no ESC + digit stand-in for them (ADR
  0032). Mac keyboards lack INS/HOME/END and terminals never pass ⌘, so a
  command on INS, HOME or END needs a CTRL key, and so does a common
  command (CTRL-N, CTRL-E …); ALT-letters also work as ESC + letter.
  Document keys in `docs/KEYBOARD.md` and the F1 help. CTRL-I/M/H/[ are unusable (they are TAB/ENTER/BACKSPACE/ESC).
- A settings box is drawn from a layout written as it looks on screen,
  with `[field    ]` placeholders (`Agendum.TUI.Boxes.Template`; `CustomizeBox`
  is the example): its fields are also the cursor's order. Look at the
  DOSBox screenshots (`docs/reference/screens/notes.md`) for how Agenda
  laid out the box.
- Menu entries are chosen by first letter, so every level of `Agendum.TUI.Menu.tree/0`
  needs unique first letters (`test/agendum/tui/menu_test.exs` checks this).
  Prefer Agenda's own command names (User's Guide, Appendix A).
- Undo is automatic: any key that changes `state.db` records one step in
  `Agendum.TUI.History`. Do not record history by hand. Keep one user action = one
  database change, so one undo reverses it.

## Testing the real terminal

Unit tests cover everything except the raw terminal. To smoke-test it without
a human, drive the app through a pseudo-terminal (Python `pty`), send keys,
and look at the output. In raw mode the tty must not intercept control keys;
`Terminal` turns off `ixon`, `isig` and `iexten` for that reason.

## Reference material

- **Real Agenda, on demand.** `tools/agformat/agenda_driver.py` runs Lotus
  Agenda 2.0 headlessly in DOSBox Staging (its memory REST API): type keys,
  read the screen as text, find the highlighted row. Use it to check how
  Agenda behaves or lays out a box, rather than asking the owner for
  screenshots. Run it on a copy of the install (`AGENDA_DOS_ROOT`), never on
  `~/Dosbox` itself, and say in the summary what Agenda showed. Ask the owner
  only for what text cannot show (colours, pixels). The `.AG` file format is
  in `docs/AGENDA_FILE_FORMAT.md`.

- `docs/AGENDA_HISTORY.md`: why people used Agenda and what made it unique;
  read it to judge which behaviours matter most to users. Background in
  `docs/reference/`: the designers' 1990 CACM article ("AGENDA- A Personal
  Information Manager (PIM).md") and a modern essay on using it ("Hidden
  Agendas, Lost Cities …").
- `docs/reference/US5115504.pdf`: the Agenda patent (data model).
- Lotus Agenda 2.0 manuals (User's Guide, Quick Start, Setting Up Agenda,
  Starter Applications, Working with Definition Files, Working with Macros)
  from https://archive.org/details/lotus-agenda-users-guide. Their searchable
  plain text is in `docs/reference/*_djvu.txt`; grep it to check original
  behaviour. The PDFs are not in git (download them from archive.org).
- `docs/reference/Agenda 2.0 Help File.html`: Agenda's own F1 help, with
  the original key charts ("Views: Accelerator Keys" etc.) and every settings
  box; check it before choosing a key. `docs/reference/ag2qanda.txt.html`:
  Lotus support Q&A (1990–91) on bugs and edge cases, useful as test cases.
