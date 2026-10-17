# A plain RSS reader

**Status:** built 2026-10-17 (R75, v0.13.0), approved by the owner the same day (tagged). Step 1 of "An RSS reader, with Wol later" (ROADMAP, Beyond Agenda; meeting 2026-10-16-2, § 7). Wol's part (summaries, sifting, suggestions) is step 2, after principle 6 of `WOL-IN-THE-MACHINE.md`.

## The idea

Feeds come in the way calendars do (R45): a subscription in the file, read by the shell, mirrored into items by a pure core module. A feed entry becomes an item in the feed's category, filed further by Agenda's own text matching and conditions, as typed items are. Nothing asks to be dealt with: there are no unread counts, an entry left alone fades away after a while, and keeping one is a choice (meeting § 7: "an entry never asks to be dealt with").

The entries are what `ITEM_LEVELS.md` calls *ingested items* (level 2). This first reader does not add levels: an entry is an ordinary item, and its feed remembers which items it made, as a calendar does. When levels come, these are the items that become level 2, and "kept" below is what promotes one.

## What the owner decided (2026-10-17)

| Question | Decision |
| --- | --- |
| Where entries go | A category per feed under **Feeds** (made when first needed): Feeds ▸ Elixir Forum |
| Their date | The entry's publish date is its **Entry** date; When stays empty, so feeds stay out of date views and the calendar |
| How long they stay | Entries older than the feed's **keep days** (30 by default; 7, 30, 90, 365, or for ever) are discarded at a refresh, unless **kept**: given a Zettel id, its text or note changed by the person, or a category given by hand. Done does not keep: it dismisses |
| An entry's item | Its text the title; its note the summary as plain text (HTML turned into text, at most about 2,000 characters), then a line with the link |
| Read or unread | Neither. F4 Done dismisses an entry: the News view hides done items |
| Reading the article | **CTRL-V** opens the highlighted item's link in the browser (also Item ▸ Open link) |
| Feed lists | **OPML** import and export |
| A view | Subscribing to the first feed makes a **News** view: a section per feed, newest first, done items hidden |
| How often | Every hour while Agendum runs by default (or 6 hours, a day, only on request), and at start, as calendars |
| Not now | A "reason" per feed (why one follows it), Wol's summaries, sifting, duplicates, likes and dislikes (the owner's notes for step 2) |

## How it is built

- **`Agendum.Core.Feed`**: the subscription, a struct in the file (`Database.feeds`, format version 36, JSON `feeds`): name, url, category, keep days, refresh minutes, last read and error, and `entries`: what each entry (by its id: the guid, else the link, else title and date) looked like when last read, and its item. An entry the person discarded, or that faded, keeps its snapshot without an item, so the next refresh does not bring it back.
- **`Agendum.Core.FeedParser`**: RSS 2.0, RSS 1.0 (RDF) and Atom, read by a small XML reader of our own, pure Elixir: no atoms are made from a feed's tag names (OTP's `xmerl` would make them, and a hostile feed could fill the atom table), and broken feeds are read as far as they go. Dates in RFC 822 (RSS) and RFC 3339 (Atom).
- **`Agendum.Core.Html`** (or in the parser): HTML to plain text, entities decoded, paragraphs and list items as lines.
- **`Agendum.Core.FeedSync`**: like `CalendarSync`. New entries within the keep window become items (through the facade, so text matching and conditions file them; dates in a title are not read as When); entries the feed changed update their item where the person has not changed it; entries past the window fade unless kept. Returns how many new, changed and faded.
- **Facade `Agendum.Core.Facade.Feeds`**: subscribe (makes Feeds ▸ name, and the News view the first time), unsubscribe (optionally discarding its items), sync, failed, cycle a setting, feeds due, OPML in and out (pure: text to feeds, feeds to text).
- **Shell**: `Agendum.CalendarFetch`'s download made shared (`Agendum.Fetch`), reading feeds in the background as calendars are; `{:fetch_feed, id, url}` comes back through `Update.feed_read/3`. Opening a link is an effect, `{:open_url, url}`: `open` on a Mac, `xdg-open` elsewhere, only `http(s)` addresses.
- **TUI**: File ▸ Transfer ▸ Feeds, a box like Calendars: INS subscribes (address, then a name), ENTER reads now, F how often, K how long to keep, DEL unsubscribes, I imports OPML, E exports OPML. CTRL-V in a view (and Item ▸ Open link) opens the link in the item's note.
- **Safety**: feed text is data, never instructions (Wol's principle 6 starts here): titles and summaries are stored as text, HTML is never shown as markup, and the reader runs no code from a feed.

## The steps

1. Parser, HTML to text, `Feed` and `FeedSync`, the facade, format 36 (core, test-first).
2. The shell: fetching in the background, the Feeds box, the News view, CTRL-V.
3. OPML in and out.
4. SPEC R75, the documents, a version (0.13.0), the long fuzz run.
