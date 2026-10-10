# ADR 0010 — Data interchange: JSON, and Agenda's structured files

**Status:** proposed · 2026-10-10 (Milestone 4)

## Context

Files are saved as Erlang terms (ADR 0003): complete and fast, but not
readable and only usable by this program. People want backups they can read
and data they can move to other tools. People who used Agenda in the 1990s
may still have `.AG` files, whose format is undocumented. Agenda 2.0 itself
imported and exported *structured files* (`.STF`), a tagged text format that
is fully documented (Working with Definition Files, Appendix B; User's Guide
chapters 23–24).

## Decision

- **JSON** is the modern interchange format. Export and import cover
  everything in a file (items, categories with their properties, links,
  views, settings), so that a file survives a round trip unchanged.
- **STF** import and export is for legacy users: DOS Agenda can export any
  `.AG` file to STF, and we read it. Both Agenda 2.0 dates
  (`{C}\When@|10%/31%/1990`) and 1.x dates (`{W}10/31/90`) map to the same
  When, Entry and Done categories, avoiding a known Agenda 2.0 duplication
  bug. STF export lets data go back to DOS Agenda.
- Reading `.AG` files directly stays optional research. STF covers most
  needs.
- The native Erlang-term format stays the working format.

## Consequences

- Two formats to maintain. JSON follows the data model directly; STF
  follows Agenda's documented subset (views and conditions, for example,
  are not in STF).
- JSON needs a stable, documented schema (versioned like ADR 0003's
  envelope), described next to `DATA_MODEL.md`.
