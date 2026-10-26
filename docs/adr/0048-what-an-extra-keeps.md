# ADR 0048 — What an extra keeps for itself

**Status:** accepted · 2026-10-26 (meeting 2026-10-26-5, §§ 5–6)

## Context

The extras (ADR 0043, 0044) need data of their own, beside the person's items: a feed remembers each entry it filed and its item, a calendar each event, the blog its settings. Each grew its own habits. The feeds kept a full copy of every live entry's title and note, to tell the person's edits from the feed's: in the owner's file on 2026-10-26 the feeds' data was 3.6 MB as a term, against 2.0 MB for all the items, after the faded entries had already been trimmed (format 45). Each feed was also an ordinary category, 243 of the owner's 268, crowding the category manager. The owner asked whether there is a general pattern and whether an overarching strategy is needed.

## Decision

- **One typed struct per extra, in the file** (`db.feeds`, `db.calendars`, `db.blog`, and the next extra's likewise): not a generic store of extras' data. Dialyzer, the JSON schema (`Agendum.Core.JSONFile`, `docs/JSON_FORMAT.md`) and the golden files depend on knowing the shape; every stored field has its place in all three.
- **An extra keeps only what it needs**: ids, dates, settings, and **fingerprints** where it must tell later whether something changed. Never a copy of what an item already holds. The first use: feed and calendar snapshots keep a fingerprint of the title and note they filed, not the text (ROADMAP, Beyond Agenda).
- **What the person should see or search lives on items**: text, notes, categories, columns. What only the machine needs (when a feed was read, what it filed, why it failed) lives in the extra's struct and is shown, where useful, in the extra's own box (the Feeds and Calendars boxes).
- **Categories an extra makes are marked as its own**: an **ingested category** has a `source` (`{:feed, id}`, later `{:calendar, id}`; nil for the person's). It is named and filled by the extra, not edited or assigned to by hand, and hidden in the category manager unless asked for; it still heads sections, filters views and is read by conditions. The details are in `plans/RSS_READER.md`, to settle before it is built.
- **A separate store for ingested items** (large volumes beside the person's file) stays a question for `plans/ITEM_LEVELS.md`, taken up when volumes ask for it.

## Consequences

- A new extra starts from this rule, not from the last extra's habits; a review can check an extra's struct against it.
- An agent (`plans/WOL-IN-THE-MACHINE.md`) can tell the person's data from an extra's bookkeeping by where it is and by a category's source, and leave the bookkeeping alone.
- Fingerprints and ingested categories are format changes: a version, a golden file, the JSON schema, and an upgrade of older files in `Store.upgrade/1`.

**Amended 2026-10-26 (when built, R75a):** an ingested category is not marked with a stored `source` field: which categories are ingested is worked out from the subscriptions (`Agendum.Core.Extras.Ingested`), as subsumption is computed (CLAUDE.md rule 4). It needs no format change, cannot go out of step, and unsubscribing hands a category back by itself, as the owner chose. A person's command that would change one is refused in `Agendum.Core.Command` (`{:error, :ingested}`); the feed and the calendar file into them below the commands.
