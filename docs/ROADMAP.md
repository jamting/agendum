# Roadmap

Small, testable increments. Open work comes first, by area; done work is
below, by milestone, as the record. Tick a box when its tests pass under
`mix check`, and move it to Done. Rule numbers refer to `SPEC.md`; larger
items have a plan in `docs/plans/` (see `docs/INDEX.md`).

## Open

**Next:** first "Sharpen the saw", small work on the tools and checks;
then the command layer ("Towards many users"), the next major work.
Parity with Agenda and the rest continue after it.

### Sharpen the saw

Tools and checks that make every later change faster and safer. Do these
first: each is small, and the command layer (below) is a large refactoring
that leans on them. From the expert review of 2026-10-16
(`docs/reviews/2026-10-16.md`) and the performance items found earlier.

- [ ] Meaning in the fuzz walks: after every key, the data model's invariants hold (no item directly in both a category and one of its ancestors, R7c; at most one child of an exclusive parent, R7; each link and its reverse agree; every id below `next_id`), and undo back to the start gives the starting file (R30). One pure check of the invariants, used by the fuzz property (`test/agendum/tui/fuzz_test.exs`), the JSON round trip and the core tests
- [ ] CI: `mix check` on every push (GitHub Actions) and the long fuzz run (`FUZZ_RUNS=3000`) nightly, once the repository is on GitHub (Housekeeping); until then a git pre-push hook that runs `mix check`
- [ ] Golden files for the file format: a small file saved by each format version from 33 on, committed when the version is made, all loaded by one test. Today's upgrade tests build old files from today's structs (`test/agendum/store_test.exs`), which can miss what a real old file holds
- [ ] The format of record (an ADR): which format keeps people's data for years, the JSON schema (`JSON_FORMAT.md`, round-trip tested) or a command log as the web plan needs, with today's Erlang-term file (`Agendum.Store`, ADR 0003) as a fast copy of it. Settle it before the web plan adds its own storage; fewer upgrade paths per stored field
- [ ] Architecture rules checked on the call graph, not by regex: a compile tracer or `mix xref`, so that an alias (`alias Agendum.Core.Database, as: DB`) or `put_in(state.db…)` cannot get round "the TUI changes the database only through `Agendum.Core`" (`test/agendum/architecture_test.exs`)
- [ ] Typed UI modes: a struct per mode instead of the `%{type: …}` maps in `State.modes` (about fifty kinds), so the compiler and Dialyzer catch a misspelt field that today only the fuzz test finds; box by box, starting where the command layer will work
- [ ] Date rules compiled once: reading a date compiles every rule of the date languages each time (`DateParser.compile/4`, ~100 regexes), the root cost behind the lags fixed on 2026-10-15. Execute over 300 items with dated text takes ~1.1 s, nearly all of it there (two readings an item). The core cannot cache in a process; the compiled rules could travel in `Agendum.Core.Context`, built once when the languages or input format change
- [ ] A view cache, when the evidence asks for it: a view on a large file is still slow to move in (at 3000 items a cursor move takes ~90 ms in `Update` and ~55 ms in `Render`), as every key rebuilds the view. Cache the computed view in `State`, recomputed only when the database, view or date changes (needs an ADR); wait for a `slow answer` line in the debug log that points at it.

### Towards many users: the command layer (the next major work)

A web application with accounts and shared files, on the same core (plan:
[MULTIUSER.md](plans/MULTIUSER.md), ADR 0020). First, in the core and the TUI, a
few commands at a time. The command layer is the next major work, after
Sharpen the saw: the web, customizable keys, a modern mode and Wol all
wait for it (expert review 2026-10-16, `docs/reviews/2026-10-16.md`).

- [ ] A command layer: one named command per user action, applied by the core. Existing actions move over a few at a time; done when `Agendum.TUI.Update` only turns keys into commands and has no logic of its own (an architecture test then keeps it so)
- [ ] Commands that describe themselves (name, summary, documentation, global or local, available now), keys bound through keymaps (R65, ADR 0033)
  - [x] The view's keys run named commands through a keymap (`Agendum.TUI.Commands`, `Agendum.TUI.Keymap`)
  - [x] A count with ALT-digits in views, for the commands chosen to take one; a repeat that changes nothing stops
  - [x] The global keys (CTRL-Z, CTRL-S …) and the keys that stand for others (CTRL-N = INS) in `Agendum.TUI.Keymap`
  - [x] The category and view managers' and a note's keys in keymaps (F1 `c` and `d` there too)
  - [x] The keys every box shares in a keymap (`:box`: F1, F3 choices, ESC cancel); F1 `c` and `d` in every box, its own keys read from its key bar
  - [x] Each box's own keys in a keymap of its own (`Box.keymap/1`, `commands/1`, `run/3`; settings boxes from `Box.settings_keymap/1`); `c` and `d` no longer read key bars
  - [x] The menu: its keys in a keymap; F1 `c` lists the level's entries by their letters, F1 `d` describes them
  - [x] Moving items, a column or a section, a column's width, Browse and searching the view: keymaps of their own, F1 there too
  - [x] The typing keys in keymaps: one line (`:line`, `Typing.LineEdit`) and a note's text (`:text`, `Typing.TextEdit`)
  - [x] Whether a command can run now (R65a): F1 `c` greys what cannot, says why, and ENTER gives the reason; each place's `unavailable/1` (the owner chose grey in place over hiding or putting last, 2026-10-16)
  - [x] A longer text than the summary, saying why one would use the command where that is not obvious (R65b): the view's, the global ones, the managers' and a note's
  - [x] Longer texts for the menu's entries (by their labels; an entry that runs a view's or a global command has its text) and the boxes' own commands (by box; a settings box's Change and Done shared)
  - [ ] Longer texts for the rest, where they would help: the moves (Browse, widths …) and typing
- [ ] Customizable key bindings: the person's own bindings, per place or everywhere, kept in the preferences and set in File ▸ Customize ▸ Keys; they come before macro keys and Agenda's keys; ESC, F1, the command list and describe key cannot be rebound
- [ ] Raw values (dates, numbers) beside the formatted cells in `Agendum.Core.ViewModel`
- [ ] Browsing's date arithmetic into the core
- [ ] Split the TUI state into the shared database and the session (modes, view, cursor, typing)

Then a web version for one person:

*[A page here was soaked in the creek. — Rabbit]*

Then working together:

*[A page here was soaked in the creek. — Rabbit]*

### Towards parity with Agenda (Milestone 2)

**The ambition:** Agendum as close to Agenda 2.0 as makes sense: the same screen, keys, menus and behaviour, apart from a list of accepted enhancements (beyond Agenda) and accepted modifications (done differently, on purpose). Everything else that differs is a gap, to close or to move onto one of the lists. Today about 80% overall (control panel and F10 menu about 75%, the note editor about 50%, the data model and views about 90%). The overview, checked in Agenda 2.0 run headless, with the two lists and the steps: [`docs/plans/AGENDA_PARITY.md`](plans/AGENDA_PARITY.md)

- [ ] Towards parity (AGENDA_PARITY.md, "The steps"):
  - [ ] The note editor as Agenda's (its own item, below; `NOTE_EDITOR.md`)
  - [ ] The View Properties box for every view (screenshot 143), F6 on the view
  - [ ] The trash: Item ▸ Undisc, Utilities ▸ Trash, File Properties ▸ Empty trash
  - [ ] File ▸ Abandon, File Maintenance Erase, File Transfer Template
  - [ ] Show ItemsDone, Show Every, Show Circular (with the `o` indicator)
  - [ ] Control panel symbols and indicators: `*` on a date category or value, `WAIT` while a calendar is fetched, `D` with unindexed categories (and unindexed categories themselves)
  - [ ] Compare the category, view and macro managers' menus with Agenda's, and add them to the overview
  - [ ] File Properties: Agenda's other settings (File description, Set file password, Make backup on open, Empty trash, Tab size; screenshot 130) where Agendum has them
  - [ ] The ALT and CTRL key bars while the key is held (kitty keyboard protocol), and after ESC as a prefix (plan: `docs/plans/KITTY.md`)
  - [ ] Optional: Utilities Launch (a shell without quitting)
- [ ] View layout and symbols: no "Section:" line, a blank line between sections; ‼ done, ♪ note; exclusive families bracketed (┌ ├ └); * date categories and datebook views; the category manager without counts and tags
- [ ] Boxes: F8 (DEFAULT) puts the highlighted setting back to its default, ALT-F8 (DFLTALL) every setting in the box, CTRL-ENTER clears a setting (User's Guide 2-17)
- [ ] Editing: the prompt and input field in the control panel (EDIT), editing key bars (F2 Paste, F3 Copy, F4 Cut, F7 Mark) in item text and category names (the note editor's header: in the note editor plan above)
- [ ] Hypertext help: topics with links (TAB, ENTER), Index, Find, Review (Agenda's F1)

### The note editor (Milestone 2)

- [ ] The note editor as Agenda's (checked in Agenda 2.0, 2026-10-15; printing and typesetting, F10 Print and F6 MARKER, out of scope). Evidence, the habit changes to settle first (ESC, INS, TAB, the control panel's first line) and the steps: [`docs/plans/NOTE_EDITOR.md`](plans/NOTE_EDITOR.md)
  - [ ] Its control panel ("Note for: … Line N INS EDIT", "Note file: …") and key bar (F5 Return, F10 Menu)
  - [ ] Its F10 menu: File, Import, Export, Clear, Return, Quit
  - [ ] Import a text file at the cursor; Export the note to a text file
  - [ ] ESC asks "Discard changes?" (No saves, Yes restores the note as opened)
  - [ ] Editing keys: INS/OVR, TAB with File Properties ▸ Tab size, ALT-M, word delete (CTRL-BACKSPACE, ALT-W), delete to line end, word moves, PGUP/PGDN, CTRL-HOME/END
  - [ ] ALT-F9 APPEND, ALT-F8 GETITMS and ALT-C (calendar) in a note
  - [ ] External note files: File Attach, Detach, Erase (a stored field and an ADR)
  - [ ] Optional: ALT-F1 COMPOSE
- [ ] Undo in the note editor: CTRL-Z / CTRL-Y while editing a note, for typing (in sensible chunks: a word or a line, not every key) and for Search/Replace's replacements, with the note's text and cursor restored in the editor; the steps join the file's history when the note closes (today undo works only after closing the note, ADR 0005)

### Data interchange (Milestone 4)

- [ ] Repeating events in a calendar from another time zone: each occurrence converted in its own zone, so the weeks between the two zones' summer-time changes are not an hour off (SPEC R45)
- [ ] Optional: read original `.AG` files directly. The format is now largely known (`docs/AGENDA_FILE_FORMAT.md`; research log `docs/plans/AGENDA_FILE_FORMAT_LOG.md`; reference reader `tools/agformat/agdump.py`): items, notes and note files, categories with all their settings, conditions and actions, assignments with values, relative and recurring dates, alarms, views with sorting and filters, datebooks, sections, columns with formats, file settings
  - [x] Reverse engineer the format: container, items, categories, values, views (2026-10-14)
  - [x] Settle the open parts: view/section sort and filter words, relative-date encoding, actions, settings (2026-10-15, second round; how to drive Agenda: `tools/agformat/DRIVING_AGENDA.md`)
  - [ ] Elixir reader outside the pure core, converting to the JSON format; File ▸ Transfer ▸ Import of a `.AG`. The first users are likely old Agenda users, and this brings them (expert review 2026-10-16)
- [ ] Optional: Agenda structured files (`.STF`): import and export as Agenda 2.0's File Transfer does (Working with Definition Files, Appendix B; User's Guide chapters 23–24), so legacy users can bring old files over via DOS Agenda's export. Read both 2.0 dates (`{C}\When@|10%/31%/1990`) and 1.x dates (`{W}10/31/90`) into the same When/Entry/Done categories (Lotus Q&A "Date Categories are Duplicated")
- [ ] Optional: Import of structured text files (one item per line, with categories)
- [ ] Optional: TXT2STF-style definition files that turn plain text into items (Working with Definition Files). A first real use: the session summaries in `docs/summaries/` (one per feature, all alike: `#` title, dated, commit hashes, R-numbers), imported with STF and a definition file so text matching files them (the owner's wish, 2026-10-15)

### Time management (Milestone 5)

- [ ] Recurring items on every date they recur: in each datebook section and in any date filter that covers an occurrence, counted from the base date, still one item (as Agenda does; checked in Agenda 2.0, User's Guide 7-11). Plan with the evidence, the habit changes to settle first and the steps: `docs/plans/RECURRING_OCCURRENCES.md` (R14a)
- [ ] Alarms sent to your phone with Signal, as well as on the screen: through the separate `signal-cli` program, linked to your Signal account; optional (nothing changes without it), set up in File ▸ Customize

### Housekeeping

- [ ] Rename the repository folder (`Lotus Agenda`) to match, moving Claude Code's project memory with it ([`docs/plans/RENAME_REPO.md`](plans/RENAME_REPO.md))
*[A page here was soaked in the creek. — Rabbit]*

### Users and direction

- [ ] Who Agendum is for, in one paragraph at the top of this roadmap, and the "Beyond Agenda" items weighed against it (expert review 2026-10-16)
- [ ] Five real users before Milestone 2 is closed: old Agenda users and people who love keyboard tools, with the debug log on (`AGENDUM_LOG`) and a short talk with each; what they stumble on goes here (expert review 2026-10-16)

### Beyond Agenda

- [ ] A GTD starter, like the Planner (R60, ADR 0028): Inbox, Next Actions by context, Projects, Waiting For, Someday/Maybe, and views for a weekly review (items untouched for a while, projects without a next action), so the rules show what they can do in a method many people know (expert review 2026-10-16)
- [ ] Capture from outside: `agendum add "text" FILE` from the shell, filed by the core as if typed in the view (the file's main view and section); later a mail or phone path (expert review 2026-10-16)
- [ ] More date languages (one `Agendum.Core.DateLanguage` pack each)
- [ ] Modern by default: today's names and standard keys out of the box (Open not Retrieve, Delete not Discard, CTRL-O/S/Z/F/N…), with Agenda's names and keys one setting away ("Agenda mode"). Agenda's steep learning curve limited its audience (AGENDA_HISTORY.md); the power should stay, the strangeness should not be the first thing people meet. Builds on the keymaps, self-describing commands and own key bindings (Towards many users); departs from ADR 0006 and 0007, so it needs an ADR of its own
- [ ] Flashcards with active recall and spaced repetition: an item is the question, its note the answer; a deck is any category. The schedule is kept in ordinary categories made the first time (date category Due; numeric Interval, Ease and Reviews), so filters, datebooks, sorting and JSON work on cards as they are, with no new stored fields. A review mode on the due items: the question, SPACE shows the note, then Again / Hard / Good / Easy sets the next Due date (one undo step per card). Scheduling is SM-2 to begin with, in a pure core module with the clock passed in, behind an interface that FSRS could replace
- [ ] A micro-blog from the file: the items of a chosen category (e.g. Posts) are posts, the item the title, the note the content (a Markdown subset), When the date (else Entry). File ▸ Transfer ▸ Publish writes a static site: an index page newest first, a page per post and an RSS feed (`rss.xml`), plain HTML without JavaScript. The site's title, base address (for the feed's links) and author are kept in the file. The pages are made in a pure core module (`{path, html}` pairs); the shell writes them to a folder, and can then sync the folder to a server with `rsync` over `ssh` (the person's own keys; nothing is stored by Agendum; optional, nothing changes without rsync). Markdown: a small subset of our own, or Earmark if it passes ADR 0021
- [ ] Zettelkasten IDs and links between items: every item gets an ID when it is made, its creation time as YYMMDDHHMM plus a digit that counts up only when two items are made in the same minute (`26101311140`); stored with the item and never changed (items from older files get one from their Entry date on load). A column kind shows it. `[[26101311140]]` in an item's text or note is a link: shown as typed in the link colour, the target's text in the control panel when the cursor is on it, a broken link marked. Following a link (a key to choose, with a Mac-friendly alternative) shows the target in the Show View (ALT-F8 back); Item Properties lists the items that link to it ("Linked from"), and a search lists them in the Show View. A key inserts a link to the marked item. Text matching ignores links. In the published micro-blog a link is an `<a>` to the target's page, or its title in plain text if the target is not published. Ours, not Agenda's; a stored field (DATA_MODEL, JSON schema, format version)

### Ideas

- Multiple files open; a launcher listing recent files
- In-line help in boxes: the hint inside a box (made from its keys, `Box.hint/2`) as the start of a fuller help, with longer texts in a help box of their own (the owner's idea, 2026-10-14)
- Wol in the machine: a personal agent (a language model) inside the file, using its items, categories, views and rules as the person's own meaning; it files, finds and plans by proposing, never silently changing; the core stays pure and privacy comes first. Builds on the command layer (Towards many users). Thoughts in [`docs/plans/WOL-IN-THE-MACHINE.md`](plans/WOL-IN-THE-MACHINE.md)

## Done

### Milestone 1 — Foundation

- [x] Pure core: items, category hierarchy, links, views (R1–R5)
- [x] Subsumption, deletion side effects (R3, R4)
- [x] Mutual exclusion, category links (R7, R8)
- [x] Automatic assignment by name with ambiguity resolution (R10–R13)
- [x] View model: sections, columns, star and date columns (R20, R22)
- [x] Save/load (versioned binary format)
- [x] TUI: view, inline editing, column entries, F-key bar, menu, help
- [x] Category manager (add, rename, promote/demote, reorder, move, discard, properties)
- [x] View manager; category picker; assignment profile; notes
- [x] Move items between sections (R26); view hide options (R27)
- [x] Print view to text file
- [x] Escript binary
- [x] Property-based fuzzing of the UI (random key sequences never crash; frames always fill the screen)

### Milestone 2 — Fidelity

- [x] Undo / redo (R30)
- [x] Mac-friendly keys: CTRL alternatives for INS and F-keys, Mac editing keys, ⌘ mapping guide (R31)
- [x] Autocompletion while typing column entries (Agenda's AUTOC indicator) (R32)
- [x] Collapse/expand families in the category manager, boxes and profile, and sections in views (ALT− / ALT=) (R33)
- [x] Item properties box (F6 on an item), as well as the profile (R34)
- [x] Marked items: bulk done / discard / remove / When / move / assign, group profile (R35)
- [x] Sorting items (ALT-F5 SORT) and view/section filters by category (R28, R36)
- [x] Search the view (ALT-F6) and the file (Show View), ALT-F8 last view (R37)
- [x] Search and replace in notes (ALT-F6 and ALT-S in a note) (R39)
- [x] Time in the title bar; alarms before the When date and time (R38)
- [x] Colour and monochrome themes: `--theme classic|mono`, `--mono`, NO_COLOR (R40)
- [x] Date display format: File ▸ Properties sets date order, separator, 12/24-hour clock, day of week (R41)
- [x] Show a category's short name in columns too narrow for its full name (e.g. "Anna" instead of "Anna Las") (R22)
- [x] Original keys in views: ALT-F5 GO TO a section, ALT-N/ALT-P next/previous view, ALT-W/G/Q save/retrieve/quit, ALT-V empty sections, ALT-K key map, ALT-I insert (R42)
- [x] Original keys in the category manager: ALT-R child, ALT-L uncle, ALT-D/ALT-U/ALT-I sibling below/above (R42)
- [x] Original keys in notes: ALT-D/ALT-T insert date/time, ALT-N/ALT-P next/previous note, ALT-S repeats a replacement (R39, R42)
- [x] Original keys that need new features (R42): ~~ALT-F9 copy item~~ (done: the Copy box), ~~ALT-Y yank back removed item~~ (done; from the trash when there is one), ~~ALT-H hop to next occurrence~~ (done), ~~ALT-F7 make item from note text, ALT-F2 make category from note text~~ (done for the word, line or all text; marked text with F7 MARK in notes) (R42)
- [x] Columns per section (User's Guide 3-16, 3-27, 5-22 to 5-25): a column belongs to one section or to all; linked columns change together; removing asks all sections or this one; each section's item text fills what its columns leave. Existing files load with every column in every section, linked (R55)
- [x] File ▸ Properties ▸ Insert new columns in (All sections / Current section), with the File Properties box drawn from a layout as in screenshot 130 (R55)
- [x] Column Properties for standard columns, with Link with other sections (unlink, or link with the columns of the same head, type, format and width), drawn from a layout as in screenshot 127 (R55)
- [x] One Column Properties box for every column, as Agenda's: the numeric and date boxes become the lower part of it, below Column head, Width, Category type and Link with other sections (screenshots 127, 133); Column head changed there with F3 (linked columns change too) (R55)
- [x] Smaller column leftovers (R55): the Column Add box, View ▸ Column ▸ Width and Move, Item Column Properties (the item column's width per section, set automatically or by hand, linked)
- [x] Typing a column head's name in Column Add and Column Properties: an existing category or a new one under MAIN (User's Guide 3-17, R55)
- [x] Column Add ▸ Category type: a standard head made a date or numeric category as the column is added, asking first as Category Properties does (User's Guide 3-17, R55)
- [x] The item column in View ▸ Column ▸ Width and Move: its width typed or fitted, and moving it among the other columns, as Agenda could (User's Guide 5-20, 5-21)
- [x] Standard column formats (R56): Name only, Parent:Category, Ancestor, Star, Yes/No and Category note (a column showing line N of the note of the item's category in that family, as Agenda's Activities Planner shows Phone # and Company from a person's note), in Column Properties and the Column Add box, with typing in Star, Yes/No and Category note columns
- [x] Hide column heads (R57): View ▸ Hide ▸ Column heads, column heads only on the first section on the screen, as Agenda's datebooks are; also in the datebook settings box, with Section separators (R58), the box drawn from a layout
- [x] Section separators (R58): View ▸ Section ▸ Lines, each section head a line across in place of the blank line; in the View Properties box when there is one
- [x] ♪ in the control panel (R59) when the highlighted section head, column entry or column head has a category note, not only an item (User's Guide 12-2; screenshot 126), so a note-line column (R56) shows whose note it reads
- [x] Section Properties box (View ▸ Section ▸ Properties; Help "Section Properties/Add Box") (R61)
  - [x] Section head, Item sorting, Section statistics, Filter, a Columns list with `<Items>` (DEL, ALT-↑↓, INS), drawn from a layout; F6 on a section head opens it
  - [x] Select numeric functions: the calculations of every numeric column in the section (the R29 gap), written into the columns (linked ones change everywhere)
- [x] Moving a section within its view (R62): ALT-F10 on a section head or View ▸ Section ▸ Move, the sections collapsed while it moves (User's Guide 5-8 to 5-9); in that view only

### Look and feel — after screenshots of Agenda 2.0 (ADR 0018)

The general look and feel of the real program, step by step; not pixel fidelity.
`tools/screenshots/` draws our screens for comparison.

- [x] Agenda's colours as the default theme: grey screen, blue heads and entries, white-on-red highlight, cyan boxes in a solid blue frame with a centred title and a shadow, the screen behind a box greyed out, cyan category manager, yellow-on-blue help; exact VGA colours on 24-bit terminals; the highlighted line tinted (R40)
- [x] Two-line control panel (File with indicators and time, then View or the manager shown) that the menu, prompts, questions and messages take over; the key bar stays one line (our choice)
- [x] More descriptive key bar labels when the terminal is wide enough ("F8 View manager"); Agenda's short ones otherwise
- [x] Boxes: help for the highlighted field in the control panel (§5)
- [x] Boxes: "Press ENTER when done, ESC to cancel" in the frame, and in every settings box ENTER is done and ESC cancels its changes (ADR 0030); ESC steps back through the menu levels (§5)
- [x] Boxes: moving between settings as Agenda (User's Guide 2-16): → or TAB right one setting, or to the next one when there is none to the right; ← or SHIFT-TAB left, or to the previous one; ↓ ↑ to the setting in the next row nearest the same place (from a right-hand setting to the right-hand one below, else the left); HOME / END the first / last. The rows and places come from the box's layout (`Agendum.TUI.Boxes.Template.grid/2`, `Agendum.TUI.Boxes.BoxNav`); boxes that list one setting a row move down and up with → ←. Choices change with SPACE; numbers and times are typed, no longer → ← (§5)
- [x] Boxes: the first letter of a choice picks it (User's Guide 2-17), and F3 lists a setting's choices (§5)
- [x] Category Properties in two columns, as Agenda's (screenshot 74), drawn from a layout; a box opened from a box sits two columns right of it whatever their widths
- [x] "..." for Category Properties' sub-boxes, as Agenda: Note, Statistics (Agenda's Category Statistics box, new) and Advanced settings, opened by SPACE
- [x] Questions as Yes/No boxes, as Agenda's (screenshots 36, 141) (§5)
- [x] View Manager as a box, as Agenda's (screenshot 40) (§5)
- [x] Bug: hint lines inside two settings boxes still gave the keys from before ENTER meant done (§5, ADR 0030): Item Properties said "ENTER edit", Macro Properties "ENTER changes". Fixed by moving both to `Agendum.TUI.Boxes.Box`, whose hint is made from the same keys as the key bar
- [x] Search/Replace in a note: "Replace this occurrence?" as a Yes/No box, as the other questions, placed so that it does not cover the occurrence
- [x] Boxes listing categories (F3 on an item or a section head, the pickers): 13 categories as Agenda's Assignment Profile, however tall the terminal, and never past the bottom of the screen (their frame was cut off)
- [x] File Properties ▸ File statistics: Agenda's File Statistics box (screenshot 140), as Category Statistics
- [x] In notes: F7 Mark, F3 Copy, F4 Cut, ALT-F4 Delete, F2 Paste, and their key bar (R63)
- [x] Word wrap in the note editor (R64): long lines shown whole on several rows, wrapped at the rightmost space, for the screen only; ↑↓ by rows, HOME/END the row's ends then the line's
- [x] Startup (R52): a splash screen laid out as Agenda's (a cyan box in a solid blue frame with a shadow, the title spaced out, the release, Name and Company lines) with Title "WOL'S AGENDUM", Tagline "Hoo's in control? You are." and Copyright "Copyright JW&D + WOL. All rites reserved."; then a File Retrieve box when no file is named

### Milestone 3 — Smarter assignment

- [x] Numeric categories and columns with totals (R29)
- [x] Display % of total: a "% tot" column beside a numeric column, each number's share of its section's total (R29)
- [x] Date and numeric filters (R28a)
- [x] Sorting by a line of a category note (R36)
- [x] Sorting section heads (R36)
- [x] Date parsing from item text into When (R14)
- [x] Times of day on When dates (R14b)
- [x] Recurring dates; marking a recurring item done creates the next one (R14a)
- [x] More date phrases: working days, quarters, "first Wednesday in November", months alone (R14d)
- [x] Global date settings: week, quarter and year boundaries, month alone, times of day (R14e)
- [x] "$Monday" fixed relative dates in ranges; When dates from notes (R14f)
- [x] Date categories the user makes: Type ▸ Date in Category Properties, converting children to dates (R6a)
- [x] Date category settings: Assign item date, Which one (the nth date in the text), Done and When keys (R6b)
- [x] Item dependencies: ALT-O makes an item depend on the marked items, views can hide dependent items (R43)
- [x] Show Prereqs / Show Depends in the Show View (R43)
- [x] Item Properties lists the items an item depends on, and those depending on it, by name (R43)
- [x] More date display options: per-column formats, display date/time, Day #, Week #, Relative, am/pm, hm (R41a)
- [x] Date input format: number order, input date separator, input clock, as personal preferences (R41b)
- [x] Assignment conditions, conditional assignments (R15)
- [x] Date and numeric conditions, re-checked when the date changes (R15a)
- [x] "Also match" text conditions (R15d)
- [x] Actions: assign, remove, date, numeric, special (done, discard) (R15b)
- [x] Utilities Execute: apply conditions and actions to existing items (ALT-E, ALT-X) (R15e)
- [x] Break text-match assignments when the text changes (R15c)
- [x] Assignment questions: Confirm assignments, Utilities Questions (R16)
- [x] Text matching settings: on/off, match on, match strength, "Sometimes" confirm, ignore enclosed text, suffixes and accents (R16a)
- [x] Text matching per category: Advanced settings, "T= Note" (R16b)
- [x] Proper names and titles in text matching ("Mrs. Wohl" matches Nancy Wohl) (R16c)

### Milestone 4 — Data interchange

- [x] JSON export/import: the modern, human-readable format; round-trips everything in a file (R44, `docs/JSON_FORMAT.md`)
- [x] iCal import: subscribe to calendars on the web, read on a schedule or on request, mirrored into items (R45)
- [x] Time zones in calendar subscriptions: a time with a TZID is converted by the calendar's own `VTIMEZONE` definitions (offsets and yearly daylight-saving rules or RDATEs, `Agendum.Core.ICal.TimeZone`) to UTC, then to local time; a zone the calendar does not define stays local time; no package (ADR 0021) (R45)

### Milestone 5 — Time management and automation

- [x] Datebook views: items by day, week, month or quarter, browsing forward and back (ALT-B); settings Date and End category, Section, Period, Interval, Start and End at, Base date on (R47)
- [x] Browse standard views and sections with date filters: ALT-B shifts the filters by a day (← →), week (CTRL-← → or ↑↓), month (PGUP/PGDN) or year (CTRL-PGUP/PGDN); ENTER keeps, ESC restores (R48)
- [x] Show Schedule (Search ▸ Schedule; Agenda's Utilities Show Sched): one date's items, optionally filtered, in the Show View (R49)
- [x] Pop-up calendar: F3 in a date column picks a date, ALT-C shows one for reference; F6 a time, typing jumps to a date (R46)
- [x] Learn-mode macros (Working with Macros, chapter 1), in three steps (R50):
  - [x] Macros in the file (name, keys, attached key, where they can run), stored in Agenda's key notation (`{F10}vc{ENTER}Hello{AltF2}`); file format and JSON (R50)
  - [x] ALT-F3 macro manager: name a macro, F7 learns (LEARN), ALT-F3 stops; ENTER runs, ALT-Z runs the last; a run plays the keys through the shell one by one (effects in between) and is one undo step; runaway guard (call depth); replace or append when learning again (R50)
  - [x] F2 edits the macro's text (note editor), F6 Properties (attach to key, run from views / notes / category manager / everywhere else), attached keys and their key-bar names, {CALL Name}, DEL, ALT-F5 sort, ALT-↑↓ move
  - Not planned now: the macro command language (chapters 2–3), external `.MAC` files, protection
- [x] A starter file like Agenda's Activities Planner: categories and views, no items (Starter Applications), bundled as a file the user copies (`starters/planner.agendum`, built from code); needs columns per section, note-line columns, hide column heads and section separators (Milestone 2) (R60)
  - [x] Its categories, with short names, Also match, conditions and Amount's action (`Agendum.Starters.Planner`)
  - [x] Its views: the 16 of Agenda's View Manager, and Contacts (`Planner.Views`); the sample data adds contact items and sections for its people and trip
  - [x] Its keystroke macros: Customize date settings, Hide/Display done items, Print current view (`Planner.Macros`; through Agendum's menus, without Agenda's {ALERT} boxes)
  - [x] `mix agendum.starters` writes `starters/planner.agendum`; `--samples` writes a copy with realistic sample data for testing (`tmp/planner-samples.agendum`; dates from `--today`, so the same day gives the same file)
  - [x] `starters/planner.agendum` committed; a test checks it is what the code builds; the README says to copy it
  - Left out: the macros Sort items in view and Create/Update contact list, which need the macro command language. The Contacts view that Create/Update contact list made is in the file instead, but it is not kept up to date: a new person needs a blank item in it by hand
- [x] An Easter egg and showcase: `agendum --clinic` opens Christopher Robin's psychotherapy clinic for the Hundred Acre Wood, mid-work (after Shea et al., CMAJ 2000, `docs/reference/1557.full.pdf`); `mix agendum.starters --clinic` writes it (`Agendum.Starters.Clinic`)
- [x] Themes from terminal colour schemes (`docs/THEMES.md`): Modus Operandi, Modus Vivendi, Alabaster, Zenburn, Ayu, Borland; the old `blue` theme removed (R40)
- [x] Preferences file and File ▸ Customize (Utilities Customize): theme, date languages, input format (R40, R14c, R41b)
- [x] More preferences (R54): key map on/off, kept (ALT-K); confirm mode; auto-save interval; decimal and thousands separators (Setting Up Agenda 1-25 to 1-31). Custom colours are not planned: we keep to themes (ADR 0022)
- [x] Select File box (R51): pick a file from a list instead of typing its name, for File ▸ Retrieve (ALT-G, CTRL-O) and Write, and Transfer ▸ Import/Export: the folders and files of the current folder, ENTER opens a folder or chooses a file, `..` goes up, typing narrows the list; F7 shows dates, as Agenda's Select File box did (User's Guide 22-4 to 22-5)
- [x] Typing in the view manager highlights a view (R53)

### Housekeeping

- [x] Move the TUI's direct `Database` writes into `Agendum.Core` operations (enforced by `architecture_test.exs`)
- [x] Resolve existing conflicts when making children exclusive, as Agenda 2.0 does (R7a)
- [x] Resolve conflicts when moving categories into exclusive families, as Agenda 2.0 does (R7b)
- [x] Enforce "no direct assignment to both a category and its ancestor", including in moves (R7c)
- [x] Outline-style promote/demote: a promoted category adopts its following siblings (R7d)
- [x] Documentation: a hierarchical overview of the different TUI screens and boxes (`docs/SCREENS.md`)
- [x] Developer tools: a screen with debugging info and a key tester, on a hidden key (ESC ?)
- [x] A debug log of each session when `AGENDUM_LOG` is set: keys, effects, messages and crashes with the state; the last five sessions kept (ADR 0027)
- [x] The name Wol's Agendum: command, files (`.agendum`), preferences, JSON format, texts; the old names still read (ADR 0019)
- [x] Rename the code to match: the Mix app `:agenda` → `:agendum`, the `Agenda.*` modules → `Agendum.*`, `lib/agendum` and `test/agendum`; files saved with the old struct names still load (ADR 0019)
- [x] Group the small TUI modules in subfolders: `tui/boxes/`, `tui/terminal/`, `tui/typing/`, `tui/moves/` (ARCHITECTURE.md, TUI)
- [x] Draw the settings boxes from layouts (`Agendum.TUI.Boxes.Template`): every box with fixed settings is (REFACTORING.md step 3); the lists draw their own rows
- [x] Every box in a module of its own behind `Agendum.TUI.Boxes.Box` (keys, drawing, key bar, help, ending), then the fallbacks removed from Update, Render.Boxes, FieldHelp, BoxCancel and BoxChoices ([`docs/plans/REFACTORING.md`](plans/REFACTORING.md) step 3)
- [x] The plans (`GITHUB.md`, `DOSBOX_STAGING.md`, `KITTY.md`, `RENAME_REPO.md`, `WOL-IN-THE-MACHINE.md`, `MULTIUSER.md`, `REFACTORING.md`) moved to `docs/plans/`, so `docs/` is what Agendum is; a group of their own, Plans, in the generated docs (REFACTORING.md step 5)
- [x] Split the four largest files into subfolders, by the sections they already have; pure moves, no change in behaviour, one file per commit (best in a fresh session each):
  - [x] `tui/render.ex` (~2,300 lines) → `tui/render/`: `Render` keeps `render/1`; `ControlPanel`, `KeyBar`, `View`, `Managers`, `Note`, `Help`, `Boxes` and `CategoryBoxes`, `Text` (shared words), `Export`
  - [x] `tui/update.ex` (~2,000) → `tui/update/`: `Update` keeps `handle/2`, `tick/2`, dispatch, effect results and the help screen's keys; `ViewKeys`, `Editing`, `Marked` (with moving items), `Prompts`, `Notes`, `Actions` (prepares the command layer, ADR 0020)
  - [x] `tui/category_screens.ex` (~1,200) → `tui/category_screens/`: `CategoryScreens` keeps opening, rows, cursor, collapsing, inline edits and dispatch; `Manager`, `Picker`, `Profile`, `Choices` (the choice boxes: exclusive children, moves, type, Learn, view type), `Properties`
  - [x] `core.ex` (~2,300, the facade) → `core/facade/`: `Agendum.Core` stays the one entry point (rule 3) as a table of contents of `defdelegate`s to area modules, where the functions and their docs live: `Files`, `Items`, `Assignments`, `Dates`, `Alarms`, `Numbers`, `Dependencies`, `Rules` (actions, text matching, conditions, Execute, Recalc), `Categories`, `Views`, `Macros`, `Calendars`; `Changes` keeps what every change to an item goes through (dates, settling)
- [x] `--rabbit` opens Rabbit's file from the manual (garden, Notices, friends and relations; `Agendum.Sample.rabbit/1`, shared with the manual's screen captures); `--demo` stays the patent's sample, which the tests use
- [x] API documentation with `ex_doc` (dev only): `mix docs` from the `@moduledoc`s and `@spec`s, for whoever builds on the core facade (ADR 0020)
- [x] The real Agenda for Claude to try (done differently: headless DOSBox Staging driven through its REST API, `tools/agformat/agenda_driver.py`; colours and pixels still need the owner's screenshots). First planned as DOSBox Staging started by a script, keys sent with its `AUTOTYPE`, the window captured with `screencapture`, to check Agenda's behaviour and compare screens without asking the owner for screenshots (plan and what the owner sets up: [`docs/plans/DOSBOX_STAGING.md`](plans/DOSBOX_STAGING.md))
- [x] Quicker answers to keys (2026-10-15): input already waiting is answered with one drawing, and the first bytes of an escape sequence draw nothing; `Database.waiting?/2` no longer walks every item for each item shown (drawing was quadratic in items). The debug log notes answers of 100 ms or more and names the file in use
- [x] The lag felt in the --clinic file (2026-10-15, 0.2.1): a view filtered by date words (Overdue, "..yesterday") read them for every item on every key, each reading compiling all the date-language rules (~200 ms update + 75 ms draw per ↓). The view model now reads them once (`Assign.resolve_ranges/3`): ~4 + 2.5 ms
- [x] A quicker lone ESC (2026-10-15): the wait for the rest of an escape sequence is 25 ms, not 40
- [x] The two fuzz failures seen once (2026-10-14 and -15) closed: seven `FUZZ_RUNS=3000` sweeps (seeds 21–27, 21,000 runs) with the whole output kept had no failure and no stack trace, as nine earlier sweeps. The fuzz now runs ~30% faster (date filters read once). Keys split across reads got a property of their own (`Agendum.TUI.KeysPropertyTest`), which the fuzz never reached: it found ESC ESC [ then A (ALT-↑, Option as Meta) read as ESC and ↑, fixed
- [x] Debug log for lag hunts (2026-10-15, 0.2.1): the build commit in the header, the file's fingerprint on disk, the view and memory with each slow answer, effects timed

### Beyond Agenda

- [x] Dates in other languages: `--lang=swedish`, `--fallback=english`; Swedish (R14c)
- [x] General negative links between any two categories, from the patent: Category Properties ▸ Excludes (R9)
- [x] Fit column to contents (R22a): a command (View ▸ Column) that sets the highlighted column's width to fit its head and the entries of the items shown at that moment; a one-time adjustment, not kept in step as items change

### Towards many users

- [x] In the TUI: help made from the commands and keymaps (R65, ADR 0033), 2026-10-15/16
  - [x] F1 shows a text about where you are: the view, a note, a manager, the menu, a move, or the box on top (`about/0` per place, `Box.about/2` per box, a default one for the others); the owner's idea
  - [x] F1 then `c`: the commands that can run there, local then global, with keys and summaries; typing narrows the list, ENTER runs the highlighted one
  - [x] F1 then `d`: describe key (the macro attached to it, the command it runs there, what an alias stands for)
  - [x] F1 then `a`: every key, generated from the keymaps (almost everywhere first, then the view, the note, typing, the rest), so it cannot drift from them
  - [x] KEYBOARD.md checked against the keymaps (a test: every F-, ALT- and CTRL-key in them is in it)
  - [x] F1 then `c` greys the commands that cannot run now and says why (R65a), 2026-10-16
  - [x] Longer texts for the commands, shown by F1 `c` and `d` (R65b), 2026-10-16
  - [x] The help page's look and feel (R65c, 2026-10-16): the same frame on every page, colours from the theme, a fixed pane of five lines at the foot with the longer text and the "Not now" reason (← → page through a long text), "…" for a long summary; drawn as a box over the faded screen beneath, taking more of a small screen (80×25: about nine tenths) than of a large one (four fifths). To try with the owner: the colours
  - Dropped (owner, 2026-10-16): the help as a panel over the right-hand side. The help box over the faded screen (R65c) keeps what it was opened from in sight, which was the panel's point
