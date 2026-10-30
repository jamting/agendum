# Minutes of the panel meeting, 2026-10-16-1905 (second)

**Place:** Owl's house, the Hundred Acre Wood
**Present:** the owner (chair); Old Mitch Lilypad, Carsten Stargazer, David the Squirrel, Dr. Russell, Little Marie-Who-Folds, Claude (Owl's cousin); Owl, host
**Excused:** José Who Brews, Great-Uncle Joe (no code or architecture on the agenda)
**Secretary:** Claude · **Approvers:** Little Marie-Who-Folds, Dr. Russell
**Agenda:** [dagordning.md](dagordning.md) · **At commit:** `8de3685`

*The second meeting in Owl's house that day. The teacups from the first had been washed but not yet put away, and Marie, without being asked, arranged them by size on the windowsill. Uncle Robert's portrait still hung slightly crooked. The panel's voices are lenses in the spirit of the named people, written by Claude, not their words; these minutes were made with the `meeting` skill.*

## § 1 Opening of the meeting

The chair opened the meeting. Owl welcomed everyone back the same day, and remarked that the portrait was still slightly crooked.

## § 2 Election of a chair, a secretary and two approvers

The owner chairs the meeting. Claude was elected secretary; Little Marie-Who-Folds and Dr. Russell were elected to approve the minutes.

## § 3 Adoption of the agenda

The agenda was adopted as proposed. The owner's single note was worded as four items (§ 5 to § 8). The owner's thoughts below the agenda's line were not discussed. José Who Brews and Great-Uncle Joe were excused.

## § 4 The previous minutes

All four decisions of the meeting earlier that day (`docs/meetings/2026-10-16-1905/protokoll.md`) were built the same evening and released in v0.8.0 (`9ea26fe`).

| Decision | Status | Evidence |
| --- | --- | --- |
| § 5 Reopen a file where you left it | Done | `5670ddf`, R69 |
| § 6 "While you were away" box | Done | `bc3b00a`, R70 |
| § 7 ► on the current view in the view manager | Done | `8a1459a`, R68 |
| § 8 Views sorted by recently used (F5) | Done | `b2b3494`, R68 |

## § 5 Who might use Agendum: a brainstorm

**Background.** The expert review of 2026-10-16 (`docs/reviews/2026-10-16-3.md`) gave a first idea of who Agendum serves at each stage of the project: the three groups in `docs/VISION.md`. The owner wants to talk about it, and to brainstorm possible users.

**Discussion.** Claude reported the three groups in `VISION.md:5-15`, in order: the owner; Agenda's old users and keyboard people; later, as a guess, people who are not nerds, on the web, with people with ADHD or easily overwhelmed as a possible group within them.

**Mitch** named the people Agenda served best: those who juggle people and promises, such as consultants, lawyers, journalists, researchers and managers (`docs/AGENDA_HISTORY.md`), and writers who collect quotes and sources. **Carsten** named Org-mode and Emacs users and the personal-knowledge crowd (Zettelkasten, Obsidian, Logseq), who care about owning their data for decades, and researchers keeping reading notes. **David** named GTD practitioners who have outgrown paper or a task app and do a weekly review. **Russell** named adults with ADHD, students, caregivers who juggle a family's appointments, and people coming back after burnout, who need a tool that does not scold. **Claude** named privacy-minded people who want a language model over their own data, on their own machine; developers who want a scriptable personal database; and, in time, agents, as users of the command layer. **Marie** observed that the owner's own uses are the clearest users of all (a blog, feeds, trackers for moods, dreams and training), and that they put the RSS reader and the blog in group 1, which by the vision's own rule may go ahead of parity.

Mitch and Marie would keep the brainstorm out of `VISION.md`, which should stay an order and not a list; Claude and Russell thought a few named guesses would help choose the five real users the roadmap asks for. The panel advised keeping the brainstorm in the minutes, with one sentence on the owner's own uses under group 1 and a one-line list of candidates under group 3.

The chair said that they really like the idea of a tool that does not scold.

*Russell underlined it twice with a teaspoon.*

**Decided:** The panel's advice. The brainstorm is kept in these minutes; `VISION.md` names the owner's own uses (a blog, feeds, trackers) under group 1, and lists the candidate users to test, from which the five real users are chosen, under group 3.

## § 6 Sort "Beyond Agenda" by who it serves

**Background.** The review recommended that each "Beyond Agenda" item on the roadmap name the group in `VISION.md` it serves, and that items for no group yet move to Ideas (recommendation 8). Should the sorting be done that way, or should the items become ideas?

**Discussion.** Claude reported nine top-level items in "Beyond Agenda" and four in Ideas, and offered a first sorting, using § 5: the item levels, Zettelkasten IDs, the micro-blog and metadata serve group 1; the guard against a file changed on disk and capture from outside serve groups 1 and 2; the GTD starter group 2 (`VISION.md:15` says so); "Modern by default" and more date languages serve group 3; flashcards no group yet.

**Marie** said that with this sorting "Beyond Agenda" becomes the list of what is next and Ideas the shelf, and nothing is thrown away: each idea keeps its group and its plan link and can move back up. **Mitch** would move group-3 items to Ideas as well, since the vision says group 3 waits, and order "Beyond Agenda" with group 1 first. **David** warned against turning every item into an idea: a list with no next step is a someday/maybe list, and the GTD starter and the guard are real next steps. **Claude** kept metadata among the items in work, since provenance (where an item came from) is the first thing the RSS reader and Wol need (principle 6 of the Wol plan); its group-3 parts can wait inside the item. **Russell** said a shorter list of what is next is easier to face, and that a group tag says why something waits, not only that it waits.

The panel advised tagging every item in "Beyond Agenda" and Ideas with its group, keeping groups 1 and 2 in "Beyond Agenda", group 1 first, and moving the items for group 3 or no group to Ideas.

**Decided:** The panel's advice. Every item in "Beyond Agenda" and Ideas names its group; groups 1 and 2 stay in "Beyond Agenda", group 1 first; "Modern by default", more date languages and flashcards move to Ideas, one line each with their group and plan. The roadmap's box for weighing "Beyond Agenda" against the vision is done.

## § 7 An LLM-enabled RSS reader

**Background.** Add an RSS reader enabled by a language model to "Beyond Agenda", if it is not there already; or make it an idea.

**Discussion.** Claude reported that RSS appears only as a sub-box under the item levels on the roadmap, in `docs/plans/ITEM_LEVELS.md:21`, and in the Wol plan (`docs/plans/WOL-IN-THE-MACHINE.md:31`), whose principle 6 (text from feeds is data, never instructions) is to be settled before the first feed is read (`:47`). The shell already fetches calendars over HTTP (`Agendum.CalendarFetch`), and OTP's own `:httpc` and `:xmerl` could fetch and parse feeds with no new dependency.

**Mitch** said Agenda never read feeds, but that they fit its idea: text arrives and files itself, and Agenda's text conditions can already file an entry about Elixir under Elixir without any model. **Carsten** pointed to elfeed, a feed reader inside one's own tool, and asked that the feed list import and export as OPML so it travels. **David** said a feed is a second inbox, and an inbox that only fills breeds guilt: an entry must never demand to be dealt with. **Russell** tied this to § 5: no unread counters and no red numbers. **Claude** advised two steps: a plain reader first, useful on its own and a way to learn the volumes; then the model's summaries, sifting and suggestions, only after principle 6 and the golden tasks with hostile feed text; the choice of model belongs to the Wol plan. **Marie** asked that RSS have one home: the new item absorbs the sub-box under the item levels.

**Decided:** The panel's advice. "An RSS reader, with Wol later" is a group-1 item in "Beyond Agenda", in two steps: a plain reader (feed entries as ingested items, filed by conditions; OPML in and out; no unread counts), then Wol's summaries and suggestions, after principle 6 and the golden tasks. It replaces the RSS sub-box under the item levels. The detailed design waits for the owner's notes, which are still below the agenda's line.

## § 8 The micro-blog: a static site generator, the owner's own use case

**Background.** Another idea, which would mean a lot to the owner as a real use case: a blogging tool in the spirit of micro.blog. A static site generator that publishes a category, hosted on any site reachable by FTP or sshfs, reasonably compatible with the fediverse. The design should be "old-school-cool", and RSS feeds are a must.

**Discussion.** Claude reported that the roadmap already has a micro-blog: the items of a chosen category as posts, File ▸ Transfer ▸ Publish writing an index, a page per post and `rss.xml` in plain HTML, from a pure core module, synced with rsync over ssh. It said nothing of FTP, sshfs, the fediverse or the design.

**Carsten** observed that sshfs needs no code (a mounted folder is a folder, and Agendum already writes to one), that FTP and FTPS are part of OTP itself (the `ftp` application, so no new dependency under ADR 0021), and that passwords should never be stored in the file (`~/.netrc`, or asked each time). **Claude** explained that a static site cannot be a full fediverse account, since being followed needs a server with an inbox; "reasonably compatible" can mean microformats (`h-entry`, `h-card`) in the pages, RSS and perhaps a JSON Feed, and optional `rel="me"` links, so that micro.blog or a bridge such as Bridgy Fed can make the blog followable from Mastodon. **Mitch** said "old-school-cool" suits the program's soul: monospace, a few colours, readable without its stylesheet, with the stylesheet one file the person can replace. **David** and **Russell** asked for publishing as one command with a safe step before it: posts in a Draft category are left out, and the command shows what will be added, changed or removed before uploading, since a post is public. Russell added that a short path from a thought to a post is what makes a blog happen. **Marie** asked for a small first version (no comments, no tag pages, no JavaScript), and noted that it serves group 1.

The panel disagreed on the order. Mitch would keep the `.AG` importer first, since it brings group 2; Marie and Russell would build the blog right after the guard against a file changed on disk, since the owner's daily use comes first.

*Mitch gathered his papers from the floor without a word, and Owl offered him the last biscuit by way of consolation.*

**Decided:** The micro-blog item gets the panel's additions: FTP or FTPS and plain folders (sshfs) beside rsync, with no stored passwords; microformats, RSS (and perhaps a JSON Feed) and `rel="me"`, for following through micro.blog or a bridge; an old-school-cool stylesheet the person can replace; drafts by category; a preview of the changes before uploading; a small first version. It is the next "Beyond Agenda" item to build after the guard against a file changed on disk, ahead of the `.AG` importer.

## § 9 Any other business

The chair had nothing more to raise.

## § 10 Next meeting

When the agenda has enough items.

## § 11 Closing of the meeting

The chair closed the meeting. *On the way out, Marie thanked the windowsill teacups for their service; Owl said they were not going anywhere, and she agreed that they need not.*

## Decisions and where they are recorded

| § | Decision | Recorded in |
| --- | --- | --- |
| 5 | The owner's own uses under group 1; candidate users to test under group 3 | `docs/VISION.md` (Who Agendum is for) |
| 6 | Every "Beyond Agenda" and Ideas item names its group; groups 3 and none wait in Ideas | `docs/ROADMAP.md` (Beyond Agenda, Ideas; the weighing box under Done, Users and direction) |
| 7 | An RSS reader in two steps, plain first, Wol later | `docs/ROADMAP.md` (Beyond Agenda); `docs/plans/ITEM_LEVELS.md`; `docs/plans/WOL-IN-THE-MACHINE.md` |
| 8 | The micro-blog extended (FTP, sshfs, fediverse, design, drafts, preview), next after the disk guard | `docs/ROADMAP.md` (Next line, Beyond Agenda); `docs/VISION.md` (the rule's examples) |

*Minutes kept by Claude. Approved by Little Marie-Who-Folds and Dr. Russell.*
