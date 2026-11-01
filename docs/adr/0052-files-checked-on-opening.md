# ADR 0052: A file is checked when it is opened

**Status:** accepted (the owner, 2026-11-01)

## Context

An `.agendum` file is Erlang terms, read with safe decoding (no new atoms), and until now checked only for its outer shape: a `Database` of a known format version. Everything inside was trusted. A file from someone else, or one damaged on disk, could hold a value of the wrong kind (a number for an item's text) or parts that do not agree (an item assigned to a category that does not exist), and Agendum would open it and crash later, on a row or a view (the threat model, `docs/SECURITY.md`, door 2). Agendum never writes such a file itself: the fuzz walks check the invariants after every key.

Agenda refused a damaged file: "If an Agenda file becomes damaged, you cannot use it" (User's Guide, Appendix I), and recovering it was a separate program (DB2STF).

## Decision

- **Every file opened is checked** (`Agendum.Core.FileCheck`, called by `Agendum.Store` after reading and upgrading it): Retrieve, the file named at startup, a crash's recovery file.
- **Types through the JSON format's strict reading:** the file is written as JSON and read back (`Agendum.Core.JSONFile`). Its checks already know every stored field, and every stored field must be in the JSON format (the round-trip tests), so a new field is checked with no line of its own. A raise while writing it (a value of the wrong kind) counts as damage.
- **Consistency through `Agendum.Core.Invariants`**, the check the fuzz walks run.
- **A damaged file is refused**, as Agenda refused one: "owl.agendum is damaged and cannot be opened: …" with the first problem; the file open stays, the damaged one is left untouched and no backup is made of it (R82d).

## Consequences

- Opening costs the JSON round trip: about 140 ms for a file of 2,000 items with many notes, 0.4 s for 5,000 short items (2026-11-01). If ingested items (`plans/ITEM_LEVELS.md`) make this slow, a type walk of its own is the alternative (fast, but each new field needs a line there).
- A damaged file of the person's own cannot be opened in Agendum; getting its contents out is a tool for later (as Agenda's DB2STF), not built.
- A new invariant must hold for every file already written, or those files stop opening: add an upgrade step for old files with the invariant.
