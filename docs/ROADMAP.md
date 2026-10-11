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
- [ ] Startup: a splash screen, and a File Retrieve box when no file is named
- [ ] Hypertext help: topics with links (TAB, ENTER), Index, Find, Review (Agenda's F1)
- [ ] Splash screen as original Agenda. Title: "WOL'S AGENDUM" Tagline: "Hoo's in control? You are." Copyright: "Copyright JWD + WOL. All rites reserved. "

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
- [ ] Optional: Agenda structured files (`.STF`): import and export as Agenda 2.0's File Transfer does (Working with Definition Files, Appendix B; User's Guide chapters 23–24), so legacy users can bring old files over via DOS Agenda's export. Read both 2.0 dates (`{C}\When@|10%/31%/1990`) and 1.x dates (`{W}10/31/90`) into the same When/Entry/Done categories (Lotus Q&A "Date Categories are Duplicated")
- [ ] Optional: Import of structured text files (one item per line, with categories)
- [ ] Optional: TXT2STF-style definition files that turn plain text into items (Working with Definition Files)
- [ ] Optional: read original `.AG` files directly (format undocumented; research; STF covers most needs)

## Milestone 5 — Time management and automation

- [ ] Datebook views: items by day, week, month or quarter, browsing forward and back (ALT-B); settings Period, Interval, Base date on, Section separators; beginning/end of week in the global date settings (User's Guide chapter 10)
- [ ] Pop-up calendar: F3 in a date column picks a date (User's Guide chapter 6)
- [ ] Learn-mode macros: record keystrokes, store them in the file, replay them, attach them to keys (Working with Macros, chapter 1)
- [ ] A starter file like Agenda's Activities Planner: categories and views, no items (Starter Applications)
- [x] Preferences file and File ▸ Customize (Utilities Customize): theme, date languages, input format (R40, R14c, R41b)
- [ ] More preferences: custom colours, key map on/off (ALT-K), confirm mode, auto-save interval, decimal and thousands separators (Setting Up Agenda 1-25 to 1-31)
- [ ] Select File box: pick a file from a list instead of typing its name, for File ▸ Retrieve (ALT-G, CTRL-O) and Write, and Transfer ▸ Import/Export: the folders and files of the current folder, ENTER opens a folder or chooses a file, `..` goes up, typing narrows the list; F7 shows dates, as Agenda's Select File box did (User's Guide 22-4 to 22-5)
- [ ] Smaller fidelity items: Trash and Undiscard, File Abandon, unindexed categories, typing in the view manager jumps to a view

## Housekeeping

- [x] Move the TUI's direct `Database` writes into `Agenda.Core` operations (enforced by `architecture_test.exs`)
- [x] Resolve existing conflicts when making children exclusive, as Agenda 2.0 does (R7a)
- [x] Resolve conflicts when moving categories into exclusive families, as Agenda 2.0 does (R7b)
- [x] Enforce "no direct assignment to both a category and its ancestor", including in moves (R7c)
- [x] Outline-style promote/demote: a promoted category adopts its following siblings (R7d)
- [x] Documentation: a hierarchical overview of the different TUI screens and boxes (`docs/SCREENS.md`)
- [x] Developer tools: a screen with debugging info and a key tester, on a hidden key (ESC ?)
- [x] The name Wol's Agendum: command, files (`.agendum`), preferences, JSON format, texts; the old names still read (ADR 0019)
- [ ] Rename the code to match: the Mix app `:agenda` → `:agendum`, the `Agenda.*` modules → `Agendum.*`, `lib/agenda` and `test/agenda`, the repository folder; one mechanical commit (ADR 0019)

## Beyond Agenda

- [x] Dates in other languages: `--lang=swedish`, `--fallback=english`; Swedish (R14c)
- [x] General negative links between any two categories, from the patent: Category Properties ▸ Excludes (R9)
- [ ] More date languages (one `Agenda.Core.DateLanguage` pack each)
- [ ] Fit column to contents: a command (View ▸ Column) that sets the highlighted column's width to fit its head and the entries of the items shown at that moment; a one-time adjustment, not kept in step as items change

## Ideas

- Multiple files open; a launcher listing recent files
- Create a web application using the functional core as backend, and not using the TUI
