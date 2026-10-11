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
- [ ] Date input format settings (R41)
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

- [ ] JSON export/import: the modern, human-readable format; round-trips everything in a file
- [ ] Agenda structured files (`.STF`): import and export as Agenda 2.0's File Transfer does (Working with Definition Files, Appendix B; User's Guide chapters 23–24), so legacy users can bring old files over via DOS Agenda's export. Read both 2.0 dates (`{C}\When@|10%/31%/1990`) and 1.x dates (`{W}10/31/90`) into the same When/Entry/Done categories (Lotus Q&A "Date Categories are Duplicated")
- [ ] Import of structured text files (one item per line, with categories)
- [ ] Optional: TXT2STF-style definition files that turn plain text into items (Working with Definition Files)
- [ ] Optional: read original `.AG` files directly (format undocumented; research; STF covers most needs)

## Milestone 5 — Time management and automation

- [ ] Datebook views: items by day, week, month or quarter, browsing forward and back (ALT-B); settings Period, Interval, Base date on, Section separators; beginning/end of week in the global date settings (User's Guide chapter 10)
- [ ] Pop-up calendar: F3 in a date column picks a date (User's Guide chapter 6)
- [ ] Learn-mode macros: record keystrokes, store them in the file, replay them, attach them to keys (Working with Macros, chapter 1)
- [ ] A starter file like Agenda's Activities Planner: categories and views, no items (Starter Applications)
- [ ] Preferences (Utilities Customize), stored outside the file: theme and custom colours, key map on/off (ALT-K), confirm mode, auto-save interval, decimal and thousands separators (Setting Up Agenda 1-25 to 1-31)
- [ ] Smaller fidelity items: Trash and Undiscard, File Abandon, unindexed categories, typing in the view manager jumps to a view

## Housekeeping

- [x] Move the TUI's direct `Database` writes into `Agenda.Core` operations (enforced by `architecture_test.exs`)
- [x] Resolve existing conflicts when making children exclusive, as Agenda 2.0 does (R7a)
- [x] Resolve conflicts when moving categories into exclusive families, as Agenda 2.0 does (R7b)
- [x] Enforce "no direct assignment to both a category and its ancestor", including in moves (R7c)
- [x] Outline-style promote/demote: a promoted category adopts its following siblings (R7d)
- [ ] Documentation: Make a hiearchical overview of the different TUI screens and boxes

## Beyond Agenda

- [x] Dates in other languages: `--lang=swedish`, `--fallback=english`; Swedish (R14c)
- [x] General negative links between any two categories, from the patent: Category Properties ▸ Excludes (R9)
- [ ] More date languages (one `Agenda.Core.DateLanguage` pack each)

## Ideas

- Multiple files open; a launcher listing recent files
- Create a web application using the functional core as backend, and not using the TUI
