# ADR 0044 — One repository and one program; the extras on a shelf of their own

**Status:** accepted · 2026-10-21 (meeting 2026-10-21-2324, § 9) · amended 2026-10-22 (meeting 2026-10-22-2130, § 5d: the allowed callers, and the round-trip test first) · amended 2026-10-31 (the split waits for a reason)

## Context

With a truthful clone first (meeting 2026-10-21-2324, § 5) and the extras hidden behind one switch (ADR 0043), the owner asked how the clone and the rest are split: a git branch, a new project, or separate "things" sharing the core (the core and the terminal program as the clone; a "next-level TUI" and the web version importing the core). Agendum is one Mix application, one repository, one single-file escript (ADR 0021); the core is already a layer of its own, used through the facade and guarded by `test/agendum/architecture_test.exs`. The extras' pure modules (the blog, the site, Markdown, feeds, Zettel ids, about 3,500 of 45,500 lines) sit among Agenda's own in `lib/agendum/core/`.

## Decision

- **One repository, one program, no branch for the clone.** A long-lived branch would need every fix twice and drift within weeks; the switch of ADR 0043 makes the clone and the extras one program.
- **The extras get a namespace of their own** (`Agendum.Core.Extras.*` for the core's modules, and a matching home on the TUI side), so the line between the clone and the extras can be seen.
- **The line is checked:** the architecture test (`:xref`, as for `Database` writes) fails if faithful code calls an extras module directly; it reaches them only through commands tagged as extras.
- **The core becomes a Mix project of its own when the web version starts** (an umbrella or path dependencies: a core library used by the terminal program and by the web application), not before: a split is made when there is a second user of the core. The file format stays one, extras' fields included.

## Consequences

- Moving the extras' modules is a refactoring with no change in behaviour, done before the Extras switch so the switch has one place to look.
- The owner's "next-level TUI", a second terminal program with modern keys, would change ADR 0038 (modern keys belong to the web); it was tabled to the next meeting.
- A public repository (meeting 2026-10-21-2324, § 10, `docs/plans/GITHUB.md` § 7) is made from this one later, by rewriting a copy; this repository stays the private workshop.

## Amendment: who may name the extras, and the test first (2026-10-22)

The extras are not only modules: their data are stored fields of the file (`next_zettel`, `feeds`, `blog`), so some faithful modules must name them. Only these may, and the `:xref` rule lists them as its exceptions from its first day, strict everywhere else (meeting 2026-10-22-2130, § 5d; expert review 2026-10-21, § 8):

- the file and its format: `Agendum.Core.Database`, `Agendum.Core.JSONFile`, `Agendum.Store` and its golden files, and `Agendum.Core.Invariants`;
- the facade's extras area (an area module under `lib/agendum/core/facade/`, delegated from `Agendum.Core`), which the TUI's extras commands call.

The order of work: first the exceptions written into the architecture test, and a round-trip test (a file with the extras' fields, saved with Extras off, keeps them unchanged) written against today's code, where both pass; then the move; then the switch (ADR 0043). The tests guard the move instead of describing it afterwards.

## Amendment: calendars on the shelf, two named exceptions, renamed structs (2026-10-23)

Settled with the owner before the tests were written (2026-10-23):

- **Calendar subscriptions are on the shelf** (`Calendar`, `CalendarSync`, `ICal` and `CalendarFetch`): AGENDA_PARITY.md tags them an extra (R45), so they move with the blog, the site, Markdown, the feeds and the Zettel ids.
- **Two named exceptions**, listed by function in the architecture test with their reasons, and no others: `Assign` blanks out a Zettel link (`[[abcdefgh]]`) before an item's text is matched to categories, so a link never assigns an item (`Assign.levels/2`, `Assign.text_matches?/3`); `ViewModel` draws the Zettel id column, a column format stored in a faithful view (`ViewModel.standard_cell/6`). `Agendum.Starters.Golden`, which sets every stored field, is one of the file's modules.
- **The stored structs move too** (`Feed`, `Blog`, `Calendar`). Loading maps their old names to the new ones, as ADR 0019 did for `Agenda.*`, so every file ever saved still opens; a new format version makes older programs refuse a file saved since, rather than misread it.
- Until the Extras preference tags the commands, the test guards the core's shelf: the extras' boxes and shell modules may use it, and faithful TUI code may still open them. The commands tagged as extras close that side.

## Amendment: the split waits for a reason (2026-10-31)

The owner, 2026-10-31: other code built on the core depends on the whole `:agendum` application, pinned to a git tag. That works today: the application starts nothing when loaded (no `mod:` in `mix.exs`) and has no runtime dependencies (ADR 0021). The core becomes a Mix project of its own when the web version starts, or when depending on the whole application actually hurts (compile times, a server that must not carry the terminal code), not merely because a second user exists. What such code may call is listed in `docs/ARCHITECTURE.md`, What a front end may use.
