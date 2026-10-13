# Roadmap

Small, testable increments. Tick a box when its tests pass under `mix check`.
Rule numbers refer to `SPEC.md`.

## Milestone 1 — Foundation ✅

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

## Milestone 2 — Fidelity

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
- [ ] Original keys that need new features: ALT-F9 copy item, ALT-Y yank back removed item, ALT-H hop to next occurrence, ALT-F7 make item from note text, ALT-F2 make category from note text (R42)
- [ ] Columns per section (User's Guide 3-16, 3-27, 5-22 to 5-25): a column belongs to one section or to all; File ▸ Properties ▸ Insert new columns in (All sections / Current section), overridden when adding; linked columns (Column Properties ▸ Link with other sections) change together; removing asks all sections or this one. Existing files load with every column in every section, linked
- [ ] Note-line columns (Column Properties ▸ Format: Category note, Line number, Column title): a column showing line N of the note of the item's category in that family, as Agenda's Activities Planner shows Phone # and Company from a person's note
- [ ] Hide column heads (View Properties): a view without its column heads, as Agenda's datebooks are
- [ ] Section separators (View Properties): a line between sections, the section head on it

## Look and feel — after screenshots of Agenda 2.0 (ADR 0018)

The general look and feel of the real program, step by step; not pixel fidelity.
`tools/screenshots/` draws our screens for comparison.

- [x] Agenda's colours as the default theme: grey screen, blue heads and entries, white-on-red highlight, cyan boxes in a solid blue frame with a centred title and a shadow, the screen behind a box greyed out, cyan category manager, yellow-on-blue help; exact VGA colours on 24-bit terminals; the old look as `blue`; the highlighted line tinted (R40)
- [x] Two-line control panel (File with indicators and time, then View or the manager shown) that the menu, prompts, questions and messages take over; the key bar stays one line (our choice)
- [x] More descriptive key bar labels when the terminal is wide enough ("F8 View manager"); Agenda's short ones otherwise
- [ ] View layout and symbols: no "Section:" line, a blank line between sections; ‼ done, ♪ note; exclusive families bracketed (┌ ├ └); * date categories and datebook views; the category manager without counts and tags
- [ ] Boxes: help for the highlighted field in the control panel, "Press ENTER when done, ESC to cancel" in the frame; ESC steps back through the menu levels
- [ ] Questions as Yes/No boxes; Category Properties in two columns with "..." sub-boxes opened by SPACE; View Manager as a box
- [ ] Editing: the prompt and input field in the control panel (EDIT), editing key bars (F2 Paste, F3 Copy, F4 Cut, F7 Mark); the note editor's "Note for: … Line 1 INS EDIT" header
- [ ] The ALT and CTRL key bars while the key is held (kitty keyboard protocol), and after ESC as a prefix
- [x] Startup (R52): a splash screen laid out as Agenda's (a cyan box in a solid blue frame with a shadow, the title spaced out, the release, Name and Company lines) with Title "WOL'S AGENDUM", Tagline "Hoo's in control? You are." and Copyright "Copyright JW&D + WOL. All rites reserved."; then a File Retrieve box when no file is named
- [ ] Hypertext help: topics with links (TAB, ENTER), Index, Find, Review (Agenda's F1)

## Milestone 3 — Smarter assignment

- [x] Numeric categories and columns with totals (R29)
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

## Milestone 4 — Data interchange

- [x] JSON export/import: the modern, human-readable format; round-trips everything in a file (R44, `docs/JSON_FORMAT.md`)
- [x] iCal import: subscribe to calendars on the web, read on a schedule or on request, mirrored into items (R45)
- [ ] Time zones in calendar subscriptions: an event with a TZID is now taken as local time, so a calendar from another zone shows the wrong hours; read the calendar's own `VTIMEZONE` definitions (offsets and daylight-saving rules) in `Agenda.Core.ICal` and convert to local time, with no package (ADR 0021)
- [ ] Optional: Agenda structured files (`.STF`): import and export as Agenda 2.0's File Transfer does (Working with Definition Files, Appendix B; User's Guide chapters 23–24), so legacy users can bring old files over via DOS Agenda's export. Read both 2.0 dates (`{C}\When@|10%/31%/1990`) and 1.x dates (`{W}10/31/90`) into the same When/Entry/Done categories (Lotus Q&A "Date Categories are Duplicated")
- [ ] Optional: Import of structured text files (one item per line, with categories)
- [ ] Optional: TXT2STF-style definition files that turn plain text into items (Working with Definition Files)
- [ ] Optional: read original `.AG` files directly (format undocumented; research; STF covers most needs)

## Milestone 5 — Time management and automation

- [x] Datebook views: items by day, week, month or quarter, browsing forward and back (ALT-B); settings Date and End category, Section, Period, Interval, Start and End at, Base date on (R47)
- [x] Browse standard views and sections with date filters: ALT-B shifts the filters by a day (← →), week (CTRL-← → or ↑↓), month (PGUP/PGDN) or year (CTRL-PGUP/PGDN); ENTER keeps, ESC restores (R48)
- [x] Show Schedule (Search ▸ Schedule; Agenda's Utilities Show Sched): one date's items, optionally filtered, in the Show View (R49)
- [x] Pop-up calendar: F3 in a date column picks a date, ALT-C shows one for reference; F6 a time, typing jumps to a date (R46)
- [x] Learn-mode macros (Working with Macros, chapter 1), in three steps (R50):
  - [x] Macros in the file (name, keys, attached key, where they can run), stored in Agenda's key notation (`{F10}vc{ENTER}Hello{AltF2}`); file format and JSON (R50)
  - [x] ALT-F3 macro manager: name a macro, F7 learns (LEARN), ALT-F3 stops; ENTER runs, ALT-Z runs the last; a run plays the keys through the shell one by one (effects in between) and is one undo step; runaway guard (call depth); replace or append when learning again (R50)
  - [x] F2 edits the macro's text (note editor), F6 Properties (attach to key, run from views / notes / category manager / everywhere else), attached keys and their key-bar names, {CALL Name}, DEL, ALT-F5 sort, ALT-↑↓ move
  - Not planned now: the macro command language (chapters 2–3), external `.MAC` files, protection
- [ ] A starter file like Agenda's Activities Planner: categories and views, no items (Starter Applications), bundled as a file the user copies (`starters/planner.agendum`, built from code); needs columns per section, note-line columns, hide column heads and section separators (Milestone 2)
- [x] Preferences file and File ▸ Customize (Utilities Customize): theme, date languages, input format (R40, R14c, R41b)
- [x] More preferences (R54): key map on/off, kept (ALT-K); confirm mode; auto-save interval; decimal and thousands separators (Setting Up Agenda 1-25 to 1-31). Custom colours are not planned: we keep to themes (ADR 0022)
- [x] Select File box (R51): pick a file from a list instead of typing its name, for File ▸ Retrieve (ALT-G, CTRL-O) and Write, and Transfer ▸ Import/Export: the folders and files of the current folder, ENTER opens a folder or chooses a file, `..` goes up, typing narrows the list; F7 shows dates, as Agenda's Select File box did (User's Guide 22-4 to 22-5)
- [ ] Smaller fidelity items: Trash and Undiscard, File Abandon, unindexed categories
- [x] Typing in the view manager highlights a view (R53)
- [ ] Alarms sent to your phone with Signal, as well as on the screen: through the separate `signal-cli` program, linked to your Signal account; optional (nothing changes without it), set up in File ▸ Customize

## Housekeeping

- [x] Move the TUI's direct `Database` writes into `Agenda.Core` operations (enforced by `architecture_test.exs`)
- [x] Resolve existing conflicts when making children exclusive, as Agenda 2.0 does (R7a)
- [x] Resolve conflicts when moving categories into exclusive families, as Agenda 2.0 does (R7b)
- [x] Enforce "no direct assignment to both a category and its ancestor", including in moves (R7c)
- [x] Outline-style promote/demote: a promoted category adopts its following siblings (R7d)
- [x] Documentation: a hierarchical overview of the different TUI screens and boxes (`docs/SCREENS.md`)
- [x] Developer tools: a screen with debugging info and a key tester, on a hidden key (ESC ?)
- [x] The name Wol's Agendum: command, files (`.agendum`), preferences, JSON format, texts; the old names still read (ADR 0019)
- [ ] Rename the code to match: the Mix app `:agenda` → `:agendum`, the `Agenda.*` modules → `Agendum.*`, `lib/agenda` and `test/agenda`, the repository folder; one mechanical commit (ADR 0019); with it, group the small TUI modules in subfolders (e.g. `tui/boxes/`, `tui/terminal/` for Terminal, Keys, Screen, Draw and Theme), so module names change only once
- [ ] Draw the settings boxes from layouts (`Agenda.TUI.Template`, as File ▸ Customize is now), a few at a time and with the split of `render.ex`; their layouts closer to Agenda's screenshots where that is easy (e.g. Category Properties in two columns)
- [ ] Split the four largest files into subfolders, by the sections they already have; pure moves, no change in behaviour, one file per commit (best in a fresh session each):
  - `tui/render.ex` (~2,300 lines) → `tui/render/`: `Render` keeps `render/1`; `ControlPanel`, `KeyBar`, `View`, `Managers`, `Note`, `Help`, `Boxes` (perhaps two, or each box module drawing its own content, as `SelectFile` does), `Export`
  - `tui/update.ex` (~2,000) → `tui/update/`: `Update` keeps `handle/2`, `tick/2`, dispatch and effect results; `ViewKeys`, `Editing`, `Marked`, `Prompts`, `Notes`, `Actions` (prepares the command layer, ADR 0020)
  - `tui/category_screens.ex` (~1,200) → `tui/category_screens/`: `Manager`, `Picker`, `Profile`, `Moves`, `Properties`
  - `core.ex` (~2,300, the facade) → `Agenda.Core` stays the one entry point (rule 3) as a table of contents of `defdelegate`s to area modules (`Agenda.Core.Facade.Items`, `.Dates`, `.Rules`, `.Views`, `.Numbers`…), where the functions and their docs live
- [x] `--rabbit` opens Rabbit's file from the manual (garden, Notices, friends and relations; `Agenda.Sample.rabbit/1`, shared with the manual's screen captures); `--demo` stays the patent's sample, which the tests use
- [x] API documentation with `ex_doc` (dev only): `mix docs` from the `@moduledoc`s and `@spec`s, for whoever builds on the core facade (ADR 0020)

## Beyond Agenda

- [x] Dates in other languages: `--lang=swedish`, `--fallback=english`; Swedish (R14c)
- [x] General negative links between any two categories, from the patent: Category Properties ▸ Excludes (R9)
- [ ] More date languages (one `Agenda.Core.DateLanguage` pack each)
- [x] Fit column to contents (R22a): a command (View ▸ Column) that sets the highlighted column's width to fit its head and the entries of the items shown at that moment; a one-time adjustment, not kept in step as items change
- [ ] Modern by default: today's names and standard keys out of the box (Open not Retrieve, Delete not Discard, CTRL-O/S/Z/F/N…), with Agenda's names and keys one setting away ("Agenda mode"). Agenda's steep learning curve limited its audience (AGENDA_HISTORY.md); the power should stay, the strangeness should not be the first thing people meet. Builds on the keymaps, self-describing commands and own key bindings (Towards many users); departs from ADR 0006 and 0007, so it needs an ADR of its own
- [ ] Flashcards with active recall and spaced repetition: an item is the question, its note the answer; a deck is any category. The schedule is kept in ordinary categories made the first time (date category Due; numeric Interval, Ease and Reviews), so filters, datebooks, sorting and JSON work on cards as they are, with no new stored fields. A review mode on the due items: the question, SPACE shows the note, then Again / Hard / Good / Easy sets the next Due date (one undo step per card). Scheduling is SM-2 to begin with, in a pure core module with the clock passed in, behind an interface that FSRS could replace
- [ ] A micro-blog from the file: the items of a chosen category (e.g. Posts) are posts, the item the title, the note the content (a Markdown subset), When the date (else Entry). File ▸ Transfer ▸ Publish writes a static site: an index page newest first, a page per post and an RSS feed (`rss.xml`), plain HTML without JavaScript. The site's title, base address (for the feed's links) and author are kept in the file. The pages are made in a pure core module (`{path, html}` pairs); the shell writes them to a folder, and can then sync the folder to a server with `rsync` over `ssh` (the person's own keys; nothing is stored by Agendum; optional, nothing changes without rsync). Markdown: a small subset of our own, or Earmark if it passes ADR 0021
- [ ] Zettelkasten IDs and links between items: every item gets an ID when it is made, its creation time as YYMMDDHHMM plus a digit that counts up only when two items are made in the same minute (`26101311140`); stored with the item and never changed (items from older files get one from their Entry date on load). A column kind shows it. `[[26101311140]]` in an item's text or note is a link: shown as typed in the link colour, the target's text in the control panel when the cursor is on it, a broken link marked. Following a link (a key to choose, with a Mac-friendly alternative) shows the target in the Show View (ALT-F8 back); Item Properties lists the items that link to it ("Linked from"), and a search lists them in the Show View. A key inserts a link to the marked item. Text matching ignores links. In the published micro-blog a link is an `<a>` to the target's page, or its title in plain text if the target is not published. Ours, not Agenda's; a stored field (DATA_MODEL, JSON schema, format version)

## Towards many users

A web application with accounts and shared files, on the same core (plan:
[MULTIUSER.md](MULTIUSER.md), ADR 0020). First, in the core and the TUI, a
few commands at a time:

- [ ] A command layer: one named command per user action, applied by the core. Existing actions move over a few at a time; done when `Agenda.TUI.Update` only turns keys into commands and has no logic of its own (an architecture test then keeps it so)
- [ ] Commands that describe themselves (name, summary, documentation, global or local, available now), keys bound through keymaps
- [ ] In the TUI: a command list of what can run here (local, then global) with keys and summaries, and "describe key"; the F1 help and KEYBOARD.md checked against the keymaps
- [ ] Customizable key bindings: the person's own bindings, per place or everywhere, kept in the preferences and set in File ▸ Customize ▸ Keys; they come before macro keys and Agenda's keys; ESC, F1, the command list and describe key cannot be rebound
- [ ] Raw values (dates, numbers) beside the formatted cells in `Agenda.Core.ViewModel`
- [ ] Browsing's date arithmetic into the core
- [ ] Split the TUI state into the shared database and the session (modes, view, cursor, typing)

Then a web version for one person:

*[A page here was soaked in the creek. — Rabbit]*

Then working together:

*[A page here was soaked in the creek. — Rabbit]*

## Ideas

- Multiple files open; a launcher listing recent files
