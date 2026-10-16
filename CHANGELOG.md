# Changelog

What changed in each version of Wol's Agendum, for the person using it. Versions follow [semantic versioning](https://semver.org): before 1.0.0, the minor number (0.**3**.0) goes up with every major feature or change to the file format, the patch number (0.3.**1**) with fixes. Each version is tagged in git (`v0.2.0`). The roadmap's Done section ([`docs/ROADMAP.md`](docs/ROADMAP.md)) lists every finished item; git log has the detail.

## 0.5.0 — 2026-10-16

Help you can learn from: the command list says what cannot run now and why, each command says why you would use it, and help opens as a box over the screen you were on.

- In F1 c, commands that cannot run now are greyed where they always are; the highlighted one says why ("Not now: No removed item to yank back"), and ENTER gives that reason instead of running it. Typing to narrow the list highlights the first match that can run. F1 d says it too.
- Commands have a longer text that says why you would use them where that is not obvious (Remove takes an item out of one category only, so other views still show it). F1 c shows it, and so does F1 d; in the menu, for its entries; in a box, for its commands.
- The help opens as a box over the screen you were on, which fades behind it, so you keep your place; it takes more of a small screen. Every help page has the same heading and rule; the command list has a pane at the foot with the highlighted command's text, which ← → page through, and the list no longer moves as the highlight moves. Long summaries end in "…". The colours follow your theme.

## 0.4.0 — 2026-10-16

F1 is help about where you are, everywhere; every key goes through a keymap, so the help lists every key correctly.

- Undoing the new macro while learning its keystrokes, then stopping Learn mode, no longer crashes: nothing is kept, and a message says why.
- F1 now shows help about where you are: the view, a note, a manager, the menu, or the box you are in, saying what to do there. From it, c lists the commands, d tells what a key does, and a lists every key (made from the keys themselves, so it is always right).
- F1 c and F1 d also work in the category manager, the view manager, a note, the menu and every box; F1 now opens the help in those places too. In a box, F1 c lists the box's commands and ENTER runs the one highlighted; in the menu, it lists the entries by their letters. F1 also works while moving items, a column or a section, changing a width, browsing and searching. Typing in F1 c's list narrows it.
- In a date filter, < and > now move a day while browsing, as ← and → do.
- The help and the keyboard guide say ⌥m (Option as Meta) where they said ESC m: ESC typed by hand and then a letter is two keys.

## 0.3.0 — 2026-10-15

Keys run named commands: a count before a command, and help that lists the commands and tells what a key does.

- A count before a command in a view, as in Emacs: ALT-1 ALT-0 ↓ moves ten rows down. Counts work with the moves (↑ ↓ PGUP PGDN ← →, previous and next section), ALT-J, ALT-H and ALT-N / ALT-P; other commands run once, and ESC drops the count.
- The help screen (F1) has two more pages: `c` lists the commands you can run where you pressed F1, with their keys (ENTER runs one), and `d` tells what the next key you press does there, without doing it.
- An ALT-arrow from a Mac with Option as Meta (ESC ESC [ A) is no longer now and then read as ESC and an arrow when its bytes arrive in two reads.
- ESC answers sooner: a lone ESC waits 25 ms, not 40, for a key that might follow it.
- Adding or changing an item is quicker when categories have date conditions ("this week", "..yesterday"): their dates are read once.

## 0.2.1 — 2026-10-15

Quicker answers to keys, and a debug log that shows where lag comes from.

- Quicker answers to keys: keys typed fast or held down are answered with one drawing, and views showing many items draw faster.
- A view filtered by dates written in words ("..yesterday", "today ..friday") no longer lags: it reads those dates once, not once for every item, so moving in it is about twenty times quicker.
- The debug log (`AGENDUM_LOG`) notes every answer to a key that took 100 ms or more, with how the time was spent, and names the file in use when the program starts and when another file is opened. It also names the commit the program was built from, the file's size, time and fingerprint on disk, how long saving, loading and calendar reads took, and with each slow answer the view on screen and the memory in use.

## 0.2.0 — 2026-10-15

The first numbered version: everything built since the first commit (2026-10-08), about 80% of the way to Lotus Agenda 2.0 ([`docs/plans/AGENDA_PARITY.md`](docs/plans/AGENDA_PARITY.md)).

- Items, categories and views as in Agenda: automatic filing by text, conditions and actions, mutually exclusive categories, dependencies.
- Dates read from plain text (English and Swedish), times, recurring dates, date categories, datebook views, alarms, the pop-up calendar.
- Views with sections, columns per section, sorting, date and numeric filters, numeric columns with totals.
- Notes with marking, cut and paste, search and replace, word wrap.
- Learn-mode macros, the Activities Planner starter file, themes, preferences, undo and redo.
- JSON export and import; calendar subscriptions from the web.
- Agenda's look: its colours, two-line control panel, boxes and menus.
- File format version 33.
