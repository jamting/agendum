# ADR 0035 — Caches travel in values the shell keeps

**Status:** accepted · 2026-10-16

## Context

Reading a date compiled every rule of the date languages each time (`Agendum.Core.DateParser`): about 40 regexes for English, twice that with a second language. Measured on 2026-10-16, compiling was about 80% of a reading (0.48 ms of 0.6 ms for English). The pure core may not keep anything between calls: no processes, no `:persistent_term`, nothing global (CLAUDE.md, rule 1). Since OTP 28 a compiled regex cannot be kept in a module attribute either, so compiling them when the code compiles is out.

## Decision

A cache the core needs is a **value**, made by a pure core function and **kept by the shell**, which passes it back in.

- The date rules: `DateParser.compile_rules/2` compiles them; `Agendum.Core.Context.prepare/1` puts them in the context, keyed by the languages and input format they were made for; `Context.parser_opts/2` hands them to the parser only when the key matches, so a stale cache is never used, only missed (and the rules compiled as before).
- The TUI keeps them in `State.reader` (a context without the time) and prepares it again when the person's languages or input format change (`State.put_reader/2`, `State.change_preference/3`).
- Callers with no prepared context (a date as the clock, most tests, building the starter files) work as before.

## Consequences

- Adding 100 items with dates in their text: 92 → 13 ms in English, 247 → 24 ms with Swedish and English (2026-10-16). Readings are the same with and without the cache (`test/agendum/core/context_test.exs`).
- The same pattern is ready for the view cache (ROADMAP, Sharpen the saw): a value the core computes and the shell keeps, with a key that says when it is stale.
- The TUI's state gained no field: languages, input format and rules are one `reader` field, which also kept `State` under 32 fields (Credo; a BEAM map with more keys changes representation).
