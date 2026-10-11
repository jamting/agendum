# ADR 0017 — Text matching follows Agenda's word rules

**Status:** accepted · 2026-10-11

## Context

Text matching assigns items to categories whose names appear in their
text (R10), and is what users valued most in Agenda
(`docs/AGENDA_HISTORY.md`). Agenda 2.0 documents exactly how it reads
words (User's Guide 19-7 to 19-17): what a word is ("can't",
"high-capacity"), the suffixes it ignores, words of three letters or
fewer matching exactly, enclosed text it skips, match strength, and
proper names and titles. General tools exist (Porter stemmers, full-text
search), but the project has no runtime dependencies (CLAUDE.md) and they
match differently from Agenda.

## Decision

- `Core.TextMatch` implements Agenda's rules itself, from its own tables:
  the word pattern, the suffix list (-ing, -ed, -ies…, at most two
  stripped, y restored, final e dropped), the encloser pairs and the
  titles (Mr, Mrs, Dr, Herr, Fru, Fröken…). It is pure, and needs no
  dictionary.
- Text is prepared once per item and settings (`TextMatch.prepare/2`):
  words, their stems, and the words in order with whether they are
  capitalized. Category names, short names and text conditions are
  matched against it, yielding `:full`, `:partial` or `:none` for the
  required strength.
- Proper names follow the manual's examples, and where it is silent
  we choose and record it in the SPEC (R16c): a name matches its last
  name alone, after a title or after its own first name, not after
  another capitalized word; a word starting a sentence is not taken as a
  first name; match strength does not apply to the name.
- Rules are tested by the manual's examples (`text_matching_settings_test`,
  `proper_names_test`).

## Consequences

- Matching behaves like Agenda in the documented cases, including its
  quirks ("buy" does not match "buying").
- The suffix and title tables are English, French, German and Swedish as
  in Agenda's manual; other languages would need tables of their own,
  perhaps from the date language packs (ADR 0009).
- Capitalization is a heuristic: "Status Report" becomes a proper name, as
  the manual warns, and an item starting "John Wohl" counts John as a
  sentence start, not as another person.
