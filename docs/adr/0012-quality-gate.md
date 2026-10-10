# ADR 0012 — The quality gate: formatter, compiler, Credo, Dialyzer, tests

**Status:** accepted · 2026-10-10

## Context

Most of this code is written with AI assistance. Rules that live only in
prose (CLAUDE.md) are easy to forget in a long session; rules that fail a
build are not. Two kinds of drift had already happened: `@spec`s that no
longer matched how functions were called, and a near miss in which the pure
core almost read the system clock. A third-party "coding standards" prompt
skill was considered and rejected: it repeated what the project already had,
gave advice that is wrong for Elixir or conflicts with the formatter, and
would cost context in every session.

## Decision

- `mix check` is the single gate, in this order: `mix format
  --check-formatted`, `compile --warnings-as-errors`, `credo`, `dialyzer`,
  `test --warnings-as-errors`. A change is done when it passes.
- Credo and Dialyzer are dev/test-only dependencies (`runtime: false`); the
  program keeps no runtime dependencies (ADR 0002).
- Credo uses its defaults except: cyclomatic complexity up to 20 and nesting
  up to 3, because key dispatchers and lookup tables have one branch per key
  (`.credo.exs`). Strict mode (alias suggestions) is off.
- What the tools report is fixed, not silenced. An exception needs an inline
  `# credo:disable-for-next-line` with the reason beside it.
- `test/agenda/architecture_test.exs` enforces the architecture rules that a
  linter cannot: the TUI changes the database only through `Agenda.Core`, and
  the core never calls the clock, I/O, the environment, randomness or
  processes.

## Consequences

- `@spec`s are now checked and must stay true.
- The first Dialyzer run on a machine builds its PLT (about a minute); after
  that the whole gate takes about ten seconds.
- Either tool can be removed by deleting two lines in `mix.exs` if it costs
  more than it helps; this ADR would then be superseded.
