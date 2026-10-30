# Minutes of the panel meeting, 2026-10-26-1732

**Place:** Owl's house, the Hundred Acre Wood
**Present:** the owner (chair); José Who Brews, Great-Uncle Joe, Carsten Stargazer, Old Mitch Lilypad, Little Marie-Who-Folds, Claude (Owl's cousin); Owl, host
**Secretary:** Claude · **Approvers:** Old Mitch Lilypad and Little Marie-Who-Folds
**Agenda:** [dagordning.md](dagordning.md) · **At commit:** `951d17c`

*The fifth meeting of the day. Owl had stopped pretending not to count and chalked the number on the door. Mitch, by now an expert, took the stairs before anyone asked; Little Marie-Who-Folds arrived with a printout of the category list, long enough that she had folded it into a neat accordion. The panel's voices are lenses in the spirit of the people named, written by Claude, not their words. The minutes were made with the `meeting` skill.*

## § 1 Opening of the meeting

Owl opened the meeting, observing that it concerned the things Agendum keeps for itself.

## § 2 Election of a chair, a secretary and two approvers

The owner chairs; Claude keeps the minutes; Old Mitch Lilypad and Little Marie-Who-Folds approve them.

## § 3 Adoption of the agenda

One thought was waiting under Next meeting, "The extras' data meeting", with its sub-points; the roadmap carried the owner's earlier question on feed names as an unindexed column. Claude worded them as two items and measured the owner's file before the meeting: 243 feeds, each a category (243 of 268 categories); the feeds' data 3.6 MB as a term against 2.0 MB for all items, most of it the 1,248 live entries' copies of their title and note. The agenda was adopted as proposed.

## § 4 The previous minutes

| Decision (2026-10-26-4) | Status | Evidence |
| --- | --- | --- |
| § 5 Faded feed entries trimmed; compression only if still slow | Done | `93598a9`, `524a3b6` (v0.64.0) |
| § 6 Logger, recovery file, hostile-text tests | Done | `fdbc3ad`, `3e05033`, `951d17c` (v0.64.1–v0.65.1) |
| § 7 Debug log by host, ten sessions | Done | `835bb41` |
| § 8 Fuzz output kept | Done | `caae55f` |
| § 9 Tidy pass and dry run | Not yet | ROADMAP, In order 4–5 |
| § 10 The "tried it?" line | Done | `c08fd01` (end-session skill) |
| § 11 `Update.Results`, code review, docs meeting | Not yet | ROADMAP, In order 1–3 |
| § 12 Sort box | Done | `bc5ed5b` |
| § 13 The SPEC sweep | Not yet | ROADMAP, In order 4 |
| § 14 After the public repository | Tabled | ROADMAP, In order 7 |
| § 15 The order | Kept | the safety items came before this meeting, the chair's choice |

## § 5 A general pattern for the extras' own data?

**Background.** The owner asks whether there is a general pattern where the extras need to keep data in structures of their own: sync data for news and calendars, the blog's publishing state, and so on. If it is a pattern, should there be an overarching strategy for handling these cases? Useful findings are added to the plans.

**Discussion.** Claude explained the present shape: each extra keeps a typed struct in the file (`db.feeds`, `db.calendars`, `db.blog`); a feed keeps, for each live entry, a copy of the title and note it filed, so that a refresh can tell the person's edits from the feed's; the blog works out what is published from its posts category. **Joe** called it a pattern with a good shape, one typed record per extra beside the data in one file, lacking a rule for what goes in: a copy kept for comparing is the expensive habit, and a fingerprint answers the same question at a fraction of the size. **José** wanted one typed struct per extra kept, not a generic store, since Dialyzer, the JSON schema and the golden files rely on knowing the shape. **Carsten** asked the rule to say where things belong: what the person would see or search on items, what only the machine needs in the extra's struct; a separate store for ingested volumes stays worth planning, but not yet. **Marie** asked for one rule, written once, applied at once where it pays. **Claude**, for its own lens, said a written rule lets an agent tell the person's data from bookkeeping.

**Decided:** an ADR with the rule (ADR 0048): one typed struct per extra; only ids, dates, settings and fingerprints, never copies of what items hold; what the person should see lives on items; every field in the JSON schema and the golden files. First use: fingerprints instead of copies in the feed and calendar snapshots (a format change). A separate store for ingested items stays a later question in `plans/ITEM_LEVELS.md`.

## § 6 What the person should see, and could unindexed columns show it?

**Background.** Some of the extras' data could be useful to the person too: the last logs, the names of the RSS feeds. Could unindexed columns be useful? The owner asked earlier whether a feed's name could be an unindexed column instead of a category, so that the feeds do not crowd the category list.

**Discussion.** Claude explained the choice with an example: today "Honey prices up" is in Feeds ▸ Heffalump News, one of 243 feed categories, and the News view has a section per feed; with an unindexed Feed column, one category would give each entry the text "Heffalump News", the list would shrink to about 26 categories and the News view become one river, but sections, filters and conditions by feed would be lost, and a conversion to unindexed cannot be undone (R29b). The last logs belong to a feed, not an entry, and are already in the Feeds and Calendars boxes. **Mitch** said unindexed categories are Agenda's tool for text that is no classification, while a feed is partly one; whether Agenda allowed an unindexed section head or filter is unchecked. **Marie** welcomed fewer categories; **Carsten** suggested a river with an optional own section per feed; **Joe** warned that the conversion is one-way. Before deciding, the chair asked whether there could instead be an "ingested category" for a feed's name: given by the feed, not editable, and therefore not shown in the category manager by default. **José** advised a `source` field on `Category` rather than a new kind, "not editable" and "hidden" following from it, a small format change without a lossy conversion. **Joe** noted it is reversible: an unsubscribed feed's category can become the person's again. **Carsten** liked that the source stays a classification, and asked for a key to show them and that nothing is assigned to one by hand. **Marie** called it tidiness without loss. **Mitch** noted Agenda had no such thing, so it is an enhancement behind the Extras switch (ADR 0043), for calendars too. **Claude** said an agent can tell machine-made categories by the field.

**Decided:** ingested categories, the chair's direction: a feed's category gets a `source` (`{:feed, id}`, later calendars), is named and filled by the feed, not editable or assignable by hand, hidden in the category manager by default with a key to show them, and still heads sections, filters views and is read by conditions. The details go into `plans/RSS_READER.md` before a roadmap item is built. The last logs stay in the Feeds and Calendars boxes.

*Marie unfolded her accordion of categories, folded 243 of them back, and handed Owl the short end.*

## § 7 Any other business

None.

## § 8 Next meeting

When the agenda has enough items; the meeting on what information to make public in the docs is on the roadmap (In order 3).

## § 9 Closing of the meeting

Owl closed the meeting and rubbed out the chalk on the door, saying he would start again from one tomorrow.

## Decisions and where they are recorded

| § | Decision | Recorded in |
| --- | --- | --- |
| 5 | The rule for what an extra keeps; fingerprints in feed and calendar snapshots; a separate store later | ADR 0048, `docs/ARCHITECTURE.md` (ADRs), `docs/ROADMAP.md` (Beyond Agenda), `docs/plans/ITEM_LEVELS.md` |
| 6 | Ingested categories, details in the plan first; logs stay in the boxes | ADR 0048, `docs/plans/RSS_READER.md`, `docs/ROADMAP.md` (Beyond Agenda) |

*Minutes kept by Claude. Approved by Old Mitch Lilypad and Little Marie-Who-Folds.*
