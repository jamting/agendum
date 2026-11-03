# Roadmap

Small, testable increments: the open work, by lane.

- **Done work** is the record in [`ROADMAP_DONE.md`](ROADMAP_DONE.md), by milestone: tick a box when its tests pass under `mix check`, and move it there. Areas with nothing open are there only: the clone's safety (done 2026-10-26: the closed effect type, the recovery file on a crash, R82b, and the hostile-text tests, R82c).
- **Rule numbers** refer to `SPEC.md`; larger items have a plan in `docs/plans/` (see `docs/INDEX.md`).
- **Open** starts with "In order", the next few things across every lane; then the lanes in the owner's order (the owner, 2026-10-31): 1 performance and bugs, 2 security, 3 parity with Agenda, 4 the extras; then the standing areas (Sharpen the saw, Housekeeping, Users and direction) and what lies further out (Beyond Agenda, Ideas).
- **The parity work** lives in [`plans/AGENDA_PARITY.md`](plans/AGENDA_PARITY.md) § The steps, in its order.
- **"Sharpen the saw"** is the standing home for work on the tools, checks and ways of working that make later changes faster and safer.

## Open

**In order:** what comes next, across every lane (the owner reorders it; details where each line points; the owner, 2026-10-31):

1. [ ] **The publisher's round 2** (meetings 2026-11-02-1954, § 13, and 2026-11-02-2244, § 7; [`plans/PUBLISHER_2.md`](plans/PUBLISHER_2.md) § The steps), steps 1 and 2 done (the R74 split; images from `assets/`, v0.87.0); next step 3: **Lists** (any of the person's own categories published as a list, replacing feeds; meeting 2026-11-02-2244, § 6), the newest N plus an archive per list, a 404 page, tag pages as a list made from a family, and, optional, `--publish --quiet` for launchd or cron. Round 1 is done (v0.79.0–v0.85.0, [`plans/archive/PUBLISHER.md`](plans/archive/PUBLISHER.md)).

Starters are done for now (the owner, 2026-11-02): GTD and the Journal are built and in use; the two in lane 3 are parked.

### 1 Fixes and polish (performance and bugs)

Kept running well as today: the nightly fuzz run (10,000 walks and the parsers), the real-terminal scenarios (`mix agendum.smoke`), the debug log read on every crash report, and reviews when the owner starts one (the owner, 2026-10-31).

- [ ] Left from the local review of group e, the keys (2026-10-30; the rest fixed in v0.72.7):

  - **A refused command still moves the screen on** (`State.run/2` drops the refusal): removing a column moves the highlight, ALT-Y says "Yanked back" over the error. Not reproduced (2026-10-31): after the TUI's own checks the core cannot refuse either command, so nothing was changed; fix it when a refusal becomes possible.
  - **Later, with the view cache** (below, when the evidence asks): a key in a column builds the view model up to four times (`Layout.current_column`, each `current_row` builds it again).
- [ ] Optional (the owner, 2026-10-27): try v0.69.3's main fix by hand: open a second file while a feed is being read, and see its entries land only in the file that asked (the richer fuzz walks already check it)
- [ ] A view cache, when the evidence asks for it: every key rebuilds the whole view (each item's cells, and every item's text wrapped for the screen, not only the rows shown), about three times per key.

  - **Measured** 2026-10-16, a cursor move: 300 items 6 ms in `Update` + 11 ms in `Render`; 3,000 items 61 + 45 ms; 10,000 items 205 + 231 ms.
  - **First** build it once per key and share it; then keep it in the session's state between keys as a value with a key that says when it is stale (ADR 0035): the database, the view, the date and time, the screen width, collapsed families, the search. Needs an ADR.
  - **Wait until the debug log shows `slow answer` lines (over 100 ms) in real use** (owner's decision, 2026-10-16); ingested items (`plans/ITEM_LEVELS.md`) will likely be what brings them.

  Update 2026-10-25 (v0.31.2): the first real-use slowness came from many sections, not many items (the owner's News view, 243 sections: ~135 ms a key); fixed without a cache (`ROADMAP_DONE.md`, Sharpen the saw), and wrapping and drawing now touch only the rows down to the highlight and on screen.

  Left: the view is still made about three times per key, so "build it once per key" is the next step if it is slow again. The command layer, which reshaped the state it would live in, is done; the TUI state's split into file and session (Towards many users) reshapes it again

### 2 Security

Security for the person in both senses: protection from others, and the program never betraying them in what it fetches, sends and logs (the owner, 2026-10-31).

- **Kept very short:** open items only; expert and code reviews add to it; an item here is fixed as soon as possible, and a done one moves to `ROADMAP_DONE.md`.

The list is chosen from the threat model, [`SECURITY.md`](SECURITY.md) (each item names its door there).

- [ ] Standing, about once a quarter (next by 2027-01-31): look over the CI pipeline (workflows, permissions, secrets), move the actions' pinned commits to their newest versions (each pin names its version in a comment), and the dependencies (four, all dev/test only, ADR 0021)

### 3 Towards parity with Agenda (Milestone 2)

**Done:** the truthful clone was declared done on 2026-10-26 with v0.62.0 (meeting 2026-10-26-1108, § 7). **The ambition was:** Agendum as close to Agenda 2.0 as makes sense: the same screen, keys, menus and behaviour, apart from accepted enhancements and modifications. The parity work, its order and its details are in one place: [`docs/plans/AGENDA_PARITY.md`](plans/AGENDA_PARITY.md) § The steps (with how close Agendum is, and the two lists).

**As today** (the owner, 2026-10-31): when Agenda is found to behave otherwise than Agendum, it is checked in DOSBox, tagged by ADR 0043's test, decided by the owner and fixed.

**Starter files are base features**, not extras (the owner, 2026-10-31): Agenda shipped its starter applications, so a new starter is content of the clone, made only of the clone's features. A starter that needs features outside the clone may be an extra instead, there only with the Extras switch on; a feature a starter would need goes to its own lane first.

**Done for now** (the owner, 2026-11-02): the GTD and Journal starters are built; the owner uses them a while before more are made. The two starters below are parked until then; what the built ones decided, and the features they lacked, are in [`plans/STARTERS.md`](plans/STARTERS.md).

- [ ] (parked) A **To-do lists** starter (meeting 2026-11-02-1043, § 5; [`plans/STARTERS.md`](plans/STARTERS.md)): the simplest starter, opening on the lists with one line to type, done items hidden; a second view, Projects, with a section per project, a Due column and an example of prerequisites (Utilities ▸ Show ▸ Prereqs). No separate project-management starter
- [ ] (parked) A starter for the easily overwhelmed, with a gentler "Overdue" (fewer at a time, kinder words, made with a filter and view names) than the Planner's (`lib/agendum/starters/planner/views.ex:73`), which stays as Agenda's PLANNER (expert review 2026-10-21, § 17; meeting 2026-10-22-2130, § 5k). See [`plans/STARTERS.md`](plans/STARTERS.md) (the three-days-away test, the mood tracker). An Overdue that adapts (three at a time, more as they are cleared) is beyond the clone
- [ ] Optional, the clone's leftovers (from the parity plan, 2026-10-26):

  - ALT-F1 COMPOSE, Agenda's way of typing accented and special characters by two keys
  - Agenda structured files (`.STF`), import and export as Agenda 2.0's File Transfer does (Working with Definition Files, Appendix B; User's Guide chapters 23–24), reading both 2.0 and 1.x dates into the same When, Entry and Done categories
  - With STF: File Properties ▸ Auto-import file, Agenda's structured file imported each time the file is opened (to check in Agenda first)
  - Import of structured text files, one item per line with categories
  - TXT2STF-style definition files that turn plain text into items; a first use, the session summaries
  - Utilities ▸ Launch, a shell without quitting Agendum
- [ ] The `.AG` import (R72), still to bring over: note files (read by the shell beside the `.AG`), the global date format, a datebook's base date
  - [ ] Macros. Every macro in the files at hand is a starter's helper program in Agenda's macro command language (`{INPUTTEXT;…}`, `{DEFSTR;%var}`, `{LABEL}`, `{WINDOWSON}`), not recorded keystrokes, so R50 cannot run them.

    The owner's own Planner has only Planner's 10 (contact list, date settings, hide done, print, four sorts), none of the owner's. Planner, Account Manager, People Manager and Information Sifter have 10, 14, 10 and 6 (checked 2026-10-16).

    Options when picked up: import plain keystroke macros as R50 macros, and keep each other macro's text in a note so it can still be read; the command language itself stays out of scope (SPEC § 6)

### 4 The extras

**The switch stays** (the owner, 2026-10-31): one quiet setting in clone mode (Utilities ▸ Customize); with it off, nothing of the extras shows. The extras meet the clone's guidelines since v0.72.0 (ADR 0049); there is no freeze on new ones.

**An Extra or Beyond Agenda** (ADR 0043, amended 2026-10-31): an extra adds to Agenda's way and can be switched off without leaving a hole (the note preview column); a change to how the program works at its heart, which cannot be a switch, is Beyond Agenda.

**In this order** (the owner, 2026-10-31); the rest after, unranked:

1. [ ] **The publisher** first, as the site uses it: its fixes and polish before other extras' when found; round 1 is done (v0.79.0–v0.85.0, [`plans/archive/PUBLISHER.md`](plans/archive/PUBLISHER.md)), round 2 is [`plans/PUBLISHER_2.md`](plans/PUBLISHER_2.md) (In order). Then, after round 2 (meeting 2026-11-02-1954, § 10): the same list-and-properties-box pattern for the RSS Feeds' and the Calendars' settings (meeting 2026-11-02-1255, § 10), what ENTER does there asked when it is built
2. [ ] **Modern keys and command names**, an extra (ADR 0038, amended 2026-10-31): today's names and standard keys (Open not Retrieve, Delete not Discard, CTRL-O/S/Z/F/N…) as a second keymap and the menu's names, a setting in the same program (Utilities ▸ Customize ▸ Keys: Agenda, the default, or Modern; meeting 2026-10-22-2130, § 6), never a second program.

   - **Made from the keymaps** (ADR 0045), kept apart from Agenda's; the function keys stay required (ADR 0032).
   - **The fuzz walks run under both keymaps,** so the second cannot rot.
   - **Why:** Agenda's steep learning curve limited its audience (AGENDA_HISTORY.md); the power should stay, the strangeness should not be the first thing people meet. Departs from ADR 0006 and 0007 only behind the switch.
3. [ ] **A read-only headless command and golden tasks**, as one item: `agendum --json view NAME FILE` in the escript, sharing `mix agendum.thoughts`'s code (expert review 2026-10-30, § 18.5), and a few small files with a request each and the commands a good answer proposes, which also test the command layer's design (expert review 2026-10-16, second meeting, `docs/reviews/2026-10-16-2.md`). The groundwork for Wol without a model; item text is data and never instructions (the Wol plan's sixth principle)

- [ ] The date filter's "or not assigned" (meeting 2026-10-28-0048, § 6; [`plans/STARTERS.md`](plans/STARTERS.md)): a Date Filter can show the items without a date as well as those in its range, so a view filtered on Start up to today also shows items with no Start ("not active until", Things' start date, GTD's tickler).

  Agenda's filter has Assigned and Not assigned apart (User's Guide 11-6), so it is an extra behind the Extras switch (ADR 0043), in the clone's Date Filter box's patterns (ADR 0049)
- [ ] The RSS reader (R75, v0.13.0; plan: [`plans/RSS_READER.md`](plans/RSS_READER.md)): Wol's part (summaries, sifting, suggestions; `plans/WOL-IN-THE-MACHINE.md`), only after its principle 6 (feed text is data, never instructions) and the golden tasks with hostile feed text. Which model is for the Wol plan. Whether feed entries should be read-only was referred to `plans/ITEM_LEVELS.md` (meeting 2026-10-22-2337, § 6)
- [ ] Later (the owner, 2026-10-26, after v0.66.0): shrink the faded feed entries further: a hashed entry id instead of the full guid or link (often a web address), and the publish date as a day number instead of a `Date` struct; the 13,181 faded entries are most of the feeds' 2.7 MB as a term in the owner's file (the file 1.21 MB on disk). A format change; not urgent, the save is 39 ms
- [ ] Calendar subscriptions (R45): repeating events in a calendar from another time zone: each occurrence converted in its own zone, so the weeks between the two zones' summer-time changes are not an hour off (SPEC R45)
- [ ] Zettel ids, a better feel (the owner tried them 2026-10-17 and approved them, v0.11.0: "the UX is a bit weak but it works"). Ask the owner what felt weak before building; what is known so far:
  - [ ] A Zettel id column without a head (R73a): with Format Zettel id the head is not used (the column shows each item's id under "Zettel id" whatever the head), yet Column Add asks for one first. Let Format come first, or let the head stay empty for this format, so no category has to be picked or made. A habit change only for this format; Agenda has no such column (AGENDA_PARITY, enhancements)
- [ ] Capture from outside (paused, owner 2026-10-16): the owner would rather capture through a URL scheme (such as `agendum://add?text=…`, which a phone, a browser or another program can open) than a shell command, `agendum add "text" FILE`; to be designed when picked up.

  Filed by the core as if typed in the view (the command `{:add_item, …}`), saying where it was filed; later a mail or phone path (expert review 2026-10-16). The first door without a keyboard, and an agent's first tool; the threat model (Security) covers it first
- [ ] Alarms sent to your phone with Signal, as well as on the screen: through the separate `signal-cli` program, linked to your Signal account; optional (nothing changes without it), set up in Utilities ▸ Customize

### Sharpen the saw

Tools and checks that make every later change faster and safer. Each is small; the command layer they made safer is done (R66, ADR 0036, in `ROADMAP_DONE.md`). From the expert review of 2026-10-16 (`docs/reviews/2026-10-16.md`) and the performance items found earlier.

- [ ] A snapshot test of what a front end may use (the owner, 2026-10-31; `ARCHITECTURE.md`, What a front end may use): the names and arities of `Agendum.Core`'s functions and `Database`'s read functions kept in a committed file; the test fails when one disappears or changes arity until the file is updated, the moment to write the CHANGELOG's Facade line (or to mark the function `@deprecated` first)
- [ ] See a nightly fuzz failure upload its log (expert review 2026-10-30, § 18.4; the owner, 2026-10-31: once, on purpose): make a run fail deliberately (a branch or a manual run with a failing seed) and check that its log arrives as an artifact; the rest is checked (2026-10-31, `ROADMAP_DONE.md`)
- [ ] Kept fast, but not at any price (the owner, 2026-10-26, and 2026-10-31: longer tests are welcome when they pay): measure `mix test` before and after a new test that adds more than a few seconds (about 37–40 s on 2026-10-31, with 1,000 fuzz walks in 8 parts); the long runs go to `mix agendum.fuzz` and the nightly CI (10,000 walks, the parsers at 2,000 inputs)
- [ ] Optional (the owner, 2026-10-30): one git-ignored link, `docs/private/`, to the owner's private documents (the Wolery's `docs/`), so they show beside the public ones in the editor (an Obsidian vault on `docs/`) and the tasks find them. Git never follows a link, so a mistaken `git add` cannot carry their text here.

  - **First check** that a linked folder breaks nothing: `mix docs`, the docs-index test, Obsidian, and a fresh clone without the link.
  - **Then** the skills, `mix agendum.thoughts` and the owner's local notes use `docs/private/…` instead of the Wolery's path.

### Housekeeping

- [ ] One line per meeting with what it decided (expert review 2026-10-30, § 18.7): in `docs/INDEX.md` or a short list in `docs/meetings/`, so a decision can be found by person or model without reading the 388 KB of minutes
- [ ] The licence and the CLA checked by a lawyer before the first outside pull request is merged (meeting 2026-10-28-1911, § 9; ADR 0051; `plans/GITHUB.md` § 7, step 7; a Swedish business lawyer, *affärsjurist*).

  - **Publishing does not wait for it;** the CLA bot blocks merging without a signature, and the public README says contributions open later.
  - **The lawyer reads** `CLA.md` and the dual-licensing question.
  - **The lawyer is asked** whether Agenda's captured texts may stay published (`docs/reference/agenda_*.json`, the 1,558 messages among them; the owner, 2026-10-28: once public, trimming them later leaves them in the history and in forks)
- [ ] Our own `.AG` test files without a starter underneath (meeting 2026-10-28-1911, § 7, found doing it): RICH.AG and DATES.AG were made in Agenda on Lotus's Planner starter (54 of their 55 categories are Planner's) and UX.AG on Information Sifter; they stay in the public copy, but could be made again from a blank Agenda file in DOSBox (`tools/agformat/agenda_driver.py`), with the tests' expectations moved to the new files; not before publishing
- [ ] The name's story and how it is said (meeting 2026-10-28-1233, § 5; ADR 0019, update 2026-10-28): one line, "Wol is how Owl spells his name", and "said wolz a-JEN-dum", where the name first meets a reader: the About help topic (`lib/agendum/tui/help/topics/about-agendum.txt`, built with the `feature` skill); the README (the tidy pass, 2026-10-28) and the site's front page (2026-10-30) have both

### Users and direction

- [ ] Real users, when there are any: old Agenda users and people who love keyboard tools, with the debug log on (`AGENDUM_LOG`) and a short talk with each; what they stumble on goes here (expert review 2026-10-16). Not a condition for declaring the clone done, and no search for old Agenda users now: the owner knows none (meeting 2026-10-22-2130, § 5a and § 5e)

### Towards many users

*[A page here was soaked in the creek. — Rabbit]*

### Beyond Agenda

Changes to how the program works at its heart, which cannot be a switch (ADR 0043, amended 2026-10-31). Each names the group in `VISION.md` it serves.

- [ ] Later (the chair, meeting 2026-10-26-2234, §§ 6, 8): settings as views, e.g. the feeds and calendars as a view of their own, one row per subscription with columns for address, how often, days kept, last read; a window onto the typed structs, never a second copy (ADR 0048)
- [ ] _Group 1._ Three levels of items (vision, the owner's, 2026-10-16; plan with open questions: [`plans/ITEM_LEVELS.md`](plans/ITEM_LEVELS.md)): zettels (the person's items, with Zettelkasten IDs), ingested items (calendar events, RSS entries …: promoted to zettels or discarded by rules) and context items (made by the language model to understand the information; inspected, not edited). The JSON export asks which levels to include, as Agenda's STF export chooses what goes in (ADR 0034). Volumes can be large
  - [ ] Settle the open questions with the owner before building (`plans/ITEM_LEVELS.md`, "Open questions"):

    - how a level is stored (a field, or derived: a zettel is an item with an ID);
    - what views show by default and how a view asks for levels 2 and 3;
    - whether text matching and conditions run on ingested items or only once promoted;
    - where the rules for ingested items live (Agenda's conditions and actions, or rules of their own) and how long discarded items are kept;
    - how context items refer to what they are about and what happens when that changes or goes;
    - whether ingestion and context items are undo steps
  - [ ] RSS and other feeds as sources of ingested items: the RSS reader (calendar events, R45, become ingested items too)
  - [ ] Rules for ingested items: keep, promote to a zettel, discard
  - [ ] The JSON export (R44) with a choice of levels; an import of a partial export says so
- [ ] _Group 1 (where an item came from), and 3 (who changed it, permissions)._ More about each item (metadata): when it was last modified and by whom, who may see or change it (permissions), where it was made (geo-tagging), where it came from (typed, ingested from a source, proposed by Wol: the provenance principle 6 of the Wol plan asks for), and so on.

  Of such metadata an item has only its Entry date today (`Agendum.Core.Item`). Serves many users (who changed what, sharing), the item levels and Wol.

  How it is stored and shown (fields of their own, Agenda-style special categories as Entry is, columns, conditions on it) is decided later, with an ADR (the owner's wish, 2026-10-16)

### Ideas

An idea moves up when the owner chooses it. Each names the group in `VISION.md` it serves (meeting 2026-10-16-2056, § 6).

- _Group 1._ A post preview in Agendum: a key in a post's note shows it as the site would draw it, read-only (meeting 2026-11-02-1954, § 13; not in round 2)
- _Group 1._ A view published as one web page: its sections, columns and sums drawn as the view looks, Agenda's Print current view on the web (the Journal's Gym log, for one; meeting 2026-11-02-2244, § 5)
- _Group 1._ Sorting and filtering in the site's templates (the owner, 2026-11-03): a list's items shown in another order, or only some of them, on a page; each a small, safe template syntax (logic-less no more), settled in a meeting first. A page only: the feeds and the newest N stay newest first by date
- _Group 1._ Sharing details for the blog: Open Graph and description meta tags, so a shared link shows a title and summary, and a `sitemap.xml` (meeting 2026-11-02-1954, § 13; not in round 2)
- _Group 1._ The project's whole site from a public Agendum file, built in CI by `mix agendum.publish` (the publisher's step 7 as the meeting planned it): the front page drawn from the site's own templates and assets, the devlog a feed; the devlog's posts then written in that public file. Left for later (the owner, 2026-11-02): the headless publish is built, the devlog stays published from the owner's own file
- _Group 1._ Export the blog's posts as Markdown with front matter (title, date, slug), for a third-party static site generator (Hugo, Zola, Eleventy) if one is ever wanted; parked, as Agendum keeps its own publisher (meeting 2026-11-02-1255, § 11)
- _Groups 1 and 2._ Attachments (meeting 2026-10-25-2252, § 5): files of any kind on an item or a category (an image that belongs to a note, the CV a note is about).

  - **Copied** into a folder beside the Agendum file as org-mode's attachments are, listed in the note, opened with the system's viewer (an effect, as CTRL-V opens a link).
  - **On the web,** uploads kept by the server.
  - **An attached file's text,** read by an agent, is data and never instructions.

  Agenda's external note files (left out of the clone) could be one case of it
- _Groups 1 and 2._ Multiple files open; a launcher listing recent files
- _Groups 2 and 3._ In-line help in boxes: the hint inside a box (made from its keys, `Box.hint/2`) as the start of a fuller help, with longer texts in a help box of their own (the owner's idea, 2026-10-14)
- _Group 1._ Wol in the machine (its memory: the context items of `plans/ITEM_LEVELS.md`): a personal agent (a language model) inside the file, using its items, categories, views and rules as the person's own meaning; it files, finds and plans by proposing, never silently changing; the core stays pure and privacy comes first. Builds on the command layer, and on the headless command and golden tasks (The extras, 3). Thoughts in [`docs/plans/WOL-IN-THE-MACHINE.md`](plans/WOL-IN-THE-MACHINE.md)
- _Group 3._ More date languages (one `Agendum.Core.DateLanguage` pack each); English and Swedish exist (R14c)
- _No group yet._ Flashcards with active recall and spaced repetition: an item is the question, its note the answer; a deck is any category.

  - **The schedule** is kept in ordinary categories made the first time (date category Due; numeric Interval, Ease and Reviews), so filters, datebooks, sorting and JSON work on cards as they are, with no new stored fields.
  - **A review mode** on the due items: the question, SPACE shows the note, then Again / Hard / Good / Easy sets the next Due date (one undo step per card).
  - **Scheduling** is SM-2 to begin with, in a pure core module with the clock passed in, behind an interface that FSRS could replace
- _Tooling, for every group (would move to Sharpen the saw)._ Try Argus (https://github.com/QuinnWilton/argus, MIT, v0.25 on 2026-10-26), a static analyser of compiled `.beam` files for OTP and concurrency bugs, without an LLM.

  Its default analyses (supervisors, GenServers, deadlocks, ETS) fit Agendum little, but its opt-in `exposure` (secrets visible to `inspect`), `unsafe_input` (atom exhaustion, unsafe deserialisation), `failure` (swallowed errors, unchecked results), `mailbox` (unhandled messages) and `races` (registered names) match kinds the slice reviews found by reading (2026-10-26).

  - **A trial first, without adopting it:** installed as an escript (`mix escript.install hex argus_beam`, so `mix.exs` does not change), run once with those analyses, every finding judged real, already fixed or noise.
  - **Adopted only if mostly real,** then as a dev-only tool run locally or nightly, not in `mix check` (fast tests, the owner), with an ADR.
  - **Cautions:** young, one maintainer, false positives expected; its first run downloads native engines of about 70 MB (or builds them with Rust)
