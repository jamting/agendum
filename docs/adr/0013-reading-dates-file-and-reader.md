# ADR 0013 — Reading dates: the file's settings and the reader's language

**Status:** accepted · 2026-10-10

## Context

Agenda 2.0's Global Date Settings (User's Guide 7-15 to 7-17) say how a
file reads typed dates: where the week, quarter and year start, what a
month named alone means, the times of "morning", "afternoon" and
"evening", and the number order of calendar dates (11/5 or 5/11). Agenda
saved all of them in the file. This program also has date languages
(ADR 0009), which belong to the reader (ADR 0008), and the Swedish pack
already reads 5/11 as 5 November.

The parser also needed these settings without the core reading anything
itself (ADR 0001), and the language packs needed a way to name times the
file can change.

## Decision

- Settings about the calendar of the information go in the file
  (`Agenda.Core.DateSettings`, `db.date_settings`): beginning and end of week,
  first quarter, beginning of year, month alone, and the times of
  morning, afternoon and evening. Everyone opening the file reads "end of
  the quarter" the same way.
- Number order stays with the reader, set by the date language pack
  (`numeric_order/0`), not by the file. Whether 5/11 is May or November is
  a habit of the person typing, like the words they type.
- (Amended 2026-10-11, R41b.) The person may override their language's
  number order, the date separator and the 12/24-hour clock with their
  own Input format (`Agenda.Core.InputFormat`, in `Agenda.Core.Context`), kept in their
  preferences (ADR 0008), never in the file.
- Every parser call gets both through `Context.parser_opts(clock,
  db.date_settings)`: the languages from the clock (`Agenda.Core.Context`), the
  settings from the file. There is no other way into `DateParser`.
- Language packs name "morning", "afternoon" and "evening" (and their
  translations) by the setting (`:morning` …), not by a time, so one file
  setting serves every language.
- Where the When date is read from (item text, note, item or note text,
  never) was first a file setting in File Properties (`db.when_from`).
  With date categories the user can create (R6a, R6b) it moved, as in
  Agenda, to When's own date rule (`Category.date_rule`), next to "Which
  one"; it is still saved in the file.
- A "$" before a relative date in a range ("$Monday") is read once and
  stored as an ISO date, so a fixed date never depends on who reads it.
- Simplifications against Agenda, recorded in SPEC R14e: quarters and
  years start on the 1st of a month, and End of year is the day before the
  next Beginning of year.

## Consequences

- Changing a setting affects dates read from then on and relative dates in
  filters and conditions (read anew), not dates already given to items.
- A file opened by a Swedish and an English reader gives the same quarter
  and week boundaries, but each types numeric dates in their own order.
- New date settings must be placed in the file or with the reader using the
  rule of ADR 0008, and reach the parser through `parser_opts/2`.
