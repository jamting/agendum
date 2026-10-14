# Reverse engineering Agenda's .AG format: methods and progress

2026-10-14 · Claude, for Mattias Jämting

The lab notebook behind [AGENDA_FILE_FORMAT.md](../AGENDA_FILE_FORMAT.md):
what was tried, with which tools, how far it got, and what to do next. The
goal is importing old Agenda files into Agendum; this stage only describes
the format.

**Status:** enough is known to import items (text, notes), categories (tree,
names, short names, text conditions, types, notes), assignments with their
date, numeric and unindexed values, and views with sections and columns. A
reference reader (`tools/agformat/agdump.py`) does this for every file at
hand. View sorting/filters, relative dates, actions and some settings are
still open (see the end).

## Prior art

A web search found no description of the binary `.AG` format.

- Agenda can export to **STF** ("structured file", File Transfer Export), a
  tagged text format half documented in *Working with Definition Files*,
  Appendix B. Tavis Ormandy's `stfjson` (github.com/taviso/stfjson) and
  `jimcollinsworth/new-agenda` read STF; neither reads `.AG`. STF is a
  fallback import path for anyone who still has Agenda running, and it was
  useful here as ground truth: it names each category's properties, which
  could then be matched against the bits in the binary.
- IBM's Lotus FTP mirror (public.dhe.ibm.com/software/lotus/desktop/Agenda)
  has the disk images and the Update B kit, no format notes.
- The Agenda patent (US 5,115,504) describes the data model (items,
  categories, links), not the file. It matched what the bytes showed: a
  sparse matrix of item-category links.

## Material

- `docs/reference/agendafiles/`: the four starter applications shipped with
  Agenda 2.0 (ACCOUNT, INFOSIFT, PEOPLE, PLANNER), dated 1990-10-23, plus a
  definition file, a text file and a macro file. The `.AG` files are
  templates: categories, views and macros, but almost no items.
- The owner's Agenda 2.0 install in DOSBox (`~/Dosbox/APPS/AGENDA`), with a
  Planner file the owner had used. **Every experiment ran on a copy** in the
  session's scratch directory; nothing in `~/Dosbox` was changed.

## Method

### 1. Look at the bytes

`xxd` and `strings` showed at once that the files are not encrypted: names,
macros and the description appear in clear. The header starts with `T\0`
and the description. File sizes are all 512·k + 8 (or + 10), which hinted
at 512-byte pages plus a small trailer.

Splitting everything after offset `0x400` into 64-byte pieces made the
structure visible: each piece starts with its own number, then a type, then
two more small numbers, the classic layout of a C program's record pool
(`struct { short id, type, next, prev; char data[56]; }`). The marker
`FF FF "LINKS" FF` every 512 bytes near the end showed a second region of
28-byte records. Eight-byte values like `8E E3 38 8E 92 30 E0 40` decode as
doubles around 33,000: days since 1899-12-30, the Lotus 1-2-3 date, which
put the starter files in October 1990.

### 2. Make Agenda an oracle (headless DOSBox)

Guessing from four templates only goes so far. The key step was running the
real program, unattended, to make files that differ in exactly one thing:

- **DOSBox Staging 0.83** (already installed) runs without a window with
  `SDL_VIDEODRIVER=dummy`, and has a REST API (`[webserver]
  webserver_enabled=true`, port 8765):
  - `GET /api/v1/memory/0xB8000/4000` returns the text screen (character
    and attribute bytes), so the program's screen can be read as text, and
    the highlighted row found by its attribute;
  - `PUT /api/v1/memory/<addr>` with `{"data": base64}` writes memory. Keys
    are typed by writing scan code/ASCII words into the BIOS keyboard
    buffer (`0040:001E`–`003D`, head `0040:001A`, tail `0040:001C`). Agenda
    reads keys through the BIOS, so every key works, F-keys included.
- `AGENDA NAME` on the DOSBox command line opens or creates
  `C:\APPS\AGENDA\NAME.AG` directly.
- This is packaged as `tools/agformat/agenda_driver.py` (start, `keys`,
  `screen`, `select` a row by its text, quit). Point `AGENDA_DOS_ROOT` at a
  copy of the install.

One lesson: while a file is open, the `.AG` on disk is Agenda's working
file and may be stale. Snapshots were therefore taken only after **Quit**
(F10 q), when Agenda writes the complete file with its trailer.

### 3. Experiments (one change each, then diff)

Each started from a copy of the same empty file (`e0`: a new file with the
description "Empty test").

| #   | Change                                                     | What it showed |
| --- | ---------------------------------------------------------- | -------------- |
| e0  | new empty file                                             | the minimal file: 38 blocks (system categories, MAIN, Entry/When/Done, Initial View and Section, summary rows, settings); 8 links |
| x1  | items "Alpha", "Beta"                                      | items are type-1 blocks with text at byte 50; each gets two assignment links (Entry with a date, Initial Section), threaded on an item list and a category list |
| x2  | 118-character item, note of two lines                      | text continues in type-2 blocks, 55 characters + NUL each; notes are a type-7 header plus a text chain, lines separated by CR |
| x3  | categories Fruit > Apple, Pear; items "Apple pie", "Banana split" | the category tree words (parent, first/last child, previous/next sibling); "Apple pie" was assigned to Apple by text matching (link flag 1); type-9 links form an AVL tree of category names |
| x4  | "Call Bob tomorrow at 3pm"; another item marked done (F4) | When and Done are assignments to date categories with a type-12 date value; the date found in the text gets flag `0x40` |
| x5  | "every Monday at 10am", "on 11/20/26", "next Friday"       | date value layout: absolute date at bytes 18–25; bytes 10–17 hold a date expression for relative dates |
| p2  | Planner: expense item, Amount 42,50                        | numeric values are a double inside the link (flag `0x80`); "Taxi" matched Transportation (flag 1); "No Purpose" came from a condition (flag 2) |
| i1  | Information Sifter: Issue 11/02/26, Page "B12-14"          | custom date category value (flag `0x100`); unindexed value text in a type-8 block (flag `0x180`) |
| pw1 | new file with password "abc", one item                     | the password is in the header XOR `0xAB`; nothing else changes, the data is not encrypted |
| x6  | discard an item (ALT-F4)                                   | discarded items stay, assigned only to `!Trash!` |
| STF | File Transfer Export of the Planner with categories        | category types and properties (`MCN`, `MSN`, `CP`, `CHC`, conditions) to match against the binary: w26 = type, w28 bits = match name/short name, w19 = conditions |

### 4. Check against the real thing

- Views decoded from the Planner starter were compared with Agenda's screen:
  the Tasks view's columns and widths (Activity 8, People 7, Project 8,
  When 17) and the View Manager's 16 view names match.
- `agdump.py --check` walks every list in every file at hand (4 starters,
  13 experiment files, the owner's used Planner) and checks each assignment
  points at a category block and an item block: no errors.
- The owner's own Planner file reads correctly: 10 items with their
  categories and a note, Swedish letters intact ("Följ upp en artikel som
  jag läst", "Call Göran").

## Progress

| Area                                   | State |
| -------------------------------------- | ----- |
| Container: header, blocks, link pages, trailer | done |
| Text, notes, long names                | done |
| Items and assignments                  | done |
| Category tree, names, types, notes, match flags | done |
| Date, numeric, unindexed values        | done (relative-date encoding open) |
| Views, sections, columns (order, width) | done |
| Assignment conditions                  | structure known |
| Password                               | done (not encryption) |
| Discarded items                        | done |
| View sort/filter/display settings      | open |
| Actions, datebook ranges, block types 11/12 | open |
| Category flags word w23, date-category settings | partly |
| Program settings in the header         | open (not needed for import) |

## Next experiments

Each is a short script with `agenda_driver.py`: make the change in a copy of
`e0` (or a starter), quit, diff.

1. **View settings.** Change one setting at a time in View Properties (sort
   by, sort order, hide done items, filter) and in Section Properties; diff
   view words w10–w21 and section words w10 and on.
2. **Relative and recurring dates.** Type When dates in a column ("every
   Monday", "first of every month", "in 3 days") and decode bytes 10–17 of
   the date value.
3. **Category properties.** Toggle each setting in Category Properties
   (exclusive children, match category name, assign conditions, date
   settings) and watch w23 and w28.
4. **Actions.** Give a category an assignment action; decode the type-7
   links.
5. **Note files and alarms.** Attach a note file to an item; set an alarm.
6. **Bigger files.** If the owner has old personal `.AG` files, run
   `agdump.py --check` on them; differences from the starters would show up
   as errors. An Agenda 1.0 file would show whether the format changed
   between versions.

For import into Agendum, a reader in Elixir would follow
"Reading a file" in the format document; it belongs outside the pure core
(it reads a file) and could convert to the existing JSON format.
