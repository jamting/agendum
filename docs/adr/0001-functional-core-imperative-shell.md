# ADR 0001 — Functional core, imperative shell

**Status:** accepted · 2026-10-08

## Context

Agenda's value is in its rules: subsumption, exclusion, automatic
assignment and editing through views. These rules must be easy to test
and easy for AI assistants to change safely.

## Decision

All domain logic lives in pure modules under `lib/agenda/core`, operating on
one immutable `Database` value. The UI is Elm-style: a pure
`Update.handle(state, key) → {state, effects}` and a pure
`Render.render(state) → lines`. Only `Terminal`, `App`, `Store`,
`Preferences` (added 2026-10-11, ADR 0008), `CalendarFetch` (R45) and `CLI`
perform I/O. The clock is read in the shell and passed in.

## Consequences

- Almost everything is testable with plain function calls, including
  whole UI interactions as key sequences asserted against screen text.
- Undo is trivial to add later (keep old values). Done this way: ADR 0005.
- The whole database is rebuilt on each change. That is fine for personal
  data sizes (thousands of items). Revisit with indexes if needed.
