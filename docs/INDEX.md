# Index of the documents

What each document is for, and when to read it. `docs/` describes Agendum as
it is; `docs/plans/` what is planned or under way; `docs/adr/` why things
are as they are. Each fact has one home; other documents link to it.
The `tidy-docs` skill brings them up to date and keeps them so.

## Start here

| Document                                     | Read it to know                                                                                   |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| [`../README.md`](../README.md)               | What Agendum is, how to run it, a quick tour                                                      |
| [`../CLAUDE.md`](../CLAUDE.md)               | The rules for changing the code: commands, architecture rules, the workflow, conventions          |
| [`../CONTRIBUTING.md`](../CONTRIBUTING.md)   | Setting up a machine, and a first change, for a person                                            |
| [`ROADMAP.md`](ROADMAP.md)                   | What is open (first) and what is done, with rule numbers                                          |
| [`../CHANGELOG.md`](../CHANGELOG.md)         | What changed in each version (semantic versioning, tagged `vX.Y.Z`)                               |

## What Agendum does

| Document                                     | Read it to know                                                                                   |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| [`SPEC.md`](SPEC.md)                         | Every behaviour, as numbered rules (R1 …); the rule index is at its top                           |
| [`KEYBOARD.md`](KEYBOARD.md)                 | Every key, its Mac-friendly alternative, and ⌘ mappings for each terminal                         |
| [`SCREENS.md`](SCREENS.md)                   | Every screen and box, how each is reached, and what it opens (checked by a test)                  |
| [`THEMES.md`](THEMES.md)                     | The colour values of the themes taken from terminal schemes                                       |
| `docs/guide/index.html`       | The short user guide (Piglet); updated on request (`update-guide` skill)                          |
| `docs/manual/index.html`     | The long manual (Owl and Rabbit), generated from `docs/manual/src/` (`update-manual` skill)           |

## How the code is built

| Document                                     | Read it to know                                                                                   |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| [`ARCHITECTURE.md`](ARCHITECTURE.md)         | The modules, core and TUI, what each does; key design decisions; developer tools; the ADR list    |
| [`DATA_MODEL.md`](DATA_MODEL.md)             | The structs of a file, their invariants, the format versions on disk                              |
| [`DATA_ACCESS.md`](DATA_ACCESS.md)           | How the database is queried and changed: the API by concern, the key algorithms, sequences        |
| [`JSON_FORMAT.md`](JSON_FORMAT.md)           | The JSON export and import schema (a new stored field needs a place here)                         |
| `docs/adr/`                               | Why: one record per lasting decision, listed in `ARCHITECTURE.md`                                 |

## Lotus Agenda, the original

| Document                                                       | Read it to know                                                                   |
| -------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| [`AGENDA_HISTORY.md`](AGENDA_HISTORY.md)                       | Why people used Agenda, what made it unique, which behaviours matter most          |
| [`AGENDA_FILE_FORMAT.md`](AGENDA_FILE_FORMAT.md)               | Agenda's `.AG` file format, reverse engineered (stored vs computed, exact numbers)  |
| `docs/reference/README.md`                   | The manuals as text, the F1 help, the support Q&A, the patent, essays: grep them   |
| `docs/reference/AGENDA_MENUS.md`       | Agenda 2.0's menus as they are (view, note editor, category manager)               |
| `tools/agformat/DRIVING_AGENDA.md` | Running the real Agenda headless to check a behaviour (`agenda_driver.py`) |

## Plans

Each plan starts with its status.

| Plan                                                                   | About                                                                          |
| ---------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| [`plans/AGENDA_PARITY.md`](plans/AGENDA_PARITY.md)                     | How close Agendum is to Agenda; accepted enhancements and modifications; steps |
| [`plans/NOTE_EDITOR.md`](plans/NOTE_EDITOR.md)                         | The note editor as Agenda's: evidence, habit changes to settle, steps          |
| [`plans/RECURRING_OCCURRENCES.md`](plans/RECURRING_OCCURRENCES.md)     | Recurring items on every date they recur, in datebooks and date filters        |
| [`plans/KITTY.md`](plans/KITTY.md)                                     | The ALT and CTRL key bars while the key is held (kitty keyboard protocol)      |
| [`plans/AGENDA_FILE_FORMAT_LOG.md`](plans/AGENDA_FILE_FORMAT_LOG.md)   | The research log behind the `.AG` format; next: the importer                   |
| [`plans/MULTIUSER.md`](plans/MULTIUSER.md)                             | A web application with accounts and shared files, on the same core (ADR 0020)  |
| [`plans/GITHUB.md`](plans/GITHUB.md)                                   | Putting the repository on GitHub; public or paid later                         |
| [`plans/RENAME_REPO.md`](plans/RENAME_REPO.md)                         | Renaming the repository folder, with Claude Code's memory                      |
| [`plans/WOL-IN-THE-MACHINE.md`](plans/WOL-IN-THE-MACHINE.md)           | An idea: a personal agent inside the file                                      |
| [`plans/REFACTORING.md`](plans/REFACTORING.md)                         | Where organic growth left complexity (mostly done)                             |
| [`plans/DOSBOX_STAGING.md`](plans/DOSBOX_STAGING.md)                   | Running the real Agenda for Claude (done differently; a record)                |

## Reviews

| Document                       | About                                                                                       |
| ------------------------------ | ------------------------------------------------------------------------------------------- |
| `docs/reviews/` (one per date) | Dated expert panel reviews (architecture, code, users, business, vision, methods), each following up the last (`expert-review` skill) |

## Where a change is written down

| When you…                              | Update                                                                                         |
| -------------------------------------- | ---------------------------------------------------------------------------------------------- |
| add or change a behaviour              | its rule in `SPEC.md` (and the rule index); the item in `ROADMAP.md`, ticked and moved to Done |
| add or change a key                    | `KEYBOARD.md`; the key's keymap and command (the F1 help is made from them)                     |
| add a screen or box                    | `SCREENS.md` (a test checks); `ARCHITECTURE.md` if it is a new module                          |
| add a stored field                     | `DATA_MODEL.md` (and a row in its format versions), `DATA_ACCESS.md` if queried, `JSON_FORMAT.md` and `Agendum.Core.JSONFile` |
| make a lasting decision                | a new ADR in `adr/`, and a row in `ARCHITECTURE.md`'s ADR list                                 |
| finish a major feature or change the file format | the version in `mix.exs` (minor, never 1.0.0 unless the owner says), an entry in `CHANGELOG.md`, a `vX.Y.Z` tag |
| find a way to work faster or safer     | an item under "Sharpen the saw" in `ROADMAP.md`                                                 |
| plan something larger                  | a plan in `plans/`, starting with its status, and a row above                                  |
