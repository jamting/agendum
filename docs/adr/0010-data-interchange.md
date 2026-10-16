# ADR 0010 — Data interchange: JSON, and Agenda's structured files

**Status:** JSON accepted and built 2026-10-11 (R44); STF proposed (Milestone 4) · the format is now named `agendum-json` (ADR 0019) · JSON's role (for people, not the working format) restated in ADR 0034

## Context

Files are saved as Erlang terms (ADR 0003): complete and fast, but not readable and only usable by this program. People want backups they can read and data they can move to other tools. People who used Agenda in the 1990s may still have `.AG` files, whose format is undocumented. Agenda 2.0 itself imported and exported *structured files* (`.STF`), a tagged text format that is fully documented (Working with Definition Files, Appendix B; User's Guide chapters 23–24).

## Decision

- **JSON** is the modern interchange format. Export and import cover everything in a file (items, categories with their properties, links, views, settings), so that a file survives a round trip unchanged.
- **STF** import and export is for legacy users: DOS Agenda can export any `.AG` file to STF, and we read it. Both Agenda 2.0 dates (`{C}\When@|10%/31%/1990`) and 1.x dates (`{W}10/31/90`) map to the same When, Entry and Done categories, avoiding a known Agenda 2.0 duplication bug. STF export lets data go back to DOS Agenda.
- Reading `.AG` files directly stays optional research. STF covers most needs.
- The native Erlang-term format stays the working format.

## JSON as built (2026-10-11)

- `Agendum.Core.JSONFile` is pure and in the core, so a web front end can use it; the facade offers `Core.export_json/1` and `Core.import_json/1`. The shell reads and writes the file (App effects).
- A hand-written schema, not a generic term encoding: readable keys, enums as words, ISO 8601 dates, items carrying their own assignments, dates, numbers and dependencies, and a fixed key order (our own small pretty printer; OTP's sorts keys), so exports diff well. Envelope `{"format": "agenda-json", "version": 1}`, versioned apart from the `.agenda` format. Described in `docs/JSON_FORMAT.md`.
- Reading is strict where it cannot trust (unknown values, wrong types, missing references, with the place named) and lenient where it can (a missing key takes its default; unknown keys are ignored).
- Import opens the JSON as a new, untitled file, like Retrieve; merging into the open file belongs to the STF and iCal imports.
- A property test runs random key sequences on the sample and requires `decode(encode(db)) == {:ok, db}`; a new field in the data model needs a line in the schema, or that test (and `json_file_test`'s rich file) fails.

## Consequences

- Two formats to maintain. JSON follows the data model directly; STF follows Agenda's documented subset (views and conditions, for example, are not in STF).
- JSON needs a stable, documented schema (versioned like ADR 0003's envelope), described next to `DATA_MODEL.md`.
