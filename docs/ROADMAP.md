# Roadmap

Small, testable increments: the open work, by area. Done work is the record in [`ROADMAP_DONE.md`](ROADMAP_DONE.md), by milestone: tick a box when its tests pass under `mix check`, and move it there. Rule numbers refer to `SPEC.md`; larger items have a plan in `docs/plans/` (see `docs/INDEX.md`). Open starts with "In order", the next few things across every area; then the areas in the order they are worked on (the freeze on Beyond Agenda, Ideas and Towards many users ended when the clone was declared done, 2026-10-26). The parity work lives in [`plans/AGENDA_PARITY.md`](plans/AGENDA_PARITY.md) § The steps, in its order. "Sharpen the saw" is the standing home for work on the tools, checks and ways of working that make later changes faster and safer.

## Open

**In order:** what comes next, across every area (the owner reorders it; details where each line points; every extra usable before the public repository, the owner, 2026-10-26):

1. A tidy pass with the SPEC sweep and the private markers (Housekeeping; meeting 2026-10-26-4, §§ 9, 13; meeting 2026-10-28-2, §§ 6–7)
2. The dry run of the public copy, as a script (Housekeeping; meeting 2026-10-28-2, § 11)
3. A practical meeting on the dry run's results: go or no-go, with the licence confirmed after a lawyer's check (`plans/GITHUB.md` § 7, step 7; ADR 0051) (Housekeeping; meeting 2026-10-28-2, § 11)
4. The public repository of the clone (Housekeeping; [`plans/GITHUB.md`](plans/GITHUB.md)): the clone was declared done on 2026-10-26 with v0.62.0 (meeting 2026-10-26-2, § 7)
5. The public site, with four doors (Housekeeping; meeting 2026-10-28-2, § 9)
6. Review the rest of the code locally, groups d to h (Sharpen the saw; `docs/CODE_REVIEW_SLICES.md` § The rest)
7. A meeting for brainstorming and general plans: clarity on the ideas, and whether an overarching strategy is needed; what comes after the public repository (users, a headless reader and golden tasks, the GTD starter, the gentler starter) is chosen there (meeting 2026-10-26-4, § 14, tabled)

The order of 1–5 is Marie the Wren's (the licence meeting, first in it, held as meeting 2026-10-28-3), at the chair's request (meeting 2026-10-28-2, § 13; the pseudonyms folded into the dry run by the chair's addendum): the licence before the dry run, as the licence and the contributors' terms go into the copy; the tidy pass and the markers in one sweep over the same documents; the dry run after the markers, so its leak test has something to check; the site after the repository, as Pages needs it public.

**The extras meet the guidelines** since v0.72.0 (2026-10-28): new extras and Wol may come again (meeting 2026-10-26-6, § 7; ADR 0049). Why: the extras were built before the clone's bar was raised and missed its catch-up, in robustness at the shell's edge and in the boxes' conventions (§ 5).

**No longer frozen** since the truthful clone was declared done (2026-10-26, v0.62.0): Beyond Agenda, Ideas and Towards many users are open again (meeting 2026-10-21, § 5; meeting 2026-10-25, § 7). The clone stays truthful: a new difference from Agenda passes ADR 0043's test or is an extra behind the Extras switch. The view cache still waits for slow answers in real use.

### Towards parity with Agenda (Milestone 2)

**Done:** the truthful clone was declared done on 2026-10-26 with v0.62.0 (meeting 2026-10-26-2, § 7); its leftovers and optional steps are in the areas below. **The ambition was:** Agendum as close to Agenda 2.0 as makes sense: the same screen, keys, menus and behaviour, apart from accepted enhancements and modifications. The parity work, its order and its details are in one place: [`docs/plans/AGENDA_PARITY.md`](plans/AGENDA_PARITY.md) § The steps (with how close Agendum is, and the two lists).

### Fixes and polish

- [ ] Idea, when it is felt (the owner, 2026-10-27): the person's own categories before a feed's or a calendar's in completion's matches (R32) in the other category fields (column and section heads, a column cell), where ingested ones are rightly offered (R75a: they head sections and filter views). Agenda's rule is every match in hierarchy order, an exact name first, and the Feeds family usually comes after the person's categories already, so wait until a feed's name is seen crowding one's own in real use
- [ ] The extras' answers handled beside them (2026-10-27, found moving their messages): `Update.Results` (a feed's and calendar's read, an OPML list, an upload) and `Update.Prompts` (subscribing, unsubscribing, the SFTP password) still hold the extras' logic, listed as doors in `architecture_test.exs`; move each into a module beside its extra, so the shared modules only dispatch (the owner's modularity, 2026-10-27)
- [ ] Key hints made from the keys in three of the clone's boxes (UI guidelines rule 6.2; found by `box_guidelines_test.exs`, 2026-10-27): the macro manager, the category picker and the file list (`select_file.ex`) write their hint lines by hand; make them with `Box.hint/2` from their keys, as the clone's other boxes, and take each off the test's list
- [ ] Optional (the owner, 2026-10-27): try v0.69.3's main fix by hand: open a second file while a feed is being read, and see its entries land only in the file that asked (the richer fuzz walks already check it)
- [ ] Found by the richer fuzz walks (2026-10-27, v0.69.3): ESC on the Publish preview while an upload runs says "Nothing was published", which is untrue; and a feed or calendar whose address changed while a read was under way would wait for ever, as a stale answer no longer clears it (nothing changes an address in place today)
- [ ] Found by the parser property tests (2026-10-27, v0.69.2), not urgent: Markdown with thousands of nested `>` quotes is still quadratic (20,000 levels about 1 s); a calendar's sync costs about 1 ms an event (a 2,000-event calendar about 2 s, linear) — check whether it runs in the TUI's process and would freeze the screen
- [ ] Hidden values of a date or numeric category (owner, 2026-10-25): a category made date or numeric keeps its short name, Also match words and conditions, as Agenda does, but its box no longer shows them (R6a). Decide what to do with them: show them somewhere (Statistics, the manager), clear them on conversion, or leave them; check first whether any still has an effect (a short name in a narrow column head, a condition)

### The clone's safety

**Done** (2026-10-26): the closed effect type, the recovery file on a crash (R82b) and the hostile-text tests (R82c), in `ROADMAP_DONE.md`; nothing open


### Sharpen the saw

Tools and checks that make every later change faster and safer. Each is small; the command layer they made safer is done (R66, ADR 0036, in `ROADMAP_DONE.md`). From the expert review of 2026-10-16 (`docs/reviews/2026-10-16.md`) and the performance items found earlier.

- [ ] Kept fast (the owner, 2026-10-26: "I don't want it to take up very much time"): the four items above add at most about 5 seconds to `mix check` (a few dozen inputs per parser, the hostile files, short richer and out-of-order walks); the long runs go to `mix agendum.fuzz` and the nightly CI. Measure `mix check` before and after
- [ ] Review the rest of the code locally (`docs/CODE_REVIEW_SLICES.md` § The rest): about 35,000 lines in five groups, each with `/code-review high <paths>`, its findings fixed as a release of its own, as the cloud slices were
- [ ] A view cache, when the evidence asks for it: every key rebuilds the whole view (each item's cells, and every item's text wrapped for the screen, not only the rows shown), about three times per key. Measured 2026-10-16, a cursor move: 300 items 6 ms in `Update` + 11 ms in `Render`; 3,000 items 61 + 45 ms; 10,000 items 205 + 231 ms. First build it once per key and share it; then keep it in the session's state between keys as a value with a key that says when it is stale (ADR 0035): the database, the view, the date and time, the screen width, collapsed families, the search. Needs an ADR. **Wait until the debug log shows `slow answer` lines (over 100 ms) in real use** (owner's decision, 2026-10-16); ingested items (`plans/ITEM_LEVELS.md`) will likely be what brings them. Update 2026-10-25 (v0.31.2): the first real-use slowness came from many sections, not many items (the owner's News view, 243 sections: ~135 ms a key); fixed without a cache (`ROADMAP_DONE.md`, Sharpen the saw), and wrapping and drawing now touch only the rows down to the highlight and on screen. Left: the view is still made about three times per key, so "build it once per key" is the next step if it is slow again. The command layer, which reshaped the state it would live in, is done; the TUI state's split into file and session (Towards many users) reshapes it again

### The note editor

Agenda's note editor is done (AGENDA_PARITY.md); these are ours, or optional:

- [ ] Optional (from the parity plan, 2026-10-26): ALT-F1 COMPOSE, Agenda's way of typing accented and special characters by two keys

- [ ] Undo in the note editor: CTRL-Z / CTRL-Y while editing a note, for typing (in sensible chunks: a word or a line, not every key) and for Search/Replace's replacements, with the note's text and cursor restored in the editor; the steps join the file's history when the note closes (today undo works only after closing the note, ADR 0005)

### Data interchange (Milestone 4)

- [ ] Optional (from the parity plan, 2026-10-26): Agenda structured files (`.STF`), import and export as Agenda 2.0's File Transfer does (Working with Definition Files, Appendix B; User's Guide chapters 23–24), reading both 2.0 and 1.x dates into the same When, Entry and Done categories
- [ ] Optional (from the parity plan, 2026-10-26): import of structured text files, one item per line with categories
- [ ] Optional, with STF (2026-10-26): File Properties ▸ Auto-import file, Agenda's structured file imported each time the file is opened (to check in Agenda first)
- [ ] Optional (from the parity plan, 2026-10-26): TXT2STF-style definition files that turn plain text into items; a first use, the session summaries in `docs/summaries/`
- [ ] The `.AG` import (R72), still to bring over: note files (read by the shell beside the `.AG`), the global date format, a datebook's base date
  - [ ] Macros. Every macro in the files at hand is a starter's helper program in Agenda's macro command language (`{INPUTTEXT;…}`, `{DEFSTR;%var}`, `{LABEL}`, `{WINDOWSON}`), not recorded keystrokes, so R50 cannot run them; the owner's own Planner has only Planner's 10 (contact list, date settings, hide done, print, four sorts), none of the owner's. Planner, Account Manager, People Manager and Information Sifter have 10, 14, 10 and 6 (checked 2026-10-16). Options when picked up: import plain keystroke macros as R50 macros, and keep each other macro's text in a note so it can still be read; the command language itself stays out of scope (SPEC § 6)

### Time management (Milestone 5)

- [ ] Alarms sent to your phone with Signal, as well as on the screen: through the separate `signal-cli` program, linked to your Signal account; optional (nothing changes without it), set up in File ▸ Customize

### Housekeeping

- [ ] The licence confirmed before publishing (meeting 2026-10-28-3, §§ 6–8; ADR 0051; `plans/GITHUB.md` § 7, step 7): a lawyer where the owner lives checks AGPL-3.0-only for the code, CC BY 4.0 for the documents and the CLA's model text (and whether it allows a commercial licence beside the AGPL); then the owner confirms it, and `LICENSE`, the SPDX lines, the documents' licence and `CONTRIBUTING.md` with the CLA go into the public copy
- [ ] Before the public repository (meeting 2026-10-26-4, §§ 9, 11, 13; meeting 2026-10-28-2, §§ 6–7, 11), in this order: a general code review (done 2026-10-26: three cloud slices, `docs/CODE_REVIEW_SLICES.md`; the rest locally after the public repository); the meeting on what to make public (done, `ROADMAP_DONE.md`); a tidy pass (`tidy-docs`: VISION's freeze paragraph, AGENDA_PARITY's "three differences" and their cousins) with a sweep of SPEC, each rule keeping a short "(checked in Agenda)" or "Our choice" and its longer story moved to `ROADMAP_DONE.md`, and in the same sweep the private passages of public documents marked `<!-- private -->` … `<!-- /private -->` or moved into private files (`plans/GITHUB.md` § 7, the list); then the dry run as a re-runnable script in `tools/public/` (the owner's preferred way, 2026-10-28, confirmed at the practical meeting: run once for real, as after the first publish the public repository is the main one and the private documents move to a private repository that imports the core, so nothing is synced; alternatives in `plans/GITHUB.md` § 7): the `git filter-repo` copy built, the markers replaced by the creek note, the panel's real names mapped to their pseudonyms in every file and commit message (`--replace-text`, `--replace-message`) from a private name list in `tools/public/` (meeting 2026-10-28-2, § 10 and its addendum), checked by `mix check`, a leak test (no private file, marker, business word, real name or surname left; a few converted minutes read to see the sentences still work) and a check that every cited commit hash exists in the copy; then a practical meeting on its results
- [ ] The name's story and how it is said (meeting 2026-10-28-4, § 5; ADR 0019, update 2026-10-28): one line, "Wol is how Owl spells his name", and "said wolz a-JEN-dum", where the name first meets a reader: the About help topic (`lib/agendum/tui/help/topics/about-agendum.txt`, built with the `feature` skill), the README in the tidy pass, and the site
- [ ] The public site, after the public repository (meeting 2026-10-28-2, § 9): one static page with four doors, Try it (install), Learn it (the guide, the manual), Look inside (the API and design docs, the ADRs), Follow it (the owner's devlog), and a short recording of typing an item and seeing it filed; the docs on GitHub Pages; an `llms.txt` made from `docs/INDEX.md`; downloads from GitHub Releases and a Homebrew tap first, bundled binaries (Burrito-style) later if people ask. The devlog is the owner's own words, published with Agendum's blog extra, backfilled as milestone posts (the summaries only jog the memory; they stay private)
- [ ] Optional (from the parity plan, 2026-10-26): Utilities ▸ Launch, a shell without quitting Agendum
*[A page here was soaked in the creek. — Rabbit]*

### Users and direction

- [ ] A meeting for brainstorming and general plans, after the public repository (meeting 2026-10-26-4, § 14, tabled): the owner, 2026-10-26: "we are entering a period of brainstorming and making general plans on ideas now", with coding too; clarity on the ideas, and whether an overarching strategy is needed. The panel's four directions for after the public repository go there: looking for users (Mitch), a read-only headless command and golden tasks (Claude), the GTD starter (David), the gentler starter (Russell)
- [ ] Real users, when there are any: old Agenda users and people who love keyboard tools, with the debug log on (`AGENDUM_LOG`) and a short talk with each; what they stumble on goes here (expert review 2026-10-16). Not a condition for declaring the clone done, and no search for old Agenda users now: the owner knows none (meeting 2026-10-22, § 5a and § 5e)

### Towards many users

Open again since the truthful clone was declared done (2026-10-26; meeting 2026-10-21, § 5; meeting 2026-10-22, § 5i).

*[A page here was soaked in the creek. — Rabbit]*

Then a web version for one person:

*[A page here was soaked in the creek. — Rabbit]*

Then working together:

*[A page here was soaked in the creek. — Rabbit]*

### Beyond Agenda

- [ ] Later (the owner, 2026-10-26, after v0.66.0): shrink the faded feed entries further: a hashed entry id instead of the full guid or link (often a web address), and the publish date as a day number instead of a `Date` struct; the 13,181 faded entries are most of the feeds' 2.7 MB as a term in the owner's file (the file 1.21 MB on disk). A format change; not urgent, the save is 39 ms
Open again since the clone was declared done (2026-10-26); the built ones stay hidden behind the Extras preference (ADR 0043).

Each item names the group in `VISION.md` it serves, group 1 first; items for group 3 or for no group yet wait under Ideas, one line each with a pointer to their plan (meeting 2026-10-16-2, § 6).

- [ ] _Group 1._ The date filter's "or not assigned" (meeting 2026-10-28, § 6; [`plans/STARTERS.md`](plans/STARTERS.md)): a Date Filter can show the items without a date as well as those in its range, so a view filtered on Start up to today also shows items with no Start ("not active until", Things' start date, GTD's tickler). Agenda's filter has Assigned and Not assigned apart (User's Guide 11-6), so it is an extra behind the Extras switch (ADR 0043), in the clone's Date Filter box's patterns (ADR 0049)
- [ ] Later, Beyond Agenda (the chair, meeting 2026-10-26-6, §§ 6, 8): settings as views, e.g. the feeds and calendars as a view of their own, one row per subscription with columns for address, how often, days kept, last read; a window onto the typed structs, never a second copy (ADR 0048). Not while the work is the truthful clone with robust extras: then only existing patterns
- [ ] _Group 1._ The extras' commands that fetch or publish move from File ▸ Transfer to **Utilities** (the owner, 2026-10-24, after Utilities came back in Agenda's shape, R81a): Calendars, Feeds and Publish are things to do with the file, not ways to bring a file in or out, so they fit beside Customize, Execute and Show better than beside Import and Export. With the Extras preference off nothing changes (they are hidden, R77); with it on, Agenda's Utilities gains them after its own entries, so its first letters (C, E, S, Q) stay as Agenda's and the new ones need letters of their own (Calendars clashes with Customize: to settle). The menu test compares the menus with the extras off, so it stays as it is; the help texts (`Agendum.TUI.CommandDocs`, `~w(File Transfer Calendars)` …) and SPEC R45, R74, R75 move with them. File ▸ Transfer keeps Import and Export, and the OPML Import when the extras thaw (meeting 2026-10-22-3, § 7)
- [ ] _Group 1._ An RSS reader, with Wol later (meeting 2026-10-16-2, § 7), fetched by the shell like calendars (`Agendum.Extras.CalendarFetch`; OTP's `:httpc` and `:xmerl`, no new dependency). In two steps:
  - [x] Built 2026-10-17 (R75, v0.13.0), approved by the owner 2026-10-17 after trying it (v0.13.0 tagged): a plain reader (plan: [`plans/RSS_READER.md`](plans/RSS_READER.md), settled with the owner 2026-10-17): feed entries become ingested items (level 2, `plans/ITEM_LEVELS.md`), filed by Agenda's own conditions as typed items are; the feed list imports and exports OPML; no unread counts: an entry never asks to be dealt with, keeping one is a choice, letting it go costs nothing
  - Dropped (the owner, 2026-10-27): OPML through File ▸ Transfer ▸ Import; the Feeds manager keeps it (F7 and F8), so the menus have no hole with the Extras off
  - Whether feed entries should be read-only was referred to `plans/ITEM_LEVELS.md` (meeting 2026-10-22-3, § 6), as part of what an ingested item is
  - [ ] Wol's part (summaries, sifting, suggestions; `plans/WOL-IN-THE-MACHINE.md`), only after its principle 6 (feed text is data, never instructions) and the golden tasks with hostile feed text. Which model is for the Wol plan. The owner's notes on the design are on the next agenda, below its line
- [ ] _Group 1._ Calendar subscriptions (R45, an extra): repeating events in a calendar from another time zone: each occurrence converted in its own zone, so the weeks between the two zones' summer-time changes are not an hour off (SPEC R45)
- [ ] _Group 1._ Three levels of items (vision, the owner's, 2026-10-16; plan with open questions: [`plans/ITEM_LEVELS.md`](plans/ITEM_LEVELS.md)): zettels (the person's items, with Zettelkasten IDs), ingested items (calendar events, RSS entries …: promoted to zettels or discarded by rules) and context items (made by the language model to understand the information; inspected, not edited). The JSON export asks which levels to include, as Agenda's STF export chooses what goes in (ADR 0034). Volumes can be large
  - [ ] Settle the open questions with the owner before building (`plans/ITEM_LEVELS.md`, "Open questions"): how a level is stored (a field, or derived: a zettel is an item with an ID); what views show by default and how a view asks for levels 2 and 3; whether text matching and conditions run on ingested items or only once promoted; where the rules for ingested items live (Agenda's conditions and actions, or rules of their own) and how long discarded items are kept; how context items refer to what they are about and what happens when that changes or goes; whether ingestion and context items are undo steps
  - [ ] RSS and other feeds as sources of ingested items: the RSS reader above (calendar events, R45, become ingested items too)
  - [ ] Rules for ingested items: keep, promote to a zettel, discard
  - [ ] The JSON export (R44) with a choice of levels; an import of a partial export says so
- [ ] _Group 1._ Zettel ids, a better feel (the owner tried them 2026-10-17 and approved them, v0.11.0: "the UX is a bit weak but it works"). Ask the owner what felt weak before building; what is known so far:
  - [ ] A Zettel id column without a head (R73a): with Format Zettel id the head is not used (the column shows each item's id under "Zettel id" whatever the head), yet Column Add asks for one first. Let Format come first, or let the head stay empty for this format, so no category has to be picked or made. A habit change only for this format; Agenda has no such column (AGENDA_PARITY, enhancements)
- [ ] _Group 1 (where an item came from), and 3 (who changed it, permissions)._ More about each item (metadata): when it was last modified and by whom, who may see or change it (permissions), where it was made (geo-tagging), where it came from (typed, ingested from a source, proposed by Wol: the provenance principle 6 of the Wol plan asks for), and so on. Of such metadata an item has only its Entry date today (`Agendum.Core.Item`). Serves many users (who changed what, sharing), the item levels and Wol. How it is stored and shown (fields of their own, Agenda-style special categories as Entry is, columns, conditions on it) is decided later, with an ADR (the owner's wish, 2026-10-16)
- [ ] _Groups 1 and 2._ Capture from outside (paused, owner 2026-10-16): the owner would rather capture through a URL scheme (such as `agendum://add?text=…`, which a phone, a browser or another program can open) than a shell command, `agendum add "text" FILE`; to be designed when picked up. Filed by the core as if typed in the view (the command `{:add_item, …}`), saying where it was filed; later a mail or phone path (expert review 2026-10-16). The first door without a keyboard, and an agent's first tool (second meeting); the guard it needs first is the first item above
- [ ] _Group 2._ A GTD starter, like the Planner (R60, ADR 0028): Inbox, Next Actions by context, Projects, Waiting For, Someday/Maybe, and views for a weekly review (items untouched for a while, projects without a next action), so the rules show what they can do in a method many people know (expert review 2026-10-16) Its sketch, and six other systems', are in [`plans/STARTERS.md`](plans/STARTERS.md) (meeting 2026-10-28)

### Ideas

Open again since the clone was declared done (2026-10-26); an idea moves up when the owner chooses it.

Each names the group in `VISION.md` it serves; an idea moves up to "Beyond Agenda" when it serves group 1 or 2 now (meeting 2026-10-16-2, § 6).

- _Groups 1 and 2._ Attachments (meeting 2026-10-25, § 5): files of any kind on an item or a category (an image that belongs to a note, the CV a note is about), copied into a folder beside the Agendum file as org-mode's attachments are, listed in the note, opened with the system's viewer (an effect, as CTRL-V opens a link); uploads kept by the server on the web; an attached file's text, read by an agent, is data and never instructions. Agenda's external note files (left out of the clone) could be one case of it
- _Groups 1 and 2._ Multiple files open; a launcher listing recent files
- _Groups 2 and 3._ In-line help in boxes: the hint inside a box (made from its keys, `Box.hint/2`) as the start of a fuller help, with longer texts in a help box of their own (the owner's idea, 2026-10-14)
- _Group 1._ Wol in the machine (its memory: the context items of `plans/ITEM_LEVELS.md`): a personal agent (a language model) inside the file, using its items, categories, views and rules as the person's own meaning; it files, finds and plans by proposing, never silently changing; the core stays pure and privacy comes first. Builds on the command layer (Towards many users). Thoughts in [`docs/plans/WOL-IN-THE-MACHINE.md`](plans/WOL-IN-THE-MACHINE.md)
- _Group 1._ Before Wol, without a model: golden tasks (a few small files, a request each, and the commands a good answer proposes), which also test the command layer's design (expert review 2026-10-16, second meeting, `docs/reviews/2026-10-16-2.md`). The sixth principle it asked for, item text is data and never instructions, is in the Wol plan
- _Group 3._ Modern by default: today's names and standard keys out of the box (Open not Retrieve, Delete not Discard, CTRL-O/S/Z/F/N…), with Agenda's names and keys one setting away ("Agenda mode"). Agenda's steep learning curve limited its audience (AGENDA_HISTORY.md); the power should stay, the strangeness should not be the first thing people meet. Builds on the keymaps, self-describing commands and own key bindings (Towards many users); departs from ADR 0006 and 0007, so it needs an ADR of its own. Since ADR 0038 (2026-10-16) this is for the web's modern interface: the terminal program keeps Agenda's names and keys. In the terminal, later and as an extra: a modern key set as a setting in the same program, File ▸ Customize ▸ Keys: Agenda (default) or Modern, not a second program (meeting 2026-10-22, § 6; ADR 0038)
- _Group 3._ A starter for the easily overwhelmed, with a gentler "Overdue" (fewer at a time, kinder words) than the Planner's (`lib/agendum/starters/planner/views.ex:73`), which stays as Agenda's PLANNER (expert review 2026-10-21, § 17; meeting 2026-10-22, § 5k) See [`plans/STARTERS.md`](plans/STARTERS.md) (the three-days-away test, the mood tracker)
- _Group 3._ More date languages (one `Agendum.Core.DateLanguage` pack each); English and Swedish exist (R14c)
- _No group yet._ Flashcards with active recall and spaced repetition: an item is the question, its note the answer; a deck is any category. The schedule is kept in ordinary categories made the first time (date category Due; numeric Interval, Ease and Reviews), so filters, datebooks, sorting and JSON work on cards as they are, with no new stored fields. A review mode on the due items: the question, SPACE shows the note, then Again / Hard / Good / Easy sets the next Due date (one undo step per card). Scheduling is SM-2 to begin with, in a pure core module with the clock passed in, behind an interface that FSRS could replace
- _Tooling, for every group (would move to Sharpen the saw)._ Try Argus (https://github.com/QuinnWilton/argus, MIT, v0.25 on 2026-10-26), a static analyser of compiled `.beam` files for OTP and concurrency bugs, without an LLM. Its default analyses (supervisors, GenServers, deadlocks, ETS) fit Agendum little, but its opt-in `exposure` (secrets visible to `inspect`), `unsafe_input` (atom exhaustion, unsafe deserialisation), `failure` (swallowed errors, unchecked results), `mailbox` (unhandled messages) and `races` (registered names) match kinds the slice reviews found by reading (2026-10-26). A trial first, without adopting it: installed as an escript (`mix escript.install hex argus_beam`, so `mix.exs` does not change), run once with those analyses, every finding judged real, already fixed or noise; adopted only if mostly real, then as a dev-only tool run locally or nightly, not in `mix check` (fast tests, the owner), with an ADR. Cautions: young, one maintainer, false positives expected; its first run downloads native engines of about 70 MB (or builds them with Rust)

