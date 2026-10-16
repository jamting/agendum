# ADR 0039 — Zettel ids are Quadsyl-24, a frozen part of the file format

**Status:** accepted · 2026-10-16 (meeting 2026-10-16-3, § 5 and § 6)

## Context

Zettels (level 1 in `docs/plans/ITEM_LEVELS.md`) need ids that last as long as the person's notes and that a link can name. The roadmap planned the creation time, `YYMMDDHHMM` plus a digit (`26101311140`). The owner designed Quadsyl-24 instead (its description and module are in the owner's `import-into-project/`, to come in as `docs/QUADSYL.md` and `Agendum.Core.ZettelId`, ROADMAP "Beyond Agenda"): a number from 0 to 16,777,215 is scrambled by a reversible mixing function and spelled as four consonant-vowel syllables, eight letters (`bonalaku`), chosen for Swedish and English speakers. The 267 ids that are real words are reserved for special notes. Eleven digits are hard to hold in mind or say aloud; four syllables are four chunks. The creation time is not lost: the Entry date keeps it.

## Decision

- **A Zettel id is a Quadsyl-24 id**, made by `Agendum.Core.ZettelId` (pure, in the core).
- **The configuration is part of the file format and never changes**: the syllable table, the excluded syllable, the multipliers and their inverses, the shift and the number of rounds. Changing any of them would change every id in every file. A known-values test pins them; an exhaustive test (tagged `:exhaustive`, outside `mix test`) checks that all 2^24 numbers round-trip.
- **The reserved list may only grow above a file's counter**, and a word in use is never removed (QUADSYL.md, "Rules and future extension"). More room, if ever needed, comes from a longer tier, not from changing this one.
- **The id is a stored field on the item**, not a category: an id says which item it is, a category what it is about. Each file has its own counter, `next_zettel`, from 1, apart from `db.next_id`. Ids are given by a command ("Attach Zettel id"), not to every item, and never changed once given.
- **The JSON stores the id as its word**, and `docs/JSON_FORMAT.md` describes the scheme, so the ids can be read without Agendum.

## Consequences

- A new stored field and counter: a format version, the JSON schema, a golden file, `DATA_MODEL.md`.
- No checksum: a typo is another well-formed id. With a few thousand zettels among 16 million ids, it almost always names no zettel, and the link shows as broken.
- Two files counting from 1 give out the same ids. Exchanging zettels between instances, and giving out the reserved words, wait for an answer in `docs/plans/ITEM_LEVELS.md` (open questions).
- An enhancement over Agenda, listed in `docs/plans/AGENDA_PARITY.md`.
