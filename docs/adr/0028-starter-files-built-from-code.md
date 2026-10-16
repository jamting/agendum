# ADR 0028 — Starter files are built from code

**Status:** accepted · 2026-10-13

## Context

Agenda shipped starter applications, such as the Activities Planner (`apps\planner`): ready-made files with categories, views and macros that a person copied and filled in. Agendum ships the Planner the same way (R60), as `starters/planner.agendum`.

An `.agendum` file is a binary term (ADR 0003). A binary file in git cannot be reviewed, and it goes stale whenever the store format changes or the Planner is improved. Building the file by hand in the TUI could not be repeated.

## Decision

- **The code is the source.** `Agendum.Starters.Planner.build/0` builds the file through the `Agendum.Core` facade, as a person would: its categories, views (`Planner.Views`) and macros (`Planner.Macros`). It never writes to the database directly, so the file always obeys the core's rules and is in the current format.
- **`mix agendum.starters` writes the file**, and the file is committed (`.gitignore` has an exception for `starters/*.agendum`), so a person who has only the repository or the release can copy it.
- **A test keeps them equal.** It loads the committed file and compares it *as data* with what `build/0` returns. Bytes are not compared: `term_to_binary/2` may encode maps differently between OTP versions. When the Planner code or the store format changes, the test fails until the file is written again and committed.
- **Sample data stays out of the shipped file.** `--samples` writes a copy with realistic items (`Planner.Samples`) to `tmp/` for testing. Its dates are counted from `--today` (by default today), so the same day always gives the same file and the datebooks are never empty.
- **What the code cannot do is left out, not faked.** Macros that need Agenda's macro command language are left out. The view one of them made (Contacts) is built directly, and the roadmap says so.

## Consequences

- A store format change (a new stored field) has one more step: `mix agendum.starters`, then commit `starters/planner.agendum`. The failing test says so.
- More starter files (Agenda had several) follow the same pattern: a module under `Agendum.Starters`, written by the same mix task, with the same test.
- Building through the facade tests the facade too: the Planner exercises columns per section, note columns, filters, datebooks and macros together, and found two bugs on its first day.
