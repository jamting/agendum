# ADR 0009 — Date language packs, and a context passed to the core

**Status:** accepted · 2026-10-10

## Context

Agenda reads dates from free text ("call Bob next Friday at 3"). The owner,
a Swedish speaker, wanted to type dates in Swedish, without translating the
rest of the program. A first look showed that the English parser contained
not only English words but English grammar: "the 5th of November", "day
after tomorrow", "in 2 days". Swedish builds these differently ("den 5
november", "i övermorgon", "om 2 dagar", "i fredags"), writes 5/11 for 5
November and uses a 24-hour clock. The core must stay pure (ADR 0001), so it
cannot read the chosen language from the environment.

## Decision

- `Core.DateLanguage` is a behaviour. A language pack gives its words (by
  kind: weekdays, months, numbers, relative words …), its phrase patterns,
  each tagged with what it means (`:relative_weekday`, `:in_units`,
  `:past_weekday` …, with capture groups in a fixed order), its day/month
  order and its clock. `English` and `Swedish` are the packs so far.
- `Core.DateParser` holds no language. It matches every pack's patterns and
  does the date arithmetic for each meaning. With several languages the
  earliest, then longest, match wins, and on a tie the main language wins.
- `Core.Context` carries the current time and the languages. Wherever the
  core took a "clock" (a `Date` or `NaiveDateTime`) it also accepts a
  context, and a bare date means English. The TUI passes
  `State.context(state)`.
- Only date input is localized: item text, date columns, the When prompt and
  date filters. Menus, messages and date display are not (ADR 0008).

## Consequences

- A new language is one module plus one line in `DateLanguage.packs/0`. A
  test checks that every pack implements the whole behaviour.
- New date features (recurring dates, R14a) need a meaning in the engine and
  phrases in every pack, so English and Swedish grow together.
- Patterns are compiled per call. That is fine for item-sized text; cache
  them if parsing ever shows up in profiles.
- CLAUDE.md: language words belong in packs, never in `DateParser`.
