# Reverse engineering Agenda's .AG format: methods and progress

2026-10-14 · Claude, for Mattias Jämting

The lab notebook behind [AGENDA_FILE_FORMAT.md](../AGENDA_FILE_FORMAT.md):
what was tried, with which tools, how far it got, and what to do next. The
goal is importing old Agenda files into Agendum; this stage only describes
the format.

**Status (2026-10-15, after the second round):** research done; next, the
importer (ROADMAP, Data interchange; "Next steps" below). The format is mapped as
far as an import needs, and most of the rest: items, notes and note files,
categories with every setting of their properties boxes, conditions,
actions and special actions, assignments with date, numeric and unindexed
values, relative and recurring date expressions, alarms, views with their
flags, sort keys, filters and date ranges, datebook views, sections,
columns with widths and formats, and the file-level settings in the
header. A reference reader (`tools/agformat/agdump.py`) decodes all of it
for every file at hand. What is left open is listed at the end of the
format document; none of it is needed to import.

## Prior art

A web search found no description of the binary `.AG` format.

- Agenda can export to **STF** ("structured file", File Transfer Export), a
  tagged text format half documented in _Working with Definition Files_,
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

| #   | Change                                                            | What it showed                                                                                                                                                                               |
| --- | ----------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| e0  | new empty file                                                    | the minimal file: 38 blocks (system categories, MAIN, Entry/When/Done, Initial View and Section, summary rows, settings); 8 links                                                            |
| x1  | items "Alpha", "Beta"                                             | items are type-1 blocks with text at byte 50; each gets two assignment links (Entry with a date, Initial Section), threaded on an item list and a category list                              |
| x2  | 118-character item, note of two lines                             | text continues in type-2 blocks, 55 characters + NUL each; notes are a type-7 header plus a text chain, lines separated by CR                                                                |
| x3  | categories Fruit > Apple, Pear; items "Apple pie", "Banana split" | the category tree words (parent, first/last child, previous/next sibling); "Apple pie" was assigned to Apple by text matching (link flag 1); type-9 links form an AVL tree of category names |
| x4  | "Call Bob tomorrow at 3pm"; another item marked done (F4)         | When and Done are assignments to date categories with a type-12 date value; the date found in the text gets flag `0x40`                                                                      |
| x5  | "every Monday at 10am", "on 11/20/26", "next Friday"              | date value layout: absolute date at bytes 18–25; bytes 10–17 hold a date expression for relative dates                                                                                       |
| p2  | Planner: expense item, Amount 42,50                               | numeric values are a double inside the link (flag `0x80`); "Taxi" matched Transportation (flag 1); "No Purpose" came from a condition (flag 2)                                               |
| i1  | Information Sifter: Issue 11/02/26, Page "B12-14"                 | custom date category value (flag `0x100`); unindexed value text in a type-8 block (flag `0x180`)                                                                                             |
| pw1 | new file with password "abc", one item                            | the password is in the header XOR `0xAB`; nothing else changes, the data is not encrypted                                                                                                    |
| x6  | discard an item (ALT-F4)                                          | discarded items stay, assigned only to `!Trash!`                                                                                                                                             |
| STF | File Transfer Export of the Planner with categories               | category types and properties (`MCN`, `MSN`, `CP`, `CHC`, conditions) to match against the binary: w26 = type, w28 bits = match name/short name, w19 = conditions                            |

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

## Second round (2026-10-14/15, overnight)

The owner asked for the complete format while they slept. About 150 more
experiments, all on copies in the session's scratch directory.

### What changed in the method

- **Save instead of quit.** File Save writes a complete file while Agenda
  keeps running (the owner suggested it). One Agenda session now runs
  dozens of experiments: change one setting, save, copy the file, diff
  against the previous save. A box setting costs about 8 seconds instead
  of a DOSBox restart each.
- **Fields by label.** The current field of a settings box is drawn with
  attribute `0x3F`; reading those characters gives its label, so scripts
  say `setf("Hide done items")` instead of counting ↓ presses, and print
  the field's new value next to the diff as a check.
- **Many dates in one go.** Date expressions were decoded by typing ~70
  items such as "Qab next monday at 9am" into one file and saving once;
  Agenda reads the date out of the text into When. (Item names with digits,
  like "T04", were themselves read as times; letters only.)
- **Robustness.** Keys are occasionally lost, the web server sometimes
  stalls, and an interrupted script leaves a box open for the next one to
  type into. Every experiment now starts from the main view (`home()`),
  every save checks the screen after each key, HTTP calls time out and
  retry, and long batches run in the background one step per line in a
  log. All of this is written down for next time in
  `tools/agformat/DRIVING_AGENDA.md`, and the helpers are in
  `agenda_driver.py`.

### Experiments

| Area | What was changed | What it showed |
| ---- | ---------------- | -------------- |
| View Properties | each Yes/No and choice field | the view flags in w20/w21; protection also marks the sections |
| Item sorting | sort on category / item text / category note, order, n/a's, sequence, sort new items, secondary key | type-8 links are **sort keys** (the first round had guessed "date filters"); view w10/w11; flags in the link's w9 |
| Filter | include, exclude, a date category with absolute and relative ranges, inside/outside | type-2 links are **filter elements**; type-13 blocks are **date ranges** holding two date expressions |
| Date expressions | ~70 phrases (today, next monday, end of next month, every other monday at 9am, in 5 working days, nov 20 …) | the 8-byte expression: unit, index/position, count, day/interval, "this", time |
| Category Properties | match name/short name, exclusive children, special actions, type | the match bits are "off" bits (the first round had them the other way round); special actions in the type-5 block |
| Advanced settings | every field of a standard, a date and a numeric category | w23, w26, w28, w29, w30; date categories form a linked list (w28/w29) |
| Section Properties | sorting, filter | the same sort-key and filter records, owned by the section |
| Column Properties | a numeric and a date column; every format field; width | numeric format in w11, date format in w10, statistics in a type-11 block |
| Assignment actions | assign Tgt, break Initial Section | type-7 links; category w8/w9 list every reference to a category |
| Note file, alarm | attach `NOTE1.TXT`; Item Alarm 5 minutes before When | note header w9 = 1 with the file name; alarm = assignment to `!Current Alarms!` + type-13 link |
| File Properties | every field and the three sub-boxes | header words `0x5E`–`0x98`, `0x186`–`0x194` |
| Datebook view | add one, change the period | stored fully materialized: a section per day with a date-range filter |
| Utilities Customize, Print | one field each | Customize is not in the file; print layout is a data block |

Checked against the screen: the Planner's views decode to what Agenda
shows (Activities sorts on When ascending; Completed This Week filters
Done to this week; Overdue keeps When up to yesterday).

### Corrections to the first round

- Type-8 links are sort keys, not date filters; type-2 links are filter
  elements; type 13 is a date-range block and also an alarm link type.
- Category w28: `0x08`/`0x10` turn matching on the name/short name **off**.
  For date categories w28 is the previous date category, not settings.
- Category w8/w9 list all references (filters, conditions, actions), not
  only conditions.
- Free blocks keep their number in word 0 (type 0).

## Progress

| Area                                            | State                                  |
| ----------------------------------------------- | -------------------------------------- |
| Container: header, blocks, link pages, trailer  | done                                   |
| Free lists                                      | done                                   |
| Text, notes, note files, long names             | done                                   |
| Items and assignments                           | done                                   |
| Category tree, names, types, notes, settings    | done                                   |
| Date, numeric, unindexed values                 | done                                   |
| Relative and recurring date expressions         | done                                   |
| Views: flags, sorting, filters, date ranges     | done                                   |
| Datebook views                                  | done (settings; generated sections)    |
| Sections, columns, column formats               | done                                   |
| Assignment conditions, actions, special actions | done                                   |
| Alarms                                          | done                                   |
| Password                                        | done (not encryption)                  |
| Discarded items                                 | done                                   |
| File settings in the header                     | done, a few words open                 |
| Macro variables (type 12), family blocks (9)    | open (not needed for import)           |

## Next steps

1. **An importer.** A reader in Elixir following "Reading a file" in the
   format document, outside the pure core (it reads a file), converting
   to the existing JSON format. `agdump.py`'s JSON output is a good
   intermediate to design the mapping against.
2. **Real files.** If the owner has old personal `.AG` files, run
   `agdump.py --check` on them; anything unexpected shows up as an error
   or an unknown value. An Agenda 1.0 file would show whether the format
   changed between versions.
3. **Open details** (only if an import turns out to need them): macro
   variable values, family settings blocks, the time-format word of date
   columns. Each is one short session with the harness described in
   `tools/agformat/DRIVING_AGENDA.md`.
