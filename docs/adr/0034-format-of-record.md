# ADR 0034 — The format of record: Erlang terms now, a database for many users, JSON for people

**Status:** accepted · 2026-10-16

## Context

Agendum has two complete file formats. The `.agendum` file is the `%Database{}` value written as an Erlang term (ADR 0003): 33 format versions in its first eight days, each with an upgrade step, and tied to module and field names. The `agendum-json` export (ADR 0010, `docs/JSON_FORMAT.md`) is readable, round-trip tested, and still at version 1, because a missing key takes its default. The expert review of 2026-10-16 (`docs/reviews/2026-10-16.md`) asked which of them keeps people's data for years, before the web plan (ADR 0020) adds a third way of storing it.

Measured on 2026-10-16:

| File                     | Erlang term                     | JSON                                     |
| ------------------------ | ------------------------------- | ---------------------------------------- |
| The golden file, 53 items | 8 KB; save and load under 1 ms | 123 KB (7 KB gzipped); save 9 ms, load 6 ms |
| 3,053 items              | 53 KB; save 8 ms, load 4 ms     | 1.5 MB (28 KB gzipped); save 17 ms, load 27 ms |

The owner decided (2026-10-16), with the reasons below. Agendum is also heading for much larger files than a person types by hand: ingested items (calendars, RSS feeds …) and context items a language model makes, on three levels (`docs/plans/ITEM_LEVELS.md`). The number of items can be substantial, and that is the deciding reason.

## Decision

- **The Erlang-term file stays the format of record** for the single-user program, for its speed and compactness at large volumes. ADR 0003 stands.
- **Backward compatibility is not a promise yet.** The owner is the only user, so a change may leave old files behind when upgrading them would cost more than it is worth. `Store.upgrade/1` and the golden files (`test/fixtures/formats/`) stay: they show what a change breaks, and the promise can be made the day other people keep data in Agendum.
- **Many users get a database**, most likely PostgreSQL, rather than files or snapshots with a command log, as first sketched. That is decided with the web plan; the pure core does not change for it (rule 1: storage is the shell's business).
- **JSON is for people:** exchange between humans and programs, and looking at a file. It is Agendum's counterpart of Agenda's structured files (STF, User's Guide chapters 23–24, Working with Definition Files Appendix B): a tagged text file of items, categories, notes, dates, numbers, conditions and actions, written by File ▸ Transfer ▸ Export. Agenda's export chooses what goes in (which items: none, the current one, the marked ones, a section's, the view's or all; explicit or also conditional assignments; categories without items or not). Agendum's export will likewise ask which item levels to include (`docs/plans/ITEM_LEVELS.md`). It is not the working format.

## Consequences

- Nothing changes in the code now. Each new stored field still bumps the format version (with a golden file, `mix agendum.golden`) and a line in the JSON schema.
- The JSON round trip stays exact for everything included in an export; an export of chosen levels is a partial file by design, and importing one must say so.
- Performance work (the Sharpen the saw items on reading dates and caching views) gets more weight: volumes, not typing, will set the limits.
- The storage plan for many users is to be rewritten around a database when the web work starts.
