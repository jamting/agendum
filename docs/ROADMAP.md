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
- [ ] Configurable colours / monochrome theme; date format setting
- [x] Show a category's short name in columns too narrow for its full name (e.g. "Anna" instead of "Anna Las") (R22)

## Milestone 3 — Smarter assignment

- [ ] Numeric categories and columns with totals (R29)
- [ ] Date and numeric filters; sorting by category note; sorting section heads (after R29)
- [x] Date parsing from item text into When (R14)
- [x] Times of day on When dates (R14b)
- [ ] More date phrases: recurring dates, working days, date settings (R14a)
- [x] Assignment conditions, conditional assignments (R15)
- [ ] Date conditions and "Also match" text conditions (R15a)
- [ ] Actions: remove, date, special (done, discard, export) (R15b)
- [ ] Break text-match assignments when the text changes (R15c)
- [ ] General negative links (R9)
- [ ] Assignment questions ("Agenda suggests…", Utilities Questions)

## Milestone 4 — Data interchange

- [ ] Human-readable export/import (JSON or a structured text format)
- [ ] Import of structured text files (one item per line, with categories)
- [ ] Optional: read original `.AG` files (format undocumented; research)

## Housekeeping

- [x] Move the TUI's direct `Database` writes into `Agenda.Core` operations (enforced by `architecture_test.exs`)
- [x] Resolve existing conflicts when making children exclusive, as Agenda 2.0 does (R7a)
- [x] Resolve conflicts when moving categories into exclusive families, as Agenda 2.0 does (R7b)
- [x] Enforce "no direct assignment to both a category and its ancestor", including in moves (R7c)
- [x] Outline-style promote/demote: a promoted category adopts its following siblings (R7d)

## Ideas

- Multiple files open; a launcher listing recent files
- Create a web application using the functional core as backend, and not using the TUI
