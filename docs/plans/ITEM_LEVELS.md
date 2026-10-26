# Three levels of items: zettels, ingested items, context items

**Status:** vision, not started (2026-10-16, from the owner). Shapes the format decision (ADR 0034), the Zettelkasten IDs, calendar and RSS ingestion, the JSON export and Wol (`WOL-IN-THE-MACHINE.md`); tracked in ROADMAP ("Beyond Agenda").

## The idea

Agendum will hold far more than what a person types. Besides their own items, it takes in information from outside, and a language model (Wol) adds what it works out about the meaning of it all, as context for itself. These are kept apart as three levels of items:

| Level | What                                                                                                   | Made by                                       | The person can                                                                                     |
| ----- | ------------------------------------------------------------------------------------------------------ | --------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| 1     | **Zettels**: the items the person cares for, each with a Zettelkasten ID                                | the person (or promoted from level 2)         | everything, as with any item today                                                                 |
| 2     | **Ingested items**: calendar events (iCal), RSS feed entries and other feeds                            | ingestion from outside sources                | promote one to a zettel when it is interesting enough; otherwise it is discarded, according to rules |
| 3     | **Context items**: what the language model infers about the semantic meaning of the information        | the language model                            | inspect, not edit; to change them, tell the model to change how it behaves                         |

The volumes of levels 2 and 3 can be substantial: thousands of feed entries, and context items about all of them. That is why the format of record stays the compact, fast Erlang-term file, and why many users will get a database (ADR 0034).

## What it touches

- **Zettelkasten IDs** (ROADMAP, "Beyond Agenda"): the ID and the `[[…]]` links become what makes an item a zettel. A promoted item gets its ID when it is promoted.
- **Calendar subscriptions** (R45) are the first ingested items: `Agendum.Core.Extras.CalendarSync` already mirrors a calendar's events into items. They become level 2, and promoting one makes it the person's.
- **RSS and other feeds**: new sources of level-2 items, fetched by the shell like `Agendum.Extras.CalendarFetch`; the first is the RSS reader, a roadmap item of its own (ROADMAP, "Beyond Agenda"; meeting 2026-10-16-2, § 7).
- **Rules for ingested items**: what is kept, promoted or discarded. Agenda's own machinery may carry much of it: conditions and actions (R15, R15b) and the Discard special action already file and remove items by rule.
- **Wol** (`WOL-IN-THE-MACHINE.md`): context items are where the agent keeps what it has learnt, inside the file, visible to the person, in line with its principle that the person decides; the person steers it by instruction, not by editing its notes.
- **The JSON export** (R44, ADR 0034): the person chooses which levels to include, as Agenda's STF export chooses which items and assignments go in. An export without some levels is partial on purpose.
- **Performance**: every key rebuilds the view today, and reading dates is slow (ROADMAP, Sharpen the saw). Large levels 2 and 3 make both matter more, and views will likely show only level 1 unless asked.

## Open questions

To settle with the owner before the work starts:

- Whether ingested items belong in the person's file at all: a separate store for them would keep the file small whatever the feeds do (Carsten, expert review 2026-10-26, § 17.2). Taken up at the meeting on the extras' data (meeting 2026-10-26-5, § 5): left for later, when volumes ask for it; meanwhile an extra keeps only ids, dates and fingerprints (ADR 0048).
- How a level is stored: a field on the item, or something derived (a zettel is an item with an ID)? Either is a stored-field change (format version, JSON schema, golden file). *Partly answered* (meeting 2026-10-16-3, § 6): the Zettel id is a stored field, given by a command ("Attach Zettel id") and not to every item, so a zettel can be an item with an id; whether levels 2 and 3 need a field of their own is still open.
- Special Zettel ids and Agendum instances talking to each other (meeting 2026-10-16-3, § 6): the reserved words of Quadsyl-24 (ADR 0039) are meant as well-known places, e.g. a mailbox in each file. Two files that each count from 1 give out the same ids, which collide when they exchange zettels: give each instance a range of its own, qualify an id by its instance, or something else? To settle before the reserved words are given out, and before the counter's design closes a door.
- What views show by default, and how a view or a section asks for levels 2 and 3.
- Whether text matching and conditions run on ingested items, or only once they are promoted, given the volumes.
- Where the rules for ingested items live: Agenda's conditions and actions, or rules of their own; how long discarded items are kept.
- How context items refer to what they are about (items, categories) and what happens to them when those change or go.
- Undo: ingestion and the model's context items are not the person's actions; should they be undo steps at all?
- Whether ingested items are read-only (meeting 2026-10-22-3, § 6, referred here). Today a feed entry is an ordinary item: editing its text or note keeps it from fading (`Agendum.Core.Extras.FeedSync.kept?/3`). The panel's views: Mitch, entries stay ordinary, editable items, as Agenda's idea has it; Carsten, the feed's text stays as written and the person's words go in the note; Claude, Wol needs to tell the feed's words from the person's. Whatever is decided, keeping an item should be visible and deliberate (David), never a side effect of an edit.
