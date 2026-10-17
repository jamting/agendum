# Plan: Agendum as close to Agenda as it makes sense (2026-10-15)

**Status:** under way: about 80% overall on 2026-10-15; the next major work, now that the command layer is done (ROADMAP, **Next:**, 2026-10-16). The steps are tracked in ROADMAP ("Towards parity with Agenda"); keep the two lists below complete.

The ambition: someone who knew Lotus Agenda 2.0 sits down at Agendum and finds the same screen, the same keys, the same menus and the same behaviour, apart from a list of **accepted enhancements** (things Agenda did not have) and **accepted modifications** (things Agenda had that Agendum does differently, for a reason). Everything else that differs is a gap, to be closed or moved onto one of the two lists on purpose.

This overview starts with the main control panel (the two top lines, the key bar and the F10 menu), checked in the real Agenda 2.0 run headless on a copy of PLANNER (2026-10-15: every menu level walked without running a command; the view's screen read) and its F1 help ("About Indicators", "Mode & Message Indicators", "View Indicators"). The note editor has its own plan: [`NOTE_EDITOR.md`](NOTE_EDITOR.md). Agenda's menus as they are, for reference: `docs/reference/AGENDA_MENUS.md`.

Out of scope, as SPEC §6 says: printing on paper and print preview (F10 Print and everything under it), typesetting (fonts, attributes), networks and file reservations, application protection, the macro command language, DOS itself (System, Compress).

## The control panel's two lines

|               | Agenda                                                                                                    | Agendum                                                                                                               |
| ------------- | --------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Line 1, left  | `File: C:\APPS\AGENDA\MN`                                                                                 | `File: <path>`, `(untitled)` for a new file, ` *` while unsaved                                                       |
| Line 1, right | the indicators, then `10/15/26 11:22am`                                                                   | the indicators, a mode word (`READY` when nothing else), then the date and time in the file's format (ISO by default) |
| Line 2, left  | `View: People [-Contact List]` (the view's filter)                                                        | the same; `Category Manager`, `Help` in those screens (a note has `Note for:   …` or `Edit macro:  …` on line 1 with `Line N INS EDIT`, as Agenda, R64a) |
| Line 2, right | `[Hide Done]` and the other hide settings; `Datebook for: …`                                              | the same, and `[No Auto Dates]` (ours) and ♪                                                                          |
| Taken over by | the menu (its entries, then the highlighted one's help), prompts, questions, messages, a box's field help | the same                                                                                                              |

### Mode and message indicators (top right)

| Agenda               | Meaning                                   | Agendum                                                                                   |
| -------------------- | ----------------------------------------- | ----------------------------------------------------------------------------------------- |
| AUTOC                | automatic completion                      | ✅                                                                                        |
| BROWSE               | browsing by date                          | ✅                                                                                        |
| EDIT                 | editing text                              | ✅                                                                                        |
| LEARN                | Learn mode                                | ✅                                                                                        |
| INS / OVR            | insert / overwrite in a note              | ⬜ (note editor plan, step 5)                                                             |
| WAIT / WRKG          | busy / working in the background          | ⬜ (could show while a calendar is fetched)                                               |
| READONLY             | no reservation on a network file          | – out of scope                                                                            |
| DEBUG                | debugging a macro                         | – out of scope (macro language)                                                           |
| DISK!, DMGD!, LIMIT! | disk full, file damaged, file near 5.5 MB | – no counterpart (no size limit; damage shows as a load error)                            |
| (none when ready)    |                                           | ours: READY, MENU, MOVE, SEARCH, CAT MGR, NOTE, HELP, PROPS, ASSIGN, CHOICES … (modified) |

### Symbols in the control panel

| Agenda                                                                | Meaning                                      | Agendum                                      |
| --------------------------------------------------------------------- | -------------------------------------------- | -------------------------------------------- |
| ▸ (t)                                                                 | the view has marked items                    | ✅ as ♦                                      |
| ♪ (j)                                                                 | the highlighted item or category has a note  | ✅                                           |
| ♫ (jj)                                                                | … has an external note file                  | ⬜ (note editor plan, step 7)                |
| @                                                                     | an alarm has sounded                         | ✅                                           |
| *                                                                     | the highlight is on a date category or value | ⬜                                           |
| #                                                                     | … on a numeric category or value             | ✅ (numeric columns)                         |
| D                                                                     | … on an unindexed category or value          | ⬜ (unindexed categories are on the roadmap) |
| ?                                                                     | unconfirmed text assignments                 | ✅                                           |
| o                                                                     | circular conditions or actions               | ⬜ (with Show Circular)                      |
| `[category]`, `[-category]`, value ranges                             | the view's filter                            | ✅                                           |
| `[Hide Empty]`, `[Hide Done]`, `[Hide Dependent]`, `[Hide Inherited]` | hide settings                                | ✅                                           |

## The key bar

|                     | Agenda                                                                                             | Agendum                                                                             |
| ------------------- | -------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| In a view           | F1 Help, F2 Edit, F3 Choices, F4 Done, F5 Note, F6 Props, F7 Mark, F8 Vw Mgr, F9 Cat Mgr, F10 Menu | the same keys and labels; longer labels when the screen is wide ("F8 View manager") |
| Layout              | two lines, ten fixed slots                                                                         | one line (modified, ours)                                                           |
| Holding ALT or CTRL | the ALT and CTRL key bars                                                                          | none: F1's help lists the commands and keys instead (modified, ours)               |
| ALT-K               | hide / show the key map                                                                            | ✅                                                                                  |

## The F10 menu, command by command

✅ there (the place may differ), ½ there in part or another way, ⬜ missing, – out of scope or no counterpart.

| Agenda                                            | Agendum                                                                                                                                                                                                          |                                                         |
| ------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------- |
| **File** Retrieve (ALT-G)                         | File ▸ Retrieve (CTRL-O); asks about unsaved changes instead of saving                                                                                                                                           | ½ modified                                              |
| File Save (ALT-W)                                 | File ▸ Save (CTRL-S)                                                                                                                                                                                             | ✅                                                      |
| File Abandon                                      | –                                                                                                                                                                                                                | ⬜ (roadmap: smaller fidelity items)                    |
| File Properties                                   | File ▸ Properties: Insert new columns in, Global date settings, Auto-assign settings, File statistics; not File description, password, backup on open, empty trash, tab size, global protection, update defaults | ½ (roadmap)                                             |
| File Transfer Import / Export (structured `.STF`) | File ▸ Transfer ▸ Import / Export (JSON)                                                                                                                                                                         | ½ modified (`.AG` import done, R72; STF on the roadmap) |
| File Transfer Template                            | – (copy the structure without the items)                                                                                                                                                                         | ⬜                                                      |
| File Maintenance MakeCopy                         | File ▸ Write (save under a new name, and go on in it)                                                                                                                                                            | ½ modified                                              |
| File Maintenance Erase                            | –                                                                                                                                                                                                                | ⬜                                                      |
| File Maintenance Compress                         | –                                                                                                                                                                                                                | – no counterpart                                        |
| File Maintenance Reservation                      | –                                                                                                                                                                                                                | – out of scope                                          |
| **Item** Properties (F6)                          | Item ▸ Properties                                                                                                                                                                                                | ✅                                                      |
| Item MakeAssign (ALT-M)                           | Item ▸ Categorize (ALT-M)                                                                                                                                                                                        | ✅ renamed                                              |
| Item Discard (ALT-F4)                             | Item ▸ Discard                                                                                                                                                                                                   | ✅                                                      |
| Item Undisc (ALT-Y)                               | – (ALT-Y yanks back what DEL removed)                                                                                                                                                                            | ⬜ (with the trash)                                     |
| Item BrkAssign (DEL)                              | DEL                                                                                                                                                                                                              | ✅ key only                                             |
| Item Reposition                                   | Item ▸ Reposition (ALT-F10)                                                                                                                                                                                      | ✅                                                      |
| Item Alarm (ALT-A)                                | Item ▸ Alarm                                                                                                                                                                                                     | ✅                                                      |
| **Category** Properties (F6)                      | F6 on a head or in the manager                                                                                                                                                                                   | ✅ key only                                             |
| Category Add                                      | Category ▸ Add                                                                                                                                                                                                   | ✅                                                      |
| Category Discard (ALT-F4)                         | ALT-F4 in the category manager                                                                                                                                                                                   | ✅ key only                                             |
| **View** Properties (F6)                          | View ▸ Properties for a datebook; a standard view's settings are spread over View ▸ Hide, Filter, Order and Section ▸ Lines                                                                                      | ½ (the View Properties box, screenshot 143, is missing) |
| View Add                                          | View ▸ Add                                                                                                                                                                                                       | ✅                                                      |
| View Browse (ALT-B)                               | View ▸ Browse                                                                                                                                                                                                    | ✅                                                      |
| View Discard                                      | View ▸ Discard                                                                                                                                                                                                   | ✅                                                      |
| View Column Properties, Add, Remove, Move, Width  | View ▸ Column ▸ the same five                                                                                                                                                                                    | ✅                                                      |
| View Section Properties, Add, Remove, Move        | View ▸ Section ▸ Properties, Below, Above, Remove, Move                                                                                                                                                          | ✅                                                      |
| **Print** Final, Preview, Layout, Setup, Named …  | Print: the view to a text file (CTRL-P)                                                                                                                                                                          | – out of scope; ours is an accepted modification        |
| **Utilities** Customize                           | File ▸ Customize                                                                                                                                                                                                 | ✅ moved                                                |
| Utilities Execute (ALT-X)                         | Category ▸ Execute                                                                                                                                                                                               | ✅ moved                                                |
| Utilities Show Match                              | Search ▸ File                                                                                                                                                                                                    | ✅ moved                                                |
| Utilities Show Prereqs, Depends                   | Search ▸ Prereqs, Depends                                                                                                                                                                                        | ✅ moved                                                |
| Utilities Show ItemsDone                          | – (View ▸ Hide ▸ Done hides them)                                                                                                                                                                                | ⬜                                                      |
| Utilities Show Circular                           | –                                                                                                                                                                                                                | ⬜                                                      |
| Utilities Show Alarm                              | Search ▸ Alarms                                                                                                                                                                                                  | ✅ moved                                                |
| Utilities Show Sched                              | Search ▸ Schedule                                                                                                                                                                                                | ✅ moved                                                |
| Utilities Show Every                              | –                                                                                                                                                                                                                | ⬜                                                      |
| Utilities Questions                               | Category ▸ Questions                                                                                                                                                                                             | ✅ moved                                                |
| Utilities Trash                                   | –                                                                                                                                                                                                                | ⬜ (with Undisc)                                        |
| Utilities Launch                                  | – (run a program without quitting)                                                                                                                                                                               | ⬜ optional: a shell, as CTRL-Z suspends                |
| **System** (exit to DOS)                          | –                                                                                                                                                                                                                | – no counterpart                                        |
| **Quit** (ALT-Q; saves automatically)             | Quit (CTRL-Q, ALT-Q); asks about unsaved changes                                                                                                                                                                 | ½ modified                                              |

Not yet compared: the menus of the category manager (Agenda: Category, Print, Return, Quit), the view manager and the macro manager.

## Beyond Agenda: accepted enhancements

What Agendum has that Agenda did not:

- Undo and redo of every change (CTRL-Z, CTRL-Y; R30), on the menu too.
- JSON export and import (R44), a readable file format.
- Calendar subscriptions (iCal, R45) and time zones.
- Date languages, Swedish among them, and the file's date format (ISO 8601 by default; R41).
- Colour themes beyond Agenda's (R40).
- Word wrap in the note editor (R64).
- A count before a command in a view, as Emacs's numeric prefix: ALT-1 ALT-0 ↓ moves ten rows (R65). In Agenda ALT-digits typed DOS character codes.
- Help made from the commands and keymaps (R65): from F1, `c` lists the commands that work there (those that cannot run now greyed, with the reason, R65a; each with a longer text saying why one would use it, R65b), `d` describes a key, `a` lists every key. Agenda's F1 help was a fixed text per screen.
- File ▸ New, File ▸ Dating (When dates from text on or off, shown as `[No Auto Dates]`), Category ▸ Recalc, View ▸ Rename, View ▸ Last, Item ▸ Note / When / Show / Finished / Mark / Unmark on the menu.
- Search this view (ALT-F6 in a view, ALT-N / ALT-P), and the Show View for results.
- Hide column heads (R57) as a view setting.
- The debug log and the developer tools (ALT-?).
- Descriptive key bar labels on a wide screen.
- The `--clinic` Easter egg.
- ► before the current view in the view manager, and F5 to list the views by recently used (R68).
- A "While you were away" box for alarms that came due while the file was closed (R70).
- Zettel ids (Quadsyl-24, R73, ADR 0039), a Zettel id column (R73a) and links between items (R73b).
- A micro-blog published from the file (File ▸ Transfer ▸ Publish, R74).
- Feeds: a plain RSS and Atom reader, the News view, OPML, CTRL-V to open a link (R75).
- CTRL-X runs a command by name, found by part of it or its initials, in a small box (R65d, ADR 0040); F1 `c` narrows the same way.

## Done differently: accepted modifications

What Agenda had that Agendum does another way, on purpose:

- **Saving.** Agenda saves automatically (Quit, Retrieve). Agendum keeps changes until you save and asks before they are lost; ` *` on the File line shows unsaved changes.
- **The menu's shape.** The same commands, regrouped: Agenda's Utilities are spread over File (Customize), Category (Execute, Questions) and a Search menu (the Show commands); Undo and Redo are on the top level; Print writes a text file.
- **Mode words.** Agendum always shows one (READY, MENU, NOTE, PROPS …); Agenda showed none when ready and had fewer.
- **The marked-items symbol** is ♦ (Agenda's ▸ is hard to tell from the cursor in a terminal).
- **The key bar** is one line, names and labels side by side.
- **Boxes**: ENTER keeps and ESC cancels in every settings box (ADR 0030), where Agenda's boxes varied.
- **Retrieve** asks about unsaved changes; **Write** (Save As) takes MakeCopy's place.
- **CTRL keys** for INS, HOME, END and the most used commands (CTRL-N new, CTRL-E edit, CTRL-K done, CTRL-D discard, CTRL-S/O/P/Q save, open, print, quit; R31, KEYBOARD.md), as Mac keyboards lack those keys and terminals can map ⌘ shortcuts onto them. Function keys are required, as in Agenda: there is no ESC + digit stand-in (ADR 0032).
- **Where you left off** (R69, meeting 2026-10-16, § 5): Agenda stored the current view and item in the file; Agendum keeps them in the preferences per file, so moving does not change the file and each person (later, each user) has their own place.
- **No ALT and CTRL key bars** while the key is held (the owner, 2026-10-16): F1's help does it better (R65: `c` lists the commands where you are, greyed with the reason when they cannot run, `d` describes a key, `a` lists every key), and a terminal sees ALT or CTRL held alone only with the kitty keyboard protocol. The research: `archive/KITTY.md`.
- **Export / Import** are JSON, not structured `.STF` files; Import also reads Agenda's own `.AG` files (R72); STF is planned.

Each of these is a candidate for "Agenda mode" (roadmap, Beyond Agenda: Agenda's names and keys one setting away).

## How close: a guesstimate

Counting what is in scope (not printing, networks, protection, the macro language, DOS), and weighing each Agenda command or behaviour about equally:

| Area                                           | Parity                                                                    | What is missing                                                                                                                             |
| ---------------------------------------------- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| The control panel (lines, indicators, key bar) | about 75%                                                                 | INS/OVR, WAIT, the * D o ♫ symbols                                                                                   |
| The F10 menu                                   | about 75% (34 of 46 in-scope commands, counting the partial ones as half) | Abandon, Template, Erase, Undisc and Trash, Show ItemsDone / Circular / Every, Launch, the View Properties box, the rest of File Properties |
| The note editor                                | about 50% (NOTE_EDITOR.md)                                                | its control panel and menu, Import/Export/Clear, ESC's question, the editing keys, APPEND/GETITMS, external note files                      |
| Data model, assignment, views (SPEC R1–R64)    | about 90%                                                                 | recurring items on every date, unindexed categories, the trash, external note files                                                         |
| **Overall**                                    | **about 80%**                                                             |                                                                                                                                             |

These are rough: a count of commands and rules, not of how much each matters. By what people used Agenda for (`docs/AGENDA_HISTORY.md`: free text, automatic assignment, views), Agendum is closer than the menu count says; the gaps are mostly in housekeeping and the editor.

## The steps

To close the gaps or move them onto the lists above on purpose; each one small and test-first, in about this order (the most used first):

1. The note editor plan (`NOTE_EDITOR.md`), from its control panel on.
2. The View Properties box for every view (screenshot 143), so that F6 on the view and View ▸ Properties work as in Agenda; the Hide, Filter and Order entries stay as shortcuts.
3. The trash: Item ▸ Undisc and Utilities ▸ Trash, with File Properties ▸ Empty trash (roadmap: smaller fidelity items).
4. File ▸ Abandon (back to the saved file), File Maintenance Erase, File Transfer Template.
5. Show ItemsDone and Show Every (Show View lists), Show Circular with the `o` indicator.
6. The control panel's `*` (date) symbol, and `WAIT` while a calendar is fetched; `D` with unindexed categories (roadmap).
7. File Properties' other settings (roadmap item), as far as Agendum has them.
8. The category manager's, view manager's and macro manager's menus: compare them with Agenda's in the same way, and add their tables here.
9. Optional: Utilities Launch (a shell without quitting).

When a difference is kept, it goes in the enhancements or modifications list above, so that the lists stay the whole truth.
