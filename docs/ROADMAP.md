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
- [ ] Autocompletion while typing column entries (Agenda's AUTOC indicator)
- [ ] Collapse/expand families in the category manager (ALT− / ALT+)
- [ ] Item properties box (F6 on an item), as well as the profile
- [ ] Marked items: bulk assign / discard / move
- [ ] Section sorting (ALT-F5 SORT) and per-section filters (R28)
- [ ] Search (ALT-F6 SEARCH)
- [ ] Show the time in the title bar; alarms (When date reached)
- [ ] Configurable colours / monochrome theme; date format setting

## Milestone 3 — Smarter assignment
- [ ] Date parsing from item text into When (R14)
- [ ] Assignment conditions and actions (R15)
- [ ] General negative links (R9)
- [ ] Assignment questions ("Agenda suggests…", Utilities Questions)
- [ ] Numeric categories and columns with totals (R29)

## Milestone 4 — Data interchange
- [ ] Human-readable export/import (JSON or a structured text format)
- [ ] Import of structured text files (one item per line, with categories)
- [ ] Optional: read original `.AG` files (format undocumented; research)

## Housekeeping
- [x] Move the TUI's direct `Database` writes into `Agenda.Core` operations (enforced by `architecture_test.exs`)
- [x] Resolve existing conflicts when making children exclusive, as Agenda 2.0 does (R7a)
- [ ] Moving a category under an exclusive parent can put items in two branches (`DATA_MODEL.md`, invariant 5)

## Ideas
- Multiple files open; a launcher listing recent files
