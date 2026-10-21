# ADR 0006 — Faithful to Agenda 2.0, with marked extensions

**Status:** accepted · 2026-10-10 · amended by ADR 0043 (a truthful clone: the test for what may differ, extras hidden behind one switch)

## Context

The project clones Lotus Agenda 2.0 (1990). Its value to users was a particular way of working (see `docs/AGENDA_HISTORY.md`), so behaviour should match the original wherever the original is known. At the same time the program runs in modern terminals, on Mac keyboards, for people who expect things like undo, Unicode and readable export, and the owner wants some modernization so that it is appreciated today.

## Decision

- The reference for behaviour is the Agenda 2.0 documentation in `docs/reference/`: the User's Guide and the other manuals, the in-program Help file (key charts and settings boxes), and Lotus's support Q&A for edge cases and known bugs. Every rule in `docs/SPEC.md` cites its source.
- Where we differ from the original on purpose, the SPEC rule says so under "Our choices", with the reason (for example: ISO dates as the default display, a search that continues from the top).
- Where we add something the original did not have, the rule is marked "not in Agenda" and listed under "Beyond Agenda" in the roadmap (for example: undo, colour themes on the command line, date languages R14c, JSON export).
- Known bugs of the original (from the support Q&A) are not copied; they become test cases for the correct behaviour.
- Agenda's own keys and command names win over our inventions (ADR 0007).

## Consequences

- Reviewers can check any behaviour against a cited page.
- Extensions are visible as such and can be kept, changed or dropped without touching the faithful core of the program.
- Some modern conveniences arrive next to the original instead of replacing it (JSON next to STF, ADR 0010).
