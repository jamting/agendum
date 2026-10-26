# ADR 0003 — File format

**Status:** accepted · 2026-10-08 · confirmed as the format of record by ADR 0034

## Decision

A file is `:erlang.term_to_binary({:agenda, version, %Database{}}, [:compressed])`, written atomically (temp file + rename) and read with `[:safe]`. The loader makes sure the app's modules are loaded first, because `:safe` refuses atoms (struct field names) that don't exist yet.

## Consequences

- Zero code needed to serialize new fields, but struct changes need a migration when `version` is bumped. `Store.upgrade/1` rebuilds every struct on load so added fields get their defaults (first used for version 2, R14); reshaped fields need an explicit step there.
- Not human-readable. A JSON/text export is on the roadmap for interchange and backups.

**Amended 2026-10-26 (meeting 2026-10-26-4, § 5):** compressed at zlib's fastest level, `compressed: 1`, instead of the default: on the owner's file the default level took 117 of a save's 123 ms, level 1 about 42 ms, for a file 15% larger. Reading does not depend on the level, so files saved either way open in every version.
