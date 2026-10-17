# Changelog

What changed in each version of Wol's Agendum, for the person using it. Versions follow [semantic versioning](https://semver.org): before 1.0.0, the minor number (0.**3**.0) goes up with every major feature or change to the file format, the patch number (0.3.**1**) with fixes. Each version is tagged in git (`v0.2.0`). The roadmap's Done section ([`docs/ROADMAP.md`](docs/ROADMAP.md)) lists every finished item; git log has the detail.

## Unreleased

## 0.14.0 — 2026-10-17

Run a command by its name.

- CTRL-X opens a small box: type part of a command's name, or the initials of its words ("azi" for Attach Zettel id), and ENTER runs the highlighted one, as its key would. Only what can run where you are is listed, each with its key, so you can learn it; the commands you last ran this way come first. It works in a view, the managers, a note, a box, and while moving or browsing.
- F1 then `c` narrows its list the same way, so typing there finds more, best match first.

## 0.13.0 — 2026-10-17

A plain news reader: feeds come in as calendars do.

- File ▸ Transfer ▸ Feeds subscribes to RSS and Atom feeds. Each entry becomes an item under Feeds ▸ the feed's name, its title the text, its summary and link the note, its publish date the Entry date; text matching and conditions file it as any item. The first feed makes a News view, newest first, done items hidden. Feeds are read every hour (or as you set), and when Agendum starts.
- Nothing asks to be read: no unread counts. F4 Done dismisses an entry; after the feed's days (30 by default) an entry fades away, unless you kept it with a Zettel id, a note of your own or a category you gave it.
- CTRL-V (Item ▸ Open link) opens an entry's link in your browser.
- OPML: I in the Feeds box imports a feed list from another reader, E exports yours.
- Files are saved in a new format (36); older files open as before.

## 0.12.1 — 2026-10-17

Keys for the Zettel commands.

- CTRL-T gives the highlighted item (or the marked ones) a Zettel id; CTRL-G follows its links; CTRL-R shows the items linking to it; in a note, CTRL-L types a link to each marked item.

## 0.12.0 — 2026-10-17

A blog from your file (the owner's own use).

- A micro-blog from your file: File ▸ Transfer ▸ Publish writes the items of a Posts category (not those also in Drafts) as a website: an index, a page per post at its Zettel id, an RSS feed and a JSON Feed, plain HTML with an old-school-cool stylesheet you can change. A post's note is written in Markdown, with task boxes `- [ ]`, `- [x]` and `- [-]`, and links to other zettels. Before anything is written, a box shows what will be added, changed and removed; then the folder is written and, if you choose, uploaded by rsync or SFTP (asking for a password when the server wants one, never kept). Files are saved in a new format (35); older files open as before.

## 0.11.0 — 2026-10-17

Zettel ids: items get names you can say, and link to each other (meeting 2026-10-16-3).

- Zettel ids: Item ▸ Zettel ▸ Attach gives an item (or the marked items) a Zettel id, eight letters you can say, such as `bonalaku` (Quadsyl-24, `docs/QUADSYL.md`). An item with an id is a zettel; the id never changes and is never given twice. The JSON export writes it as its word. Files are saved in a new format (34); older files open as before.
- A column can show the Zettel ids: choose the Format Zettel id in Column Add or Column Properties.
- Links between zettels: `[[bonalaku]]` in a text or note, or the id on its own, links to that item, shown in the link colour (a broken one in another). With the cursor on a link the control panel says what it points at. Item ▸ Zettel ▸ Follow and Linked show the items an item links to, and those linking to it, in the Show View; Item Properties lists them under Linked from. In a note, Insert link (from F1 c) types links to the marked items. Text matching ignores links.
- The menu line scrolls when its entries are wider than the screen, ◄ and ► showing there is more: at 80 columns the Item menu hid Reposition and Discard.

## 0.10.0 — 2026-10-16

Old Lotus Agenda files open in Agendum.

- Old Lotus Agenda files come over: File ▸ Transfer ▸ Import takes an Agenda `.AG` file as well as JSON, and `agendum OLD.AG` opens one from the command line. Categories, items, notes, dates, numbers, alarms, conditions and views come with it; it opens as `OLD.agendum` beside the old file, saved when you save. Assignments you made by hand are kept; the rest Agendum works out by its own rules, and a report box lists what came over, what was left out (macros, for now), and any item Agendum files differently. A file with a password asks for it.

## 0.9.0 — 2026-10-16

Agendum guards your file against other writers, and a failed save no longer loses your changes.

- Agendum no longer saves over a file that something else changed after Agendum opened it (another Agendum, a sync tool, an agent). It asks "… has changed on disk since Agendum read it. Save over it?"; No keeps your changes unsaved, and File ▸ Write can save them under another name. Auto-save doesn't ask: it says so and waits for you to save.
- A save that fails no longer loses your changes on the way out: Quit, with Yes to "Save changes before quitting?", now stays open when the save fails (a full disk) and says why; "Save changes first?" before Retrieve, New or Import opens nothing then either.

## 0.8.0 — 2026-10-16

Agendum remembers where you were: a file opens where you left it, alarms missed while it was closed are shown when you come back, and the view manager shows where you are and what you used last (the panel meeting of 2026-10-16).

- Alarms that came due while a file was closed are no longer just a message line: after the splash screen, a "While you were away" box lists them, the latest first, alarms with the same text counted on one line. ENTER or ESC closes it; Search ▸ Alarms still lists them.
- An alarm going off no longer counts as a change to the file, so it never makes Agendum ask "Save changes?" by itself. A past alarm shows the time it was due.
- A file opens where you left it: on the view and the item you were on when you quit or opened another file. The place is kept in your preferences, not in the file, so moving around never asks you to save.
- The view manager (F8) marks the view you are in with ►, wherever the highlight is.
- F5 in the view manager lists the views by when you last used them, and F5 again in your own order. Only the list changes: ALT-N and ALT-P keep your order. Agendum remembers the choice for each file.
- The assignment profile (F3 on an item) says at the top why the item is in the highlighted category: "In Urgent: its condition holds (Calls)", "In People: through Kanga", its text matching, another category's action, or by hand.

## 0.7.0 — 2026-10-16

The groundwork for a web version is laid in the core and the terminal program; the terminal program keeps Agenda's keys.

- F1 c and F1 d say more about moving items, searching, browsing dates, a column's width, moving a column or a section, and typing.
- Inside, for what comes next (a web version, an agent, `agendum add`): typing over a column entry and setting a condition are commands of their own; a view's cells carry their values as data; browsing's dates are worked out in the core; the core can say why an item is in a category (not shown yet); every screen and box is a struct, so a mistake in one is found when the code is compiled.

## 0.6.0 — 2026-10-16

Every change to a file is now a command the core runs, the groundwork for a web version, an agent and capture from the command line. The keys work as before.

- Done (F4) on marked items now records the time where a date category keeps the done time, as done on one item always did.
- ALT-F7 in a note on text of only spaces no longer makes an empty item; the note keeps the spaces.
- A category with conditions that is made a date or numeric category keeps them, as Agenda does, but they no longer assign items.
- Adding or editing many dated items is several times quicker: the date words are prepared once.
- The help box has a background colour of its own in every theme.

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
