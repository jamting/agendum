# ADR 0021 — Runtime dependencies: only when they keep what the rule protects

**Status:** accepted · 2026-10-12 (recording and refining a rule kept since 2026-10-08)

## Context

From the first commit, CLAUDE.md said "No runtime dependencies", but no ADR
gave the reasons. The only recorded one was ADR 0002: the Elixir TUI
libraries needed native code and were unmaintained. Later decisions took the
rule as given (ADR 0017 wrote Agenda's text matching ourselves partly
because of it). As written, the rule also forbids packages that would harm
none of the things it protects, such as a pure-Elixir time-zone database.

What the rule actually protects:

- **The single-file program.** `mix escript.build` bundles a package's
  compiled code, but not its `priv` files or native code. A package with a
  NIF, or one that reads or writes data files at runtime (`tzdata`), breaks
  `./agendum` as one file to copy anywhere.
- **Longevity.** A clone of a 1988 program should keep working for years:
  nothing to upgrade, no abandoned package to replace, a small supply chain.
- **A portable core.** The pure core can sit under any front end (ADR 0020)
  without bringing anything with it.

## Decision

The core and the TUI take a runtime dependency only when the package:

1. is pure Elixir or Erlang, with no native code;
2. needs no files at runtime (data compiled in is fine) and no network of
   its own;
3. is maintained, and small in what it brings with it (its own
   dependencies count);
4. does clearly more than a small module of our own would, and does it the
   way Agenda needs (a stemmer that matches differently from Agenda does
   not qualify, ADR 0017);
5. keeps the core pure: no processes, I/O or clock inside core calls
   (CLAUDE.md, rule 1).

Each such dependency gets a line in this ADR's list below, with why. Dev
and test tools (`runtime: false` or `only: [:dev, :test]`) are not
runtime dependencies and need only to earn their keep (ADR 0012).

The web application (ADR 0020) is a separate Mix project or umbrella app
on top of the core, and may have its own dependencies (Phoenix, LiveView,
a database driver); they never become dependencies of the core or the TUI.

Runtime dependencies taken so far: none.

## Consequences

- CLAUDE.md rule 5 points here instead of forbidding everything.
- Choices become judgements against stated criteria. The first one is time
  zones in calendar subscriptions: reading each calendar's own `VTIMEZONE`
  definitions needs no package at all and is preferred; `tz` would pass
  the criteria if that falls short.
- The escript must still be checked to run on its own after adding any
  dependency (build it and start it outside the project directory).
