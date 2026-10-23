# Roadmap

Small, testable increments: the open work, by area. Done work is the record in [`ROADMAP_DONE.md`](ROADMAP_DONE.md), by milestone: tick a box when its tests pass under `mix check`, and move it there. Rule numbers refer to `SPEC.md`; larger items have a plan in `docs/plans/` (see `docs/INDEX.md`). Open starts with what comes next; "Sharpen the saw" is the standing home for work on the tools, checks and ways of working that make later changes faster and safer.

## Open

**Frozen until the truthful clone is declared done:** Beyond Agenda, Ideas and Towards many users wait (bug fixes only). Not frozen: the clone's safety work and tests (Towards parity, meeting 2026-10-22, § 5c) and Sharpen the saw (meeting 2026-10-22, § 5i).

**Next action:** Agenda's menus captured in DOSBox and compared by a test (Towards parity, below). The extras' shelf (ADR 0044) and the Extras preference (R77, v0.18.0) are done (2026-10-23); the owner turns Extras on in File ▸ Customize to keep the blog, feeds and Zettel ids. The tagging of AGENDA_PARITY.md's entries is done (2026-10-22); the changes back are items below, each settled with the owner before it is built.

**Next:** a truthful clone of Lotus Agenda first (meeting 2026-10-21, § 5; `VISION.md`, ADR 0043): parity before everything else, "Beyond Agenda" frozen to bug fixes until the clone is declared done. First the clone's own groundwork, in "Towards parity" below: Agenda's menus captured in DOSBox and compared by a test (the extras' shelf, ADR 0044, and the Extras preference, R77, done 2026-10-23). Beside it, the clone's safety work. After that the parity steps, View Properties first and recurring items on every date second (meeting 2026-10-22, § 5f), the habit changes settled first: F6 on a view opening View Properties, or DEL putting items in a trash; and the note editor's open questions (should GETITMS ask Agenda's "discard the copied items?"; external note files, step 7, or left out on purpose). Approved and tagged up to v0.16.0 (2026-10-19); v0.16.1 (the note scrolling fix) tagged 2026-10-22. The repository is on GitHub (private, `jamting/agendum`) with CI, 2026-10-17; a public repository is made from it when the clone is done (Housekeeping). The view cache waits for slow answers in real use.

### Sharpen the saw

Tools and checks that make every later change faster and safer. Each is small; the command layer they made safer is done (R66, ADR 0036, in `ROADMAP_DONE.md`). From the expert review of 2026-10-16 (`docs/reviews/2026-10-16.md`) and the performance items found earlier.

- [ ] A view cache, when the evidence asks for it: every key rebuilds the whole view (each item's cells, and every item's text wrapped for the screen, not only the rows shown), about three times per key. Measured 2026-10-16, a cursor move: 300 items 6 ms in `Update` + 11 ms in `Render`; 3,000 items 61 + 45 ms; 10,000 items 205 + 231 ms. First build it once per key and share it; then keep it in the session's state between keys as a value with a key that says when it is stale (ADR 0035): the database, the view, the date and time, the screen width, collapsed families, the search. Needs an ADR. **Wait until the debug log shows `slow answer` lines (over 100 ms) in real use** (owner's decision, 2026-10-16); ingested items (`plans/ITEM_LEVELS.md`) will likely be what brings them. The command layer, which reshaped the state it would live in, is done; the TUI state's split into file and session (Towards many users) reshapes it again

### Towards many users

**Waits until the truthful clone is declared done** (meeting 2026-10-21, § 5; meeting 2026-10-22, § 5i).

*[A page here was soaked in the creek. — Rabbit]*

Then a web version for one person:

*[A page here was soaked in the creek. — Rabbit]*

Then working together:

*[A page here was soaked in the creek. — Rabbit]*

### Towards parity with Agenda (Milestone 2)

**The ambition:** Agendum as close to Agenda 2.0 as makes sense: the same screen, keys, menus and behaviour, apart from a list of accepted enhancements (beyond Agenda) and accepted modifications (done differently, on purpose). Everything else that differs is a gap, to close or to move onto one of the lists. Today about 80% overall (control panel and F10 menu about 75%, the note editor about 50%, the data model and views about 90%). The overview, checked in Agenda 2.0 run headless, with the two lists and the steps: [`docs/plans/AGENDA_PARITY.md`](plans/AGENDA_PARITY.md)

- [ ] The truthful clone's groundwork (meeting 2026-10-21, § 5–9), in this order:
  - [ ] Agenda in DOSBox as the reference for texts and menus (§ 8): a capture tool run by hand (`tools/agformat/agenda_driver.py`) walks Agenda's F10 menus (the view's, the note editor's, the category manager's) and writes their entries and help lines to a committed JSON reference, which replaces or generates the hand-made table in `docs/reference/AGENDA_MENUS.md`; a test, without DOSBox, compares `Agendum.TUI.Menu.tree/0` with it and fails on any difference not tagged as accepted (the tags above). Differences are found automatically and fixed by hand. Then the labels in settings boxes, the key bar and messages, step by step. Long help lines are Lotus's text: mind them before going public (GITHUB.md § 7)
- [ ] The changes back from the tagging sitting (2026-10-22; AGENDA_PARITY.md's two lists, tag *change back*). Each alters a habit: settle it with the owner before it is built, then the owner tries it before the next is built on it:
  - [ ] New files get Agenda's date format, MM/DD/YY; ISO stays a choice (YYYYMMDD with "-"), and a file keeps the format it has
  - [ ] Agenda's menu shape: Utilities back, no Search menu, Undo and Redo off the top level (their keys stay); File ▸ New, File ▸ Dating, Category ▸ Recalc, View ▸ Rename, View ▸ Last and Item ▸ Note / When / Show / Finished / Mark / Unmark leave the menus, their keys and CTRL-X stay. Goes with the DOSBox menu comparison above
  - [ ] No mode word when ready, and only Agenda's mode words elsewhere
  - [ ] The key bar on two lines, the keys above their labels, as Agenda's
  - [ ] Settings boxes apply their changes on ENTER, not while open (ADR 0030, amended 2026-10-22); ESC still puts back everything since the box opened (tagged *work*)
  - [ ] Category lists opened from a box (filters, Assignment Profile, conditions, Excludes): "Press ENTER to accept", SPACE switches a category, ENTER and ESC both close the list keeping the change
  - [ ] File ▸ Maintenance ▸ MakeCopy in Write's place (check in Agenda first which file you are in afterwards)
- [ ] Alarms as Agenda's (the tagging sitting, 2026-10-22): an alarm that came due while the file was closed rings when it is opened and shows `@`, without a box (checked in Agenda 2.0); Utilities ▸ Show Alarm, a Show View with !Current Alarms! and !Past Alarms! (DEL removes an item from the list; Past Alarms emptied at the end of the day; User's Guide 10-18 to 10-20). The "While you were away" box (R70) is an extra since R77 (2026-10-23): with Extras off, missed alarms already ring on open, without the box
- [ ] Search compared with Agenda's (ALT-F6 SEARCH in a view and a note, its Search box, the Match show view): the differences become parity work (the tagging sitting, 2026-10-22: no longer an enhancement)
- [ ] The clone's safety, clone work and not frozen (meeting 2026-10-22, § 5c; expert review 2026-10-21, § 8 and § 14):
  - [ ] A closed effect type, with a last clause in `App.run_effects/2` (`lib/agendum/tui/app.ex:209-309`) for an effect it does not know, so an unknown effect is logged rather than a crash (the crash of 2026-10-17, `a0612f9`)
  - [ ] A recovery file on a crash: the unsaved file written beside it, and offered when it is next opened
  - [ ] Hostile-text tests: a `.AG` file (and a feed) whose item text asks for changes imports as plain items, and only its own
- [ ] Towards parity (AGENDA_PARITY.md, "The steps"; View Properties first, recurring items second, meeting 2026-10-22, § 5f):
  - [ ] The View Properties box for every view (screenshot 143), F6 on the view
  - [ ] Recurring items on every date they recur: in each datebook section and in any date filter that covers an occurrence, counted from the base date, still one item (as Agenda does; checked in Agenda 2.0, User's Guide 7-11). Plan with the evidence, the habit changes to settle first and the steps: `docs/plans/RECURRING_OCCURRENCES.md` (R14a). A parity step since meeting 2026-10-22, § 5a
  - [ ] The note editor as Agenda's (its own item, below; `NOTE_EDITOR.md`)
  - [ ] The trash: Item ▸ Undisc, Utilities ▸ Trash, File Properties ▸ Empty trash
  - [ ] File ▸ Abandon, File Maintenance Erase, File Transfer Template
  - [ ] Show ItemsDone, Show Every, Show Circular (with the `o` indicator)
  - [ ] Control panel symbols and indicators: `*` on a date category or value, `WAIT` while a calendar is fetched, `D` with unindexed categories (and unindexed categories themselves)
  - [ ] Compare the category, view and macro managers' menus with Agenda's, and add them to the overview
  - [ ] File Properties: Agenda's other settings (File description, Set file password, Make backup on open, Empty trash; screenshot 130) where Agendum has them (Tab size done, R64e)
  - [ ] Agenda's help, in our own words (meeting 2026-10-22, § 7; AGENDA_PARITY.md, step 10): Agenda's F1 keys and structure exactly (the topic for where you are, bold links, F3 Index, F5 Find, F6 Keys, F8 or BACKSPACE Review; PURPOSE, STEPS, PRESS / TO DO THIS), the texts new since Agenda's are Lotus's: terse, a Hundred Acre Wood flavour in an opening line and the examples, no Milne quoted, no Disney or Shepard pictures. Today's F1 texts and command descriptions become its topics; F1's `c`, `d`, `a` (R65) stay reachable from it
  - [ ] Optional: Utilities Launch (a shell without quitting)
- [ ] Category properties of a date or numeric category as Agenda's: the box shows only Category name, Type, Parent, Note, Note file, Special actions, Assignment actions, Statistics and Advanced settings; Short name, Match category name, Match short name, Also match, Exclusive children and Assignment conditions go (checked in Agenda 2.0, 2026-10-16, converting a category in its box: the fields vanish as Type changes). A habit change for the box: settle with the owner first; Agendum's Excludes (ours) to decide too
- [ ] View layout and symbols: no "Section:" line, a blank line between sections; ‼ done, ♪ note; exclusive families bracketed (┌ ├ └); * date categories and datebook views; the category manager without counts and tags
- [ ] Boxes: F8 (DEFAULT) puts the highlighted setting back to its default, ALT-F8 (DFLTALL) every setting in the box, CTRL-ENTER clears a setting (User's Guide 2-17)
- [ ] Editing: the prompt and input field in the control panel (EDIT), editing key bars (F2 Paste, F3 Copy, F4 Cut, F7 Mark) in item text and category names (the note editor's header: in the note editor plan above)

### The note editor (Milestone 2)

- [ ] The note editor as Agenda's (checked in Agenda 2.0, 2026-10-15; printing and typesetting, F10 Print and F6 MARKER, out of scope). Evidence, the habit changes to settle first (ESC, INS, TAB, the control panel's first line) and the steps: [`docs/plans/NOTE_EDITOR.md`](plans/NOTE_EDITOR.md)
  - [x] Its control panel and key bar (R64a, 2026-10-17): line 1 "Note for:   …" (the macro editor's "Edit macro:  …") with "Line N INS EDIT" on the right, a message over it until the next key, hints on line 2; the key bar in Agenda's order, F1 Help … F5 Return, F7 Mark. "Note file: …" comes with external note files, F10 Menu with the menu
  - [x] Its F10 menu (R64b, 2026-10-17): Clear (asks; one undo step), Return, Quit, with Agenda's help lines; Import and Export come with the next item, File with external note files
  - [x] Import a text file at the cursor; Export the note to a text file (R64c, 2026-10-17): prompts with F3 listing `.txt` and `.md`, CR LF read as LF
  - [x] ESC asks "Discard changes?" (R64d, 2026-10-17): only when the note changed; No (first) saves, Yes restores the note as opened, saved replacements and Clear included; ESC on it goes back to the note; F5, ALT-N/P save without asking
  - [x] Editing keys, part 1 (R64e, 2026-10-17): ALT-M, word moves (CTRL-←/→, ⌥←/→), word delete (⌥⌫, CTRL-W, ALT-W), CTRL-K to the line end, PGUP/PGDN, CTRL-HOME/END (⌥< ⌥>)
  - [x] Editing keys, part 2 (R64e, 2026-10-17, v0.15.0, format 37): INS/OVR (INS, CTRL-N) shown in the header; TAB to the next tab stop, File Properties ▸ Tab size (stored, 5 by default)
  - [x] ALT-F9 APPEND, ALT-F8 GETITMS and ALT-C (calendar) in a note (R64f, 2026-10-17); GETITMS copies only: whether to add Agenda's "discard the copied items?" question is the owner's to decide
  - [x] Bug: in a note longer than the screen, ↑ from the bottom kept the cursor on the bottom row and scrolled the note under it (found by the owner, 2026-10-18). The note now keeps the row it shows first and scrolls only when the cursor would leave the screen, as an editor does
  - [ ] External note files: File Attach, Detach, Erase (a stored field and an ADR)
  - [ ] Optional: ALT-F1 COMPOSE
- [ ] Undo in the note editor: CTRL-Z / CTRL-Y while editing a note, for typing (in sensible chunks: a word or a line, not every key) and for Search/Replace's replacements, with the note's text and cursor restored in the editor; the steps join the file's history when the note closes (today undo works only after closing the note, ADR 0005)

### Data interchange (Milestone 4)

- [ ] Repeating events in a calendar from another time zone: each occurrence converted in its own zone, so the weeks between the two zones' summer-time changes are not an hour off (SPEC R45)
- [ ] Optional: read original `.AG` files directly. The format is now largely known (`docs/AGENDA_FILE_FORMAT.md`; research log `docs/plans/archive/AGENDA_FILE_FORMAT_LOG.md`; reference reader `tools/agformat/agdump.py`): items, notes and note files, categories with all their settings, conditions and actions, assignments with values, relative and recurring dates, alarms, views with sorting and filters, datebooks, sections, columns with formats, file settings
  - [x] Reverse engineer the format: container, items, categories, values, views (2026-10-14)
  - [x] Settle the open parts: view/section sort and filter words, relative-date encoding, actions, settings (2026-10-15, second round; how to drive Agenda: `tools/agformat/DRIVING_AGENDA.md`)
  - [x] An Elixir reader and conversion (pure, `Agendum.Core.AgFile`, through the JSON format's checks); File ▸ Transfer ▸ Import of a `.AG` and `agendum OLD.AG`, with a password and a report of what came over (R72, 2026-10-16)
  - [ ] Still to bring over: note files (read by the shell beside the `.AG`), the global date format, a datebook's base date
  - [ ] Macros. Every macro in the files at hand is a starter's helper program in Agenda's macro command language (`{INPUTTEXT;…}`, `{DEFSTR;%var}`, `{LABEL}`, `{WINDOWSON}`), not recorded keystrokes, so R50 cannot run them; the owner's own Planner has only Planner's 10 (contact list, date settings, hide done, print, four sorts), none of the owner's. Planner, Account Manager, People Manager and Information Sifter have 10, 14, 10 and 6 (checked 2026-10-16). Options when picked up: import plain keystroke macros as R50 macros, and keep each other macro's text in a note so it can still be read; the command language itself stays out of scope (SPEC § 6)
- [ ] Optional: Agenda structured files (`.STF`): import and export as Agenda 2.0's File Transfer does (Working with Definition Files, Appendix B; User's Guide chapters 23–24), so legacy users can bring old files over via DOS Agenda's export. Read both 2.0 dates (`{C}\When@|10%/31%/1990`) and 1.x dates (`{W}10/31/90`) into the same When/Entry/Done categories (Lotus Q&A "Date Categories are Duplicated")
- [ ] Optional: Import of structured text files (one item per line, with categories)
- [ ] Optional: TXT2STF-style definition files that turn plain text into items (Working with Definition Files). A first real use: the session summaries in `docs/summaries/` (one per feature, all alike: `#` title, dated, commit hashes, R-numbers), imported with STF and a definition file so text matching files them (the owner's wish, 2026-10-15)

### Time management (Milestone 5)

- [ ] Alarms sent to your phone with Signal, as well as on the screen: through the separate `signal-cli` program, linked to your Signal account; optional (nothing changes without it), set up in File ▸ Customize

### Housekeeping

- [ ] The session summaries into git: `docs/summaries/` no longer ignored (`.gitignore:55`), committed to this private repository, so they are not on one disk only; left out of the public copy with the business files (`GITHUB.md` § 7) (meeting 2026-10-22, § 5h)
- [ ] Rename the repository folder (`Lotus Agenda`) to match, moving Claude Code's project memory with it ([`docs/plans/RENAME_REPO.md`](plans/RENAME_REPO.md))
*[A page here was soaked in the creek. — Rabbit]*

### Users and direction

- [ ] Real users, when there are any: old Agenda users and people who love keyboard tools, with the debug log on (`AGENDUM_LOG`) and a short talk with each; what they stumble on goes here (expert review 2026-10-16). Not a condition for declaring the clone done, and no search for old Agenda users now: the owner knows none (meeting 2026-10-22, § 5a and § 5e)

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
