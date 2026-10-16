# ADR 0029 — Stored date phrases are read in English too

**Status:** accepted · 2026-10-13

## Context

Some date phrases are kept in a file as text and read again each time they are used, so that they stay relative:

- a date filter's ends (R28a): "yesterday", "beginning of this week";
- a datebook view's base date (R47): "beginning of next week";
- a date category's action date (R15b).

They are read with the date languages of the person who opens the file (R14c). The file does not record which language a phrase was written in. A file made in English, such as the Planner starter file (ADR 0028), therefore broke for someone who reads only Swedish: the Overdue filter did not read "yesterday", and Next Week fell back to this week, because a base date that cannot be read means today. Files shared between people with different languages, which the planned web front end will have (ADR 0020), would break the same way.

## Decision

A phrase kept in the file is read in the reader's languages first, then in English (`Agendum.Core.Context.stored_parser_opts/2`). The datebook base date, the range filter (when set and when read) and the date action (when set and when run) use it.

What a person types (item text, date columns, prompts) is still read in their own languages only, so English never overrides their phrases there.

## Consequences

- Files made in English, the starter files among them, work in every language. A person's own phrases still work, since their languages come first.
- A phrase in another language than the reader's and not English still fails, as before. Recording the language with each phrase would fix that, but it is a format change with no need yet.
- New features that keep a date phrase in the file should read it with `stored_parser_opts/2`, not `parser_opts/2`.
