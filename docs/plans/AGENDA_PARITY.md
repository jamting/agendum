# Plan: Agendum as close to Agenda as it makes sense (2026-10-15)

**Status:** under way: about 80% overall on 2026-10-15, still about 80% on 2026-10-22 with the note editor's steps done, on 2026-10-23 with View Properties built (R78), and on 2026-10-25 with the key bars, menus and boxes as Agenda's (R80–R81c; "How close", not recounted). Since the meeting of 2026-10-21 (§ 5) this is the work that comes first: a truthful clone, declared done when the steps below are done and every entry on the two lists is tagged and confirmed; "Beyond Agenda" gets bug fixes only until then. The steps are the checklist at the end ("The steps"), the only list of the parity work, which ROADMAP points to; keep the two lists below complete.

**The test for a difference** (ADR 0043, meeting 2026-10-21, § 6): a difference from Agenda 2.0 stays only if **the machine** forces it (keyboards, terminals, sound, files), it protects **the person's work** (undo, asking before changes are lost), or it is **quiet** (an Agenda user who never asks for it never meets it: nothing changed on Agenda's screens, no Agenda key taken, no entry added to Agenda's menus). Anything else is an *extra*, hidden behind the Extras preference (off by default), or is changed back. Each entry on the two lists below has its tag (*machine*, *work*, *quiet*, *extra* or *change back*), confirmed by the owner entry by entry on 2026-10-22; a change back that alters a habit is a roadmap item of its own, settled first. The comparison with Agenda's captured menus (meeting 2026-10-21, § 8) reads these tags as the accepted differences.

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
| INS / OVR            | insert / overwrite in a note              | ✅ (R64e; INS or CTRL-N)                                                                  |
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
| In a view           | F1 Help, F2 Edit, F3 Choices, F4 Done, F5 Note, F6 Props, F7 Mark, F8 Vw Mgr, F9 Cat Mgr, F10 Menu | ✅ the same; with the extras, longer labels when the screen is wide ("View manager") |
| Layout              | two lines, ten fixed slots                                                                         | ✅ in a view, a note and the managers (R80); boxes and the rest one line for now     |
| Holding ALT or CTRL | the ALT, CTRL and SHIFT key bars                                                                   | ✅ ALT-K shows them in turn (machine, below; R80)                                           |
| ALT-K               | hide / show the key map                                                                            | ✅ after the ALT, CTRL and SHIFT keys (machine, below)                              |

## The F10 menu, command by command

✅ there (the place may differ), ½ there in part or another way, ⬜ missing, – out of scope or no counterpart.

| Agenda                                            | Agendum                                                                                                                                                                                                          |                                                         |
| ------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------- |
| **File** Retrieve (ALT-G)                         | File ▸ Retrieve (CTRL-O); a name that is not a file makes a new one, after asking (2026-10-24); asks about unsaved changes instead of saving                                                                     | ½ modified                                              |
| File Save (ALT-W)                                 | File ▸ Save (CTRL-S)                                                                                                                                                                                             | ✅                                                      |
| File Abandon                                      | –                                                                                                                                                                                                                | ⬜ (The steps)                    |
| File Properties                                   | File ▸ Properties: Insert new columns in, Global date settings, Auto-assign settings, File statistics; not File description, password, backup on open, empty trash, global protection, update defaults; Tab size (R64e) | ½ (The steps)                                         |
| File Transfer Import / Export (structured `.STF`) | File ▸ Transfer ▸ Import / Export (JSON)                                                                                                                                                                         | ½ modified (`.AG` import done, R72; STF optional, The steps) |
| File Transfer Template                            | – (copy the structure without the items)                                                                                                                                                                         | ⬜                                                      |
| File Maintenance MakeCopy                         | File ▸ Write (save under a new name, and go on in it)                                                                                                                                                            | ½ modified                                              |
| File Maintenance Erase                            | –                                                                                                                                                                                                                | ⬜                                                      |
| File Maintenance Compress                         | –                                                                                                                                                                                                                | – no counterpart                                        |
| File Maintenance Reservation                      | –                                                                                                                                                                                                                | – out of scope                                          |
| **Item** Properties (F6)                          | Item ▸ Properties                                                                                                                                                                                                | ✅                                                      |
| Item MakeAssign (ALT-M)                           | Item ▸ MakeAssign (ALT-M)                                                                                                                                                                                        | ✅ (2026-10-24)                                         |
| Item Discard (ALT-F4)                             | Item ▸ Discard                                                                                                                                                                                                   | ✅                                                      |
| Item Undisc (ALT-Y)                               | – (ALT-Y yanks back what DEL removed)                                                                                                                                                                            | ⬜ (with the trash)                                     |
| Item BrkAssign (DEL)                              | Item ▸ BrkAssign, DEL                                                                                                                                                                                            | ✅ (2026-10-24)                                         |
| Item Reposition                                   | Item ▸ Reposition (ALT-F10)                                                                                                                                                                                      | ✅                                                      |
| Item Alarm (ALT-A)                                | Item ▸ Alarm                                                                                                                                                                                                     | ✅                                                      |
| **Category** Properties (F6)                      | Category ▸ Properties on a section head (F6 there opens Section Properties), F6 in the manager                                                                                                                   | ✅ (2026-10-24)                                         |
| Category Add                                      | Category ▸ Add                                                                                                                                                                                                   | ✅                                                      |
| Category Discard (ALT-F4)                         | Category ▸ Discard on a section head, ALT-F4 there and in the manager                                                                                                                                            | ✅ (2026-10-24)                                         |
| **View** Properties (F6)                          | View ▸ Properties and F6 in the view manager: the View Properties box of a standard view as Agenda's (R78, 2026-10-23), a datebook's settings for a datebook                                                    | ✅ (Number items since 2026-10-23, R79)                 |
| View Add                                          | View ▸ Add                                                                                                                                                                                                       | ✅                                                      |
| View Browse (ALT-B)                               | View ▸ Browse                                                                                                                                                                                                    | ✅                                                      |
| View Discard                                      | View ▸ Discard                                                                                                                                                                                                   | ✅                                                      |
| View Column Properties, Add, Remove, Move, Width  | View ▸ Column ▸ the same five                                                                                                                                                                                    | ✅                                                      |
| View Section Properties, Add, Remove, Move        | View ▸ Section ▸ Properties, Add (Agenda's Section Add box), Remove, Move                                                                                                                                        | ✅ (2026-10-24)                                         |
| **Print** Final, Preview, Layout, Setup, Named …  | Print: the view to a text file (CTRL-P)                                                                                                                                                                          | – out of scope; ours is an accepted modification        |
| **Utilities** Customize                           | Utilities ▸ Customize                                                                                                                                                                                            | ✅ (2026-10-24)                                         |
| Utilities Execute (ALT-X)                         | Utilities ▸ Execute (ALT-X)                                                                                                                                                                                      | ✅ (2026-10-24)                                         |
| Utilities Show Match                              | Utilities ▸ Show ▸ Match                                                                                                                                                                                         | ✅ (2026-10-24)                                         |
| Utilities Show Prereqs, Depends                   | Utilities ▸ Show ▸ Prereqs, Depends (with One level, All levels, Every item under them)                                                                                                                          | ½ a submenu of levels (2026-10-24)                     |
| Utilities Show ItemsDone                          | – (View Properties ▸ Hide done items hides them)                                                                                                                                                                                | ⬜                                                      |
| Utilities Show Circular                           | –                                                                                                                                                                                                                | ⬜                                                      |
| Utilities Show Alarm                              | Utilities ▸ Show ▸ Alarm                                                                                                                                                                                         | ✅ (2026-10-24)                                         |
| Utilities Show Sched                              | Utilities ▸ Show ▸ Sched                                                                                                                                                                                         | ✅ (2026-10-24)                                         |
| Utilities Show Every                              | –                                                                                                                                                                                                                | ⬜                                                      |
| Utilities Questions                               | Utilities ▸ Questions                                                                                                                                                                                            | ✅ (2026-10-24)                                         |
| Utilities Trash                                   | –                                                                                                                                                                                                                | ⬜ (with Undisc)                                        |
| Utilities Launch                                  | – (run a program without quitting)                                                                                                                                                                               | ⬜ optional: a shell, as CTRL-Z suspends                |
| **System** (exit to DOS)                          | –                                                                                                                                                                                                                | – no counterpart                                        |
| **Quit** (ALT-Q; saves automatically)             | Quit (CTRL-Q, ALT-Q); asks about unsaved changes                                                                                                                                                                 | ½ modified                                              |

Since 2026-10-23 the menus are captured from Agenda itself (`tools/agformat/capture_menus.py`, `docs/reference/agenda_menus.json`), and `test/agendum/tui/agenda_menus_test.exs` compares Agendum's with them, with the Extras preference off: every difference is listed there with its tag, so a new one or a fixed one fails the test. The category manager's menu (Category ▸ Properties, Add [INS], Discard; Print; Return [F9]; Quit) is captured too; Agendum has none yet (F10 there returns to the view), tagged not built. Not yet compared: the view manager's and the macro manager's.

## Beyond Agenda: accepted enhancements

What Agendum has that Agenda did not. The entries tagged **extra** are hidden while the Extras preference is off, as it is by default (R77, built 2026-10-23). Each entry carries its tag by ADR 0043's test, proposed by Claude and confirmed by the owner entry by entry in the tagging sitting of 2026-10-22 (meeting 2026-10-22, § 5b): **machine**, **work** or **quiet** stay; **extra** is hidden behind the Extras preference; **change back** is a roadmap item of its own (ROADMAP, Towards parity).

- **work** · Undo and redo of every change (CTRL-Z, CTRL-Y; R30), on their keys only since the menu took Agenda's shape (2026-10-24).
- **machine** · JSON export and import (R44), a readable file format.
- **extra** · Calendar subscriptions (iCal, R45) and time zones.
- **quiet** · Date languages, Swedish among them (R41): English is the default.
- **change back** · The file's date format defaults to ISO 8601 (R41). New files get Agenda's MM/DD/YY; ISO stays one of Agenda's own choices (YYYYMMDD with "-"), and files keep the format they have.
- **quiet** · Colour themes beyond Agenda's (R40): Agenda's colours are the default.
- **machine** · Word wrap in the note editor (R64). Agenda wrapped notes too, at 79 characters (User's Guide, importing a note); Agendum wraps at the window's width, the same on an 80-column screen.
- **machine** · A count before a command in a view, as Emacs's numeric prefix: ALT-1 ALT-0 ↓ moves ten rows (R65). In Agenda ALT-digits typed DOS character codes, which a terminal cannot.
- **quiet, once Agenda's help is built** · Help made from the commands and keymaps (R65): from F1, `c` lists the commands that work there (those that cannot run now greyed, with the reason, R65a; each with a longer text saying why one would use it, R65b), `d` describes a key, `a` lists every key. Agenda's F1 help was a fixed text per screen; the step "Agenda's help, in our own words" (The steps, Help) makes Agenda's help the front, with `c`, `d` and `a` reached from it.
- **quiet** · The debug log and the developer tools (ALT-?).
- **extra** · Descriptive key bar labels on a wide screen.
- **quiet** · The `--clinic` Easter egg (reached only by a command-line flag).
- **extra** · ► before the current view in the view manager, and F5 to list the views by recently used (R68).
- **extra** · A "While you were away" box for alarms that came due while the file was closed (R70). Agenda rings such alarms when the file is opened and shows `@`, with no box (checked in Agenda 2.0, 2026-10-22: an alarm due at 10:04pm, the file closed, opened at 10:05pm); the items are in Utilities ▸ Show Alarm's Past Alarms, which Agendum is to get (ROADMAP).
- **extra** · Zettel ids (Quadsyl-24, R73, ADR 0039), a Zettel id column (R73a) and links between items (R73b).
- **extra** · A micro-blog published from the file (File ▸ Transfer ▸ Publish, R74).
- **extra** · Feeds: a plain RSS and Atom reader, the News view, OPML, CTRL-V to open a link (R75).
- **quiet** · The Extras row in File ▸ Customize (R77): the switch that hides every entry tagged *extra* above, off by default (the owner chose the Customize box and confirmed the tag, 2026-10-23). A row Agenda's Customize box did not have, met only by someone who opens Customize and looks for it.
- **quiet** · ALT-↑ and ALT-↓ in View Properties' Sections (R78) move the highlighted section a place at once, as they move a column in Section Properties; Agenda's ALT-F10 (pick it up, ↑ ↓, ENTER) works as well (the owner chose both and the tag, 2026-10-23). Keys Agenda's box did not use, met only by someone who presses them.
- **quiet** · CTRL-X runs a command by name, found by part of it or its initials, in a small box (R65d, ADR 0040), a key Agenda left unused; F1 `c` narrows the same way.

Off the list since the tagging sitting, as no difference from Agenda: **search** (ALT-F6, ALT-N / ALT-P and the Show View for results) is Agenda's own ALT-F6 SEARCH in views and notes, with its Match show view (Agenda's F1 help); comparing it with Agenda's Search box is parity work (ROADMAP). **Hide column heads** (R57) is a setting of Agenda's own View Properties box (checked in Agenda 2.0, 2026-10-22).

## Done differently: accepted modifications

What Agenda had that Agendum does another way, on purpose. Tagged as the enhancements above, 2026-10-22.

- **work** · **Saving.** Agenda saves automatically (Quit, Retrieve). Agendum keeps changes until you save and asks before they are lost; ` *` on the File line shows unsaved changes.
- **machine** · **Sounds** (R76). Agenda's own tones, through the computer's audio player rather than the PC speaker (the terminal's bell where there is none); every error message beeps with the one error beep, where Agenda also had a shorter one; Sound in File ▸ Customize silences them all.
- **change back** · **The key bar outside a view, a note and the managers** (boxes, the menu, typing a line, moves, prompts) is one line of hints naming any key (`↑↓←→ Setting SPACE Open … F3 Choices`); Agenda's has its ten F-key slots there too (Item Properties: Help, Edit, Choices, Props, Default). Comes back with the texts step (The steps); the view's, the note's and the managers' are Agenda's since R80.
- **change back** · **Mode words.** Agendum always shows one (READY, MENU, NOTE, PROPS …); Agenda showed none when ready and had fewer.
- **machine** · **The marked-items symbol** is ♦ (Agenda's ▸ is hard to tell from the cursor in a terminal).
- **Boxes** (ADR 0030): ENTER keeps and ESC cancels in every settings box, as Agenda's frame says, so that part is no difference. Checked in Agenda 2.0, 2026-10-22, three differences remain:
  - **change back** · Agenda's category lists opened from a box (a view's Filter, the Assignment Profile, conditions, Excludes) say "Press ENTER to accept", SPACE switches a category, and ENTER and ESC both close the list keeping the change; Agendum's say "Press ESC when done", and in some ENTER switches a category.
  - **work** · ESC in a box puts back everything done since it opened, changes made in its category lists included; Agenda's ESC kept those.
- **work** · **Retrieve** asks about unsaved changes. **change back**: **Write** (Save As) gives way to Agenda's File ▸ Maintenance ▸ MakeCopy, a copy under another name.
- **machine** · **CTRL keys** for INS, HOME, END and the most used commands (CTRL-N new, CTRL-E edit, CTRL-K done, CTRL-D discard, CTRL-S/O/P/Q save, open, print, quit; R31, KEYBOARD.md), as Mac keyboards lack those keys and terminals can map ⌘ shortcuts onto them. Function keys are required, as in Agenda: there is no ESC + digit stand-in (ADR 0032).
- **quiet** · **Where you left off** (R69, meeting 2026-10-16, § 5): Agenda stored the current view and item in the file; Agendum keeps them in the preferences per file, so moving does not change the file and each person (later, each user) has their own place.
- **machine** · **No CTRL-ENTER in boxes** (Agenda's "clear the setting", User's Guide 2-17; the owner, 2026-10-24): terminals send CTRL-ENTER as ENTER. F8 clears a setting whose default is empty; F2 then CTRL-U otherwise.
- **machine** · **The ALT, CTRL and SHIFT key bars come with ALT-K, not by holding the key** (meeting 2026-10-24, § 5; the tag confirmed by the owner 2026-10-24: ALT-K is Agenda's own key, so not quiet; to be built, The steps): a terminal sees ALT or CTRL held alone only with the kitty keyboard protocol (`archive/KITTY.md`), so ALT-K cycles the bar through the normal one, ALT, CTRL, SHIFT and hidden; the key names (`AltF4`, `CtlF4`) say which (a letter in the last column, decided at the meeting, was dropped by the owner after trying it, 2026-10-24).
- **machine** · **Export / Import** are JSON, not structured `.STF` files; Import also reads Agenda's own `.AG` files (R72); STF is still to come (ROADMAP, Data interchange).

## How close: a guesstimate

Counting what is in scope (not printing, networks, protection, the macro language, DOS), and weighing each Agenda command or behaviour about equally:

| Area                                           | Parity                                                                    | What is missing                                                                                                                             |
| ---------------------------------------------- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| The control panel (lines, indicators, key bar) | about 80%                                                                 | WAIT, the * D o ♫ symbols                                                                                            |
| The F10 menu                                   | about 75% (35 of 46 in-scope commands, counting the partial ones as half; View Properties whole since 2026-10-23) | Abandon, Template, Erase, Undisc and Trash, Show ItemsDone / Circular / Every, Launch, the rest of File Properties |
| The note editor                                | about 85% (NOTE_EDITOR.md; was 50% before steps 1–6, R64a–R64f, 2026-10-17) | external note files (File Attach, Detach, Erase), ALT-F1 COMPOSE                                                                           |
| Data model, assignment, views (SPEC R1–R64)    | about 90%                                                                 | unindexed categories, the trash, external note files                                                         |
| **Overall**                                    | **about 80%**                                                             |                                                                                                                                             |

These are rough: a count of commands and rules, not of how much each matters. By what people used Agenda for (`docs/AGENDA_HISTORY.md`: free text, automatic assignment, views), Agendum is closer than the menu count says; the gaps are mostly in housekeeping and the editor.

## The steps

The parity work, in the order it is planned (the owner reorders it): each item small and test-first, built with the `feature` skill. This is the only list of it; `ROADMAP.md` points here, and its "In order" list names the next few. A finished item is ticked and moved to `ROADMAP_DONE.md` (Milestone 2), as every roadmap item is. Done so far: the groundwork of the truthful clone (the extras' shelf, ADR 0044; the Extras preference, R77; Agenda's menus captured and compared by a test), the tagging of the two lists above (2026-10-22), View Properties (R78) with Number items (R79), the shortcut entries out of the menus, recurring items on every date they recur, and editing one shows its rule (R14a) (2026-10-23); the key bar on two lines and ALT-K's bars (R80, ADR 0045), Agenda's menus (R81, R81a, with the Section Add box, R61), settings boxes applying on ENTER (ADR 0030), category lists from a box (R81b), and F8 / ALT-F8 in boxes (R81c) (2026-10-24); a date or numeric category's properties (R6a, 2026-10-25). The order: View Properties first and recurring items second, as the owner met both in daily use (meeting 2026-10-22, § 5f), the shortcut entries leaving the menus once View Properties was built (owner, 2026-10-23); the rest grouped by kind, the most used first.

#### Next

The rest of Agenda as the reference for texts (Screens and texts, below).

#### Menus as Agenda's

Done (R81, R81a, 2026-10-24; `ROADMAP_DONE.md`, Milestone 2). Left: comparing the managers' menus (Commands and behaviour still missing, below).

#### Boxes and lists

Done: Category properties of a date or numeric category as Agenda's (R6a, 2026-10-25; `ROADMAP_DONE.md`, Milestone 2).

#### Screens and texts

- [ ] The rest of Agenda as the reference for texts (§ 8), after the menus (done 2026-10-23, `capture_menus.py` and the menu test): the labels in settings boxes, the key bar and messages, captured and compared step by step, each difference tagged. Long help lines are Lotus's text: mind them before going public (GITHUB.md § 7)
  - [x] The settings boxes captured and compared (2026-10-25, `capture_boxes.py`, `agenda_boxes_test.exs`): 96 differences in 25 boxes, each tagged; the owner chose Agenda's way for the four groups below
  - [x] Six more boxes captured and compared (2026-10-25): Display Format, Input Format, Item Column Properties, Search, Show Schedule (as Agenda's already), Macro Properties; 21 differences tagged, the owner choosing Agenda's way for the titles, Display Format, Macro Properties and Item Column Properties' Width
  - [ ] Item Column Properties: Agenda's Width row (change back, owner 2026-10-25)
  - [ ] Still to capture: Datebook settings (a datebook view), Questions with suggestions waiting, Column Add's choices
  - [ ] Messages compared with Agenda's
- [ ] No mode word when ready, and only Agenda's mode words elsewhere (a change back, tagged in the sitting of 2026-10-22: settle it with the owner before it is built; the owner tries it before the next is built on it)
- [ ] View layout and symbols: no "Section:" line, a blank line between sections; ‼ done, ♪ note; exclusive families bracketed (┌ ├ └); * date categories and datebook views; the category manager without counts and tags
  - [ ] Rows under a section indented four spaces, and ♪ on a section head (the owner's note, 2026-10-24; checked in Agenda 2.0, PLANNER's People view): an item's tag in column 5 and its text from column 7 (`    • Call Mattias`), its columns staying under their heads; a head's first column kept for ♪ when its category has a note (`♪Göran`), a space otherwise (` Unassigned`). Agenda draws an item's note as ♪ in the tag's place (`    ♪ Call Göran`), not `•♪` as ours (the ♪ above)
  - [ ] `»` on the current row (the owner's note, 2026-10-24; checked in Agenda 2.0): with the item text highlighted, `»` stands just before the row's first column; with a column entry highlighted (→), `»` takes the tag's place before the item text, so the row the highlight is on shows in both. Agenda's character (CP437 0xAF), the owner's choice; `>` only where a theme has no »
- [ ] Control panel symbols and indicators: `*` on a date category or value, `WAIT` while a calendar is fetched, `D` with unindexed categories (and unindexed categories themselves)
- [ ] Editing: the prompt and input field in the control panel (EDIT), editing key bars (F2 Paste, F3 Copy, F4 Cut, F7 Mark) in item text and category names (the note editor's header: in the note editor plan above)

#### Commands and behaviour still missing

- [ ] New files get Agenda's date format, MM/DD/YY; ISO stays a choice (YYYYMMDD with "-"), and a file keeps the format it has (a change back, tagged in the sitting of 2026-10-22: settle it with the owner before it is built; the owner tries it before the next is built on it)
- [ ] Alarms as Agenda's (the tagging sitting, 2026-10-22): an alarm that came due while the file was closed rings when it is opened and shows `@`, without a box (checked in Agenda 2.0); Utilities ▸ Show Alarm, a Show View with !Current Alarms! and !Past Alarms! (DEL removes an item from the list; Past Alarms emptied at the end of the day; User's Guide 10-18 to 10-20). The "While you were away" box (R70) is an extra since R77 (2026-10-23): with Extras off, missed alarms already ring on open, without the box
- [ ] Search compared with Agenda's (ALT-F6 SEARCH in a view and a note, its Search box, the Match show view): the differences become parity work (the tagging sitting, 2026-10-22: no longer an enhancement)
- [ ] The trash: Item ▸ Undisc, Utilities ▸ Trash, File Properties ▸ Empty trash (a habit change: DEL putting items in a trash; settle it with the owner first)
- [ ] File ▸ Abandon, File Maintenance Erase, File Transfer Template
- [ ] File ▸ Maintenance ▸ MakeCopy in Write's place (check in Agenda first which file you are in afterwards) (a change back, tagged in the sitting of 2026-10-22: settle it with the owner before it is built; the owner tries it before the next is built on it)
- [ ] Show ItemsDone, Show Every, Show Circular (with the `o` indicator); and Show Prereqs and Depends as Agenda's, one command each (ours ask One level, All levels or Every item in a submenu; how Agenda chooses is unchecked)
- [ ] File Properties: Agenda's other settings (File description, Set file password, Make backup on open, Empty trash; screenshot 130) where Agendum has them (Tab size done, R64e)
- [ ] Compare the category, view and macro managers' menus with Agenda's, and add them to the overview
- [ ] Optional: Agenda structured files (`.STF`): import and export as Agenda 2.0's File Transfer does (Working with Definition Files, Appendix B; User's Guide chapters 23–24), so legacy users can bring old files over via DOS Agenda's export. Read both 2.0 dates (`{C}\When@|10%/31%/1990`) and 1.x dates (`{W}10/31/90`) into the same When/Entry/Done categories (Lotus Q&A "Date Categories are Duplicated") (moved from the roadmap's Data interchange, owner 2026-10-23; stays optional)
- [ ] Optional: Import of structured text files (one item per line, with categories) (moved from the roadmap's Data interchange, owner 2026-10-23; stays optional)
- [ ] Optional: TXT2STF-style definition files that turn plain text into items (Working with Definition Files). A first real use: the session summaries in `docs/summaries/` (one per feature, all alike: `#` title, dated, commit hashes, R-numbers), imported with STF and a definition file so text matching files them (the owner's wish, 2026-10-15) (moved from the roadmap's Data interchange, owner 2026-10-23; stays optional)

#### The note editor

- [ ] The note editor as Agenda's (checked in Agenda 2.0, 2026-10-15; printing and typesetting, F10 Print and F6 MARKER, out of scope). Evidence, the habit changes to settle first (ESC, INS, TAB, the control panel's first line) and the steps: [`docs/plans/NOTE_EDITOR.md`](NOTE_EDITOR.md)
  - [x] Its control panel and key bar (R64a, 2026-10-17): line 1 "Note for:   …" (the macro editor's "Edit macro:  …") with "Line N INS EDIT" on the right, a message over it until the next key, hints on line 2; the key bar in Agenda's order, F1 Help … F5 Return, F7 Mark. "Note file: …" comes with external note files, F10 Menu with the menu
  - [x] Its F10 menu (R64b, 2026-10-17): Clear (asks; one undo step), Return, Quit, with Agenda's help lines; Import and Export come with the next item, File with external note files
  - [x] Import a text file at the cursor; Export the note to a text file (R64c, 2026-10-17): prompts with F3 listing `.txt` and `.md`, CR LF read as LF
  - [x] ESC asks "Discard changes?" (R64d, 2026-10-17): only when the note changed; No (first) saves, Yes restores the note as opened, saved replacements and Clear included; ESC on it goes back to the note; F5, ALT-N/P save without asking
  - [x] Editing keys, part 1 (R64e, 2026-10-17): ALT-M, word moves (CTRL-←/→, ⌥←/→), word delete (⌥⌫, CTRL-W, ALT-W), CTRL-K to the line end, PGUP/PGDN, CTRL-HOME/END (⌥< ⌥>)
  - [x] Editing keys, part 2 (R64e, 2026-10-17, v0.15.0, format 37): INS/OVR (INS, CTRL-N) shown in the header; TAB to the next tab stop, File Properties ▸ Tab size (stored, 5 by default)
  - [x] ALT-F9 APPEND, ALT-F8 GETITMS and ALT-C (calendar) in a note (R64f, 2026-10-17); GETITMS copies only: whether to add Agenda's "discard the copied items?" question is the owner's to decide
  - [x] Bug: in a note longer than the screen, ↑ from the bottom kept the cursor on the bottom row and scrolled the note under it (found by the owner, 2026-10-18). The note now keeps the row it shows first and scrolls only when the cursor would leave the screen, as an editor does
  - [ ] External note files: File Attach, Detach, Erase (a stored field and an ADR), or left out on purpose: the owner's to decide (NOTE_EDITOR.md, step 7)
  - [ ] Optional: ALT-F1 COMPOSE

#### Help

- [ ] Agenda's help, in our own words (meeting 2026-10-22, § 7): Agenda's F1 keys and structure exactly (the topic for where you are, bold links, F3 Index, F5 Find, F6 Keys, F8 or BACKSPACE Review; PURPOSE, STEPS, PRESS / TO DO THIS), the texts new since Agenda's are Lotus's: terse, a Hundred Acre Wood flavour in an opening line and the examples, no Milne quoted, no Disney or Shepard pictures. Today's F1 texts and command descriptions become its topics; F1's `c`, `d`, `a` (R65) stay reachable from it
- [ ] Optional: Utilities Launch (a shell without quitting)

**Declared done** means: every step above built, and every entry on the two lists tagged by ADR 0043's test and confirmed by the owner. It does not wait for outside users' findings (meeting 2026-10-22, § 5a). Each missing thing in "How close" above is either a step here or on the modifications list on purpose.

When a difference is kept, it goes in the enhancements or modifications list above, so that the lists stay the whole truth.
