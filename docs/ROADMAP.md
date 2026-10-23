# Roadmap

Small, testable increments: the open work, by area. Done work is the record in [`ROADMAP_DONE.md`](ROADMAP_DONE.md), by milestone: tick a box when its tests pass under `mix check`, and move it there. Rule numbers refer to `SPEC.md`; larger items have a plan in `docs/plans/` (see `docs/INDEX.md`). Open starts with "In order", the next few things across every area; then the areas in the order they are worked on, the frozen ones last. The parity work lives in [`plans/AGENDA_PARITY.md`](plans/AGENDA_PARITY.md) § The steps, in its order. "Sharpen the saw" is the standing home for work on the tools, checks and ways of working that make later changes faster and safer.

## Open

**In order:** what comes next, across every area (the owner reorders it; details where each line points):

1. View Properties ▸ Number items (parity, [`AGENDA_PARITY.md`](plans/AGENDA_PARITY.md) § The steps)
2. The key bar at 80 columns (Fixes and polish, below)
3. The shortcut entries leave the menus (parity; a habit change, settled first)
4. Recurring items on every date they recur (parity; `RECURRING_OCCURRENCES.md`)
5. A closed effect type in `App` (The clone's safety, below)
6. Then the parity steps in their order ([`AGENDA_PARITY.md`](plans/AGENDA_PARITY.md) § The steps), with the rest of the clone's safety between them

**Frozen until the truthful clone is declared done** (meeting 2026-10-21, § 5; `VISION.md`, ADR 0043): Beyond Agenda, Ideas and Towards many users wait (bug fixes only). Not frozen: the parity steps, the clone's safety work and tests (meeting 2026-10-22, § 5c) and Sharpen the saw (§ 5i). The view cache waits for slow answers in real use.

### Towards parity with Agenda (Milestone 2)

**The ambition:** Agendum as close to Agenda 2.0 as makes sense: the same screen, keys, menus and behaviour, apart from accepted enhancements and modifications. The parity work, its order and its details are in one place: [`docs/plans/AGENDA_PARITY.md`](plans/AGENDA_PARITY.md) § The steps (with how close Agendum is, and the two lists).

### Fixes and polish

- [ ] The key bar at 80 columns: boxes with many keys (Section Properties, View Properties) run past the screen's width and are cut mid-word ("ENTER Do"); drop whole entries that do not fit, ENTER and ESC first (the box's bottom edge names them), as the hint inside the box already does (found 2026-10-23)

### The clone's safety

Clone work, not frozen (meeting 2026-10-22, § 5c; expert review 2026-10-21, § 8 and § 14):

- [ ] A closed effect type, with a last clause in `App.run_effects/2` (`lib/agendum/tui/app.ex:209-309`) for an effect it does not know, so an unknown effect is logged rather than a crash (the crash of 2026-10-17, `a0612f9`)
- [ ] A recovery file on a crash: the unsaved file written beside it, and offered when it is next opened
- [ ] Hostile-text tests: a `.AG` file (and a feed) whose item text asks for changes imports as plain items, and only its own

### Sharpen the saw

Tools and checks that make every later change faster and safer. Each is small; the command layer they made safer is done (R66, ADR 0036, in `ROADMAP_DONE.md`). From the expert review of 2026-10-16 (`docs/reviews/2026-10-16.md`) and the performance items found earlier.

- [ ] A view cache, when the evidence asks for it: every key rebuilds the whole view (each item's cells, and every item's text wrapped for the screen, not only the rows shown), about three times per key. Measured 2026-10-16, a cursor move: 300 items 6 ms in `Update` + 11 ms in `Render`; 3,000 items 61 + 45 ms; 10,000 items 205 + 231 ms. First build it once per key and share it; then keep it in the session's state between keys as a value with a key that says when it is stale (ADR 0035): the database, the view, the date and time, the screen width, collapsed families, the search. Needs an ADR. **Wait until the debug log shows `slow answer` lines (over 100 ms) in real use** (owner's decision, 2026-10-16); ingested items (`plans/ITEM_LEVELS.md`) will likely be what brings them. The command layer, which reshaped the state it would live in, is done; the TUI state's split into file and session (Towards many users) reshapes it again

### The note editor

Agenda's note editor is parity work (AGENDA_PARITY.md § The steps); this one is ours:

- [ ] Undo in the note editor: CTRL-Z / CTRL-Y while editing a note, for typing (in sensible chunks: a word or a line, not every key) and for Search/Replace's replacements, with the note's text and cursor restored in the editor; the steps join the file's history when the note closes (today undo works only after closing the note, ADR 0005)

### Data interchange (Milestone 4)

- [ ] Repeating events in a calendar from another time zone: each occurrence converted in its own zone, so the weeks between the two zones' summer-time changes are not an hour off (SPEC R45)
- [ ] Optional: read original `.AG` files directly. The format is now largely known (`docs/AGENDA_FILE_FORMAT.md`; research log `docs/plans/archive/AGENDA_FILE_FORMAT_LOG.md`; reference reader `tools/agformat/agdump.py`): items, notes and note files, categories with all their settings, conditions and actions, assignments with values, relative and recurring dates, alarms, views with sorting and filters, datebooks, sections, columns with formats, file settings
  - [x] Reverse engineer the format: container, items, categories, values, views (2026-10-14)
  - [x] Settle the open parts: view/section sort and filter words, relative-date encoding, actions, settings (2026-10-15, second round; how to drive Agenda: `tools/agformat/DRIVING_AGENDA.md`)
  - [x] An Elixir reader and conversion (pure, `Agendum.Core.AgFile`, through the JSON format's checks); File ▸ Transfer ▸ Import of a `.AG` and `agendum OLD.AG`, with a password and a report of what came over (R72, 2026-10-16)
  - [ ] Still to bring over: note files (read by the shell beside the `.AG`), the global date format, a datebook's base date
  - [ ] Macros. Every macro in the files at hand is a starter's helper program in Agenda's macro command language (`{INPUTTEXT;…}`, `{DEFSTR;%var}`, `{LABEL}`, `{WINDOWSON}`), not recorded keystrokes, so R50 cannot run them; the owner's own Planner has only Planner's 10 (contact list, date settings, hide done, print, four sorts), none of the owner's. Planner, Account Manager, People Manager and Information Sifter have 10, 14, 10 and 6 (checked 2026-10-16). Options when picked up: import plain keystroke macros as R50 macros, and keep each other macro's text in a note so it can still be read; the command language itself stays out of scope (SPEC § 6)

### Time management (Milestone 5)

- [ ] Alarms sent to your phone with Signal, as well as on the screen: through the separate `signal-cli` program, linked to your Signal account; optional (nothing changes without it), set up in File ▸ Customize

### Housekeeping

*[A page here was soaked in the creek. — Rabbit]*

### Users and direction

- [ ] Real users, when there are any: old Agenda users and people who love keyboard tools, with the debug log on (`AGENDUM_LOG`) and a short talk with each; what they stumble on goes here (expert review 2026-10-16). Not a condition for declaring the clone done, and no search for old Agenda users now: the owner knows none (meeting 2026-10-22, § 5a and § 5e)

### Towards many users

**Waits until the truthful clone is declared done** (meeting 2026-10-21, § 5; meeting 2026-10-22, § 5i).

*[A page here was soaked in the creek. — Rabbit]*

Then a web version for one person:

*[A page here was soaked in the creek. — Rabbit]*

Then working together:

*[A page here was soaked in the creek. — Rabbit]*

### Beyond Agenda

**Frozen to bug fixes until the truthful clone is declared done** (meeting 2026-10-21, § 5); the items below wait, and the built ones are hidden behind the Extras preference (ADR 0043).

Each item names the group in `VISION.md` it serves, group 1 first; items for group 3 or for no group yet wait under Ideas, one line each with a pointer to their plan (meeting 2026-10-16-2, § 6).

- [ ] *Group 1.* An RSS reader, with Wol later (meeting 2026-10-16-2, § 7), fetched by the shell like calendars (`Agendum.Extras.CalendarFetch`; OTP's `:httpc` and `:xmerl`, no new dependency). In two steps:
  - [x] Built 2026-10-17 (R75, v0.13.0), approved by the owner 2026-10-17 after trying it (v0.13.0 tagged): a plain reader (plan: [`plans/RSS_READER.md`](plans/RSS_READER.md), settled with the owner 2026-10-17): feed entries become ingested items (level 2, `plans/ITEM_LEVELS.md`), filed by Agenda's own conditions as typed items are; the feed list imports and exports OPML; no unread counts: an entry never asks to be dealt with, keeping one is a choice, letting it go costs nothing
  - [ ] When the extras thaw (meeting 2026-10-22-3, § 7): File ▸ Transfer ▸ Import takes an `.opml` feed list too, chosen by its extension as a `.AG` is
  - Whether feed entries should be read-only was referred to `plans/ITEM_LEVELS.md` (meeting 2026-10-22-3, § 6), as part of what an ingested item is
  - [ ] Wol's part (summaries, sifting, suggestions; `plans/WOL-IN-THE-MACHINE.md`), only after its principle 6 (feed text is data, never instructions) and the golden tasks with hostile feed text. Which model is for the Wol plan. The owner's notes on the design are on the next agenda, below its line
- [ ] *Group 1.* Three levels of items (vision, the owner's, 2026-10-16; plan with open questions: [`plans/ITEM_LEVELS.md`](plans/ITEM_LEVELS.md)): zettels (the person's items, with Zettelkasten IDs), ingested items (calendar events, RSS entries …: promoted to zettels or discarded by rules) and context items (made by the language model to understand the information; inspected, not edited). The JSON export asks which levels to include, as Agenda's STF export chooses what goes in (ADR 0034). Volumes can be large
  - [ ] Settle the open questions with the owner before building (`plans/ITEM_LEVELS.md`, "Open questions"): how a level is stored (a field, or derived: a zettel is an item with an ID); what views show by default and how a view asks for levels 2 and 3; whether text matching and conditions run on ingested items or only once promoted; where the rules for ingested items live (Agenda's conditions and actions, or rules of their own) and how long discarded items are kept; how context items refer to what they are about and what happens when that changes or goes; whether ingestion and context items are undo steps
  - [ ] RSS and other feeds as sources of ingested items: the RSS reader above (calendar events, R45, become ingested items too)
  - [ ] Rules for ingested items: keep, promote to a zettel, discard
  - [ ] The JSON export (R44) with a choice of levels; an import of a partial export says so
- [ ] *Group 1.* Zettel ids, a better feel (the owner tried them 2026-10-17 and approved them, v0.11.0: "the UX is a bit weak but it works"). Ask the owner what felt weak before building; what is known so far:
  - [ ] A Zettel id column without a head (R73a): with Format Zettel id the head is not used (the column shows each item's id under "Zettel id" whatever the head), yet Column Add asks for one first. Let Format come first, or let the head stay empty for this format, so no category has to be picked or made. A habit change only for this format; Agenda has no such column (AGENDA_PARITY, enhancements)
- [ ] *Group 1 (where an item came from), and 3 (who changed it, permissions).* More about each item (metadata): when it was last modified and by whom, who may see or change it (permissions), where it was made (geo-tagging), where it came from (typed, ingested from a source, proposed by Wol: the provenance principle 6 of the Wol plan asks for), and so on. Of such metadata an item has only its Entry date today (`Agendum.Core.Item`). Serves many users (who changed what, sharing), the item levels and Wol. How it is stored and shown (fields of their own, Agenda-style special categories as Entry is, columns, conditions on it) is decided later, with an ADR (the owner's wish, 2026-10-16)
- [ ] *Groups 1 and 2.* Capture from outside (paused, owner 2026-10-16): the owner would rather capture through a URL scheme (such as `agendum://add?text=…`, which a phone, a browser or another program can open) than a shell command, `agendum add "text" FILE`; to be designed when picked up. Filed by the core as if typed in the view (the command `{:add_item, …}`), saying where it was filed; later a mail or phone path (expert review 2026-10-16). The first door without a keyboard, and an agent's first tool (second meeting); the guard it needs first is the first item above
- [ ] *Group 2.* A GTD starter, like the Planner (R60, ADR 0028): Inbox, Next Actions by context, Projects, Waiting For, Someday/Maybe, and views for a weekly review (items untouched for a while, projects without a next action), so the rules show what they can do in a method many people know (expert review 2026-10-16)

### Ideas

**Frozen until the truthful clone is declared done** (meeting 2026-10-21, § 5; meeting 2026-10-22, § 5i): ideas wait here; none moves up before then.

Each names the group in `VISION.md` it serves; an idea moves up to "Beyond Agenda" when it serves group 1 or 2 now (meeting 2026-10-16-2, § 6).

- *Groups 1 and 2.* Multiple files open; a launcher listing recent files
- *Groups 2 and 3.* In-line help in boxes: the hint inside a box (made from its keys, `Box.hint/2`) as the start of a fuller help, with longer texts in a help box of their own (the owner's idea, 2026-10-14)
- *Group 1.* Wol in the machine (its memory: the context items of `plans/ITEM_LEVELS.md`): a personal agent (a language model) inside the file, using its items, categories, views and rules as the person's own meaning; it files, finds and plans by proposing, never silently changing; the core stays pure and privacy comes first. Builds on the command layer (Towards many users). Thoughts in [`docs/plans/WOL-IN-THE-MACHINE.md`](plans/WOL-IN-THE-MACHINE.md)
- *Group 1.* Before Wol, without a model: golden tasks (a few small files, a request each, and the commands a good answer proposes), which also test the command layer's design (expert review 2026-10-16, second meeting, `docs/reviews/2026-10-16-2.md`). The sixth principle it asked for, item text is data and never instructions, is in the Wol plan
- *Group 3.* Modern by default: today's names and standard keys out of the box (Open not Retrieve, Delete not Discard, CTRL-O/S/Z/F/N…), with Agenda's names and keys one setting away ("Agenda mode"). Agenda's steep learning curve limited its audience (AGENDA_HISTORY.md); the power should stay, the strangeness should not be the first thing people meet. Builds on the keymaps, self-describing commands and own key bindings (Towards many users); departs from ADR 0006 and 0007, so it needs an ADR of its own. Since ADR 0038 (2026-10-16) this is for the web's modern interface: the terminal program keeps Agenda's names and keys. In the terminal, later and as an extra: a modern key set as a setting in the same program, File ▸ Customize ▸ Keys: Agenda (default) or Modern, not a second program (meeting 2026-10-22, § 6; ADR 0038)
- *Group 3.* A starter for the easily overwhelmed, with a gentler "Overdue" (fewer at a time, kinder words) than the Planner's (`lib/agendum/starters/planner/views.ex:73`), which stays as Agenda's PLANNER (expert review 2026-10-21, § 17; meeting 2026-10-22, § 5k)
- *Group 3.* More date languages (one `Agendum.Core.DateLanguage` pack each); English and Swedish exist (R14c)
- *No group yet.* Flashcards with active recall and spaced repetition: an item is the question, its note the answer; a deck is any category. The schedule is kept in ordinary categories made the first time (date category Due; numeric Interval, Ease and Reviews), so filters, datebooks, sorting and JSON work on cards as they are, with no new stored fields. A review mode on the due items: the question, SPACE shows the note, then Again / Hard / Good / Easy sets the next Due date (one undo step per card). Scheduling is SM-2 to begin with, in a pure core module with the clock passed in, behind an interface that FSRS could replace
