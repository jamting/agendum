# Agenda — behaviour specification

What we are cloning, distilled from US patent 5,115,504 ("Information
Management System", Belove, Kapor, Kaplan et al., Lotus 1992) and the Lotus
Agenda 2.0 manuals. Rules are numbered so tests and commits can refer to them.
✅ = implemented and tested, ⏳ = planned (see `ROADMAP.md`).

## 1. Concepts

| Concept               | Meaning                                                                                                    | Code                    |
| --------------------- | ---------------------------------------------------------------------------------------------------------- | ----------------------- |
| **Item**              | A free-form piece of text (up to a few lines), with an optional note. Exists independently of categories.  | `Core.Item`             |
| **Category**          | A named node in one hierarchy rooted at **MAIN**.                                                          | `Core.Category`         |
| **Link / assignment** | An independent many-to-many link between an item and a category (the patent's "link structures").          | `Core.Links`            |
| **View**              | A saved arrangement: **sections** (each headed by a category) and **columns** (each headed by a category). | `Core.View`             |
| **Date category**     | Entry, When, Done: categories whose membership is an item's date.                                          | `Database.date_field/2` |

## 2. Data model rules

- **R1 ✅ Many-to-many.** An item may be assigned to any number of
  categories and a category may hold any number of items. Links are
  reachable from both sides (patent FIG. 2, 3B).
- **R2 ✅ Hierarchy.** Categories form a single tree under MAIN, with
  ordered children (patent FIG. 1). MAIN, Entry, When and Done cannot be
  deleted or renamed.
- **R3 ✅ Subsumption.** An item assigned to a category is also a member of
  every ancestor of that category (patent FIG. 4: I4 in C9 is also in C5, C2,
  C1). This is computed, not stored.
- **R4 ✅ Deletion side effects.** Deleting a category deletes its subtree
  and all its links. Items lose the memberships they had only through it
  (patent: deleting C5 removes I6 from C2 and C1). The category also
  disappears from view sections and columns.
- **R5 ✅ Every item is in MAIN.**
- **R6 ✅ Date categories.** Entry is set when an item is created, When is
  read from the item text (R14) or set explicitly in a When column or with
  ALT-F2, and Done is set by F4.
- **R7 ✅ Mutual exclusion.** A category can declare its children mutually
  exclusive (e.g. Priority: High/Medium/Low). Assigning an item to one child
  removes it from the others and their subtrees. This applies at every
  exclusive level above the target. (Patent "negative links", FIG. 6;
  Agenda's "mutually exclusive" category property.)
- **R7a ✅ Resolving conflicts when making children exclusive.** If items
  are already in more than one child, the user chooses where they go, as in
  Agenda 2.0's _Assign conflicting item(s) to_ box (User's Guide,
  "Resolving conflicts for mutually exclusive categories"):
  **Parent category** (default; leave all children, assign to the parent),
  **Existing category** (keep the child closest to the top of the family),
  or **New category** (a new child, named by the user, gets them). The
  manual doesn't say where the new category is created; we make it a child
  so the family stays consistent. Making children non-exclusive keeps all
  assignments. MAIN and the date categories cannot be made exclusive.
- **R7b ✅ Resolving conflicts when moving categories.** Promoting (F7),
  demoting (F8) or moving (ALT-F10) a category can put an item in two
  branches of a mutually exclusive family. The user then chooses, as in
  Agenda 2.0's _Process conflicting item(s) by_ box (User's Guide,
  "Resolving Conflicts When Promoting/Demoting Categories"):
  **Removing from current category** (default; the moved category),
  **Removing from conflicting category** (the branch it clashes with), or
  **Moving to new category** (named by the user). We create the new category
  as a child of the exclusive family where the clash happens, and the
  items leave both clashing branches. Reordering siblings cannot clash.
- **R7c ✅ No direct assignment to both a category and its ancestor.** An
  item is a member of every ancestor through inheritance, so it is never
  _directly_ assigned to a category and one of its ancestors. Assigning to
  an ancestor breaks the item's assignments to its descendants (as the
  manual states, User's Guide 16-5). Assigning to a descendant replaces a
  direct assignment to an ancestor (our reading of "does not let you
  assign... to both"). Automatic assignment never assigns a category the
  item already belongs to, and when a category and its ancestor both match
  the text it keeps the more specific one. A category link (`also_assign`)
  to a category the item already belongs to is skipped. A move (promote,
  demote, ALT-F10) that would break the rule offers the same three choices
  as R7b; when it breaks both rules, we show one box for both instead of
  Agenda's two boxes in sequence. With "Moving to new category", the new
  category is created under the conflicting ancestor or exclusive family.
- **R7d ✅ Outline-style promote.** The hierarchy behaves like an outline
  whose order never changes; promote and demote only shift a category's
  level (User's Guide, "Promoting and Demoting Categories"). Promote moves a
  category up one level, right after its old parent, and its following
  siblings become its children, after its own children (Figure 16-13:
  promoting Sam adopts John and Anna, and Sam's child Ted comes along).
  Demote makes a category the last child of its previous sibling and is
  refused for a first child, which would skip a level. Conflicts caused by
  adopted siblings (Figure 16-15: promoting Anna makes Tim its child) are
  resolved with the R7b/R7c choices; when several links clash, the one
  closest to the top of the outline wins. Our reading: the promoted
  category keeps its own subtree, which matches the manual's example.
- **R8 ✅ Category links.** A category can pass its items on to other
  categories (`also_assign`, patent FIG. 6). This applies transitively and is
  safe with cycles.
- **R9 ⏳ General negative links.** Two arbitrary categories that may not
  share an item.

## 3. Automatic assignment

- **R10 ✅ Text matching.** When an item is entered or edited, it is
  assigned to every category whose name (or short name) appears in its
  text as whole words, ignoring case and extra whitespace (patent: "Meet with
  John Smith on Tuesday" → Meetings + John Smith). Categories can opt out
  (`match_name: false`).
- **R11 ✅ Explicit wins.** An automatic match that conflicts with an
  existing explicit assignment (R7) is dropped.
- **R12 ✅ Ambiguity (patent claim 7).** If two matches conflict with each
  other, prefer the category that the adjacent item in the view belongs
  to (previous, then next). Otherwise prefer the category created first.
- **R13 ✅ Recalc.** The user can re-run automatic assignment for all items
  (Category ▸ Recalc).
- **R14 ✅ When dates from item text.** The first date in an item's text
  becomes its When date ("Call Toni on August 7", "Cheryl arrives
  tomorrow"); items with no date get none (User's Guide 6-6 to 6-7).
  Editing the date words changes the When date; relative dates are read
  once, so editing other words keeps it, and removing the date words
  clears it. A When date set explicitly (When column, ALT-F2, Item ▸ When)
  overrides the text, and later edits leave it alone; clearing it (DEL in
  the When column) hands it back to the text. File ▸ Dating turns
  automatic dating off for a file. Recalc dates items that have a date in
  their text but no When date.
  Dates follow the manual's rules (chapter 7): weeks run Monday to Friday; a
  bare weekday is its next occurrence (today if today); this/next/last put a
  weekday in the current, following or previous week; this/next/last
  week/month/year is the start of that period; a date without a year is in
  the future. Supported phrases: today, tomorrow, yesterday (and Agenda's
  "tmorrow", "ystday"), the day after tomorrow / before yesterday,
  weekdays, beginning/end of a week or month, in N days/weeks/months (digits
  or words), N … from today, N … ago, a fortnight, month-day dates ("August
  7", "November 23rd, 1991", "the first of November", "7 Aug"), and numeric
  dates (11/20/90, 11/20, 2026-11-20). Times ("at 3:00") are accepted and
  ignored. Our safeguard: bare abbreviations that are common words ("sat",
  "sun", "wed", "may" alone) count as dates in item text only after "on",
  "by", "until" or "till", or with a day number ("May 5").
- **R14b ✅ Times of day** (User's Guide 6-12 to 6-13). When dates can
  carry a time, read from item text or typed into a When column / ALT-F2:
  "3:30 pm", "@ 3pm", "15:30", "noon", "morning" (8:00), "afternoon"
  (14:00), "evening" and "tonight" (17:00), "now", "in 2 hours", "45 mins
  from now". A time alone means today; a time without am/pm falls between
  8:00 am and 7:59 pm ("3:30" is 15:30); hours over 12 and a leading zero
  read as a 24-hour clock. When columns show "2026-10-13 15:00" and sort
  by date and time. A time never reuses a date's words ("at 12/24").
- **R14a ⏳ More date phrases.** Recurring dates ("every Monday", "every other Monday"), working days,
  quarters, "first Wednesday in November", "next April", dates from notes,
  and settings for date order (day/month) and the start of the week.
- **R15 ✅ Assignment conditions** (User's Guide, chapters 18 and 20). A
  category can have conditions on other categories: items *assigned* to
  them (Urgent if Taxes and Accountant) or *not assigned* to them (Me if
  not People). All conditions must hold, except "assigned" conditions on
  mutually exclusive categories, which are alternatives (High or Low).
  Agenda checks an item against all conditions when it is added, edited,
  assigned or unassigned: a category whose conditions it meets assigns it,
  and an assignment a condition made is broken once the condition no longer
  holds. Assignments the user makes are never broken by conditions. Like
  Agenda, a new condition applies to existing items only after Recalc
  (Agenda's Utilities Execute). Conditions are set in category properties
  (ENTER on a category cycles none → assigned → not assigned); the
  category manager shows them ("if Taxes, not People") and the assignment
  profile marks conditional assignments with "c". Contradictory conditions
  settle after a bounded number of rounds.
- **R15a ⏳ Date conditions** (a Today or Overdue category by When or Done
  date, rechecked when the date changes), and text conditions beyond the
  category name and short name ("Also match").
- **R15b ⏳ Actions:** remove-from actions, date actions (set a When date),
  special actions (mark done, discard, export), and Utilities Execute for
  re-running actions. Category links (R8) already cover "also assign".
- **R15c ⏳ Text matches as conditional assignments:** in Agenda, an
  assignment made because a name appeared in the text is broken when the
  text no longer contains it; ours only adds.

## 4. Working through views

All modification happens in the context of a view (patent claims 1, 3, 4, 6).

- **R20 ✅ Sections.** A section lists every item that is a member of its
  head category (including via subcategories), in item order. Items
  that are members only through a subcategory are "inherited" and can be
  hidden.
- **R21 ✅ Entering an item.** Typing under a section creates an item
  assigned to the section's category (unless it is MAIN), placed after the
  highlighted item. Automatic assignment (R10–R12) then runs, using the
  neighbouring items in the section for R12.
- **R22 ✅ Columns (claim 2).** A column headed by category _C_ shows, for
  each item, the descendants of _C_ the item is assigned to. A childless
  head shows `*` when the item is a member. A date column shows the date.
  When a column is too narrow for a category's full name, the category's
  short name is shown instead, for column entries and column heads alike
  (User's Guide 19-2).
- **R23 ✅ Typing in a column (claims 3, 6).** Text typed in a column cell is
  matched against the column head's descendants with automatic completion
  (R32); if nothing matches, a new child is created. Typing replaces the
  current entry; INS adds another one. Date columns parse dates.
- **R24 ✅ DEL** on an item removes it from the section's category (and its
  subtree). The item stays in the file. On a column entry DEL unassigns it,
  and on a section head DEL removes the section from the view.
  **DISCARD** (ALT-F4) deletes the item from the file.
- **R25 ✅ Editing the structure from a view.** Rename a category by editing
  a section head or column entry (F2). Add sections (ALT-D/ALT-U) and columns
  (ALT-R/ALT-L) with existing or new categories.
- **R26 ✅ Move (ALT-F10).** Moving an item to another section reassigns it
  from the old section's category to the new one and reorders it.
- **R27 ✅ View options.** Hide done items, empty sections, inherited items.
- **R28 ✅ Filters** (User's Guide chapter 11). A view, and each of its
  sections, can be filtered by categories: items assigned (or not
  assigned) to them. All criteria must hold, except that categories that
  are mutually exclusive are alternatives (same rule as R15). The view's
  filter shows in brackets beside its name, a section's after its head.
  Typing an item into a filtered view or section assigns it to the
  categories the filter requires (of exclusive alternatives, the first),
  so it stays in sight. Set with View ▸ Filter and View ▸ Section ▸ Filter
  (ENTER cycles + assigned · - not assigned · none; the box stays open).
  Not done: date and numeric filters.
- **R29 ⏳ Numeric columns.**
- **R36 ✅ Sorting items** (User's Guide chapter 15). A view has sort
  settings for all its sections; a section can override them or use the
  view's. Up to two keys (primary, then a secondary for ties): item text,
  or a category — its children in hierarchy order or alphabetically, or
  the date for a date category. Each key has an order (ascending,
  descending) and puts items without a value at the bottom or top. Ties
  keep entry order. Set in the Sort box (View ▸ Order, View ▸ Section ▸
  Sort, or ALT-F5 in a view for the current section). Our choice: sorting
  is applied whenever the view is shown, like Agenda's "When item is
  entered" setting, so "On leaving a section" and ALT-S re-sorting are not
  needed. ALT-F5 in the category manager sorts the highlighted category's
  children alphabetically (after Y/N); in the view manager it sorts the
  views. Not done: sorting by category note, sorting section heads.
- **R37 ✅ Search** (User's Guide 15-1 to 15-5). ALT-F6 (or Search ▸ View)
  opens the Search box: the text, Match on (item text, note text, both),
  Direction (forward, backward, from the beginning) and Ignore case (yes by
  default). ENTER highlights the first match and starts search mode: ALT-N
  / ALT-P go to the next / previous match (a message says when there are
  no more), F7 marks the highlighted item, ENTER or ESC ends. Search ▸ File
  (Agenda's Utilities Show Match) lists every matching item in the file in
  a "Show View", created the first time; ALT-F8 (LAST VW, or View ▸ Last)
  returns to the previous view. Text rules: every word must appear as a
  whole word, "Pat*" matches any ending, "(a phrase)" must appear as
  written. Not done: Agenda's other text-condition symbols (? ; , ~ !),
  and items in collapsed sections are skipped. Searching inside a note is
  R39.
- **R38 ✅ Clock and alarms** (User's Guide 10-16 to 10-20). The title bar
  shows the date and time. ALT-A (Item ▸ Alarm) sets an alarm to ring 0
  to 60 minutes (default 5) before an item's When date and time; the item
  shows "@"; ALT-A again cancels it. When the time comes the alarm rings:
  a bell, a message naming the item, and "@" in the title until the alarm
  list is opened. Search ▸ Alarms lists current alarms and today's past
  alarms; DEL removes a past one, ALT-A cancels a current one. Past alarms
  are forgotten when the date changes. Our choices: alarms always use the
  When date (Agenda let you choose the date category); the alarm list is a
  box rather than a Show View with !Current Alarms! / !Past Alarms!
  sections; ringing is not an undo step.
- **R39 ✅ Search and replace in a note** (User's Guide 15-6 to 15-8).
  ALT-F6 in a note opens the Search/Replace box: Search for, Replace text
  (No by default; Yes adds Replace with, Global replacement (No) and
  Confirm replacement (Yes)), Direction (Forward or Backward) and Ignore
  case (Yes). The text is matched as written, anywhere in a line. A search
  moves the cursor to the next occurrence and highlights it; ALT-S finds
  the next one and beeps when there are no more. A replacement replaces
  the next occurrence, or every occurrence when global; when confirming,
  each occurrence is highlighted and Y replaces it, N skips it, ESC stops.
  Our choices: the search starts at the cursor and, when nothing is found
  after it, continues from the top (backward: the bottom), since a note
  opens with the cursor at its end; a global replacement covers the whole
  note; the box remembers its last settings; no length limit (Agenda
  allowed 25 characters); text never matches across lines. The note is
  saved when it is closed, so all replacements are one undo step.

## 5. User interface (Agenda 2.0 conventions)

Screen: a title bar (file, view, mode indicator such as READY / EDIT /
MENU / CAT MGR), a two-line control panel (menus, prompts, messages), the
body, and a function-key bar.

| Key         | View                                                                | Category manager        |
| ----------- | ------------------------------------------------------------------- | ----------------------- |
| F1          | Help                                                                |                         |
| F2          | Edit item / section head / column entry                             | Rename                  |
| F3 | Choices (category box for a column; assignment profile for an item) | |
| F4          | Done                                                                |                         |
| F5          | Note                                                                | Note                    |
| F6 | Properties (item: Item Properties box; section head: category properties) | Properties |
| F7          | Mark                                                                | Promote                 |
| F8          | View manager                                                        | Demote                  |
| F9          | Category manager                                                    | Return                  |
| F10 or `/`  | Menu (File Item Category View Print Quit)                           | Return                  |
| ALT-F4      | Discard                                                             | Discard                 |
| ALT-F10     | Move item                                                           | Move under a new parent |
| ALT-D/U/R/L | Add section below/above, column right/left                          |                         |
| INS         | New item / additional column entry                                  | New category below      |

Category manager navigation (from the manual): ↑/BACKSPACE, ↓/ENTER,
HOME = parent, END = last of family, CTRL-PGUP/PGDN = previous/next
sibling, CTRL-HOME/END = first/last.

Extras that are not in the original (details in `KEYBOARD.md`):

- **R30 ✅ Undo/redo** (CTRL-Z / CTRL-Y, menu Undo/Redo). Every action that
  changes the database is one undo step. Undo returns to the view and item
  where the change happened. It is available in views and in the category and
  view managers, but not while typing. Undoing back to the last save clears
  the "modified" marker. History holds 100 steps.
- **R31 ✅ Keyboard alternatives.** ESC+digit = F-key, ESC+shifted digit =
  ALT-F-key. CTRL-N = INS, CTRL-E = F2, CTRL-K = F4, CTRL-D = discard,
  CTRL-S/O/P/Q = save/open/print/quit. ⌥↑/⌥↓ jump between sections. Text
  fields use Mac/emacs editing keys. ⌘ shortcuts are mapped onto these CTRL
  keys by the terminal.
- **R32 ✅ Automatic completion** (User's Guide 2-19 to 2-21). While a
  category name is typed into a column cell, Agenda shows the first
  matching category (the rest of its name in grey), the top line says how
  many match, and AUTOC shows in the title bar. Matching is on the start of
  names, ignoring case and accents ("éc" matches écrit and economy), among
  the column head's subcategories only, with an exact name first and then
  hierarchy order. ENTER accepts the shown match; F8 / ALT-N and F7 / ALT-P
  cycle through the matches (wrapping); typing more starts again at the
  first. INS, CTRL-N or F5 (NEWCAT) create exactly what was typed, even when
  it begins an existing name (Low when Lowest exists). With no match, ENTER
  creates the new category. Not done: the beeps, and F3 opening the category
  box at the matches.
- **R33 ✅ Collapsing and expanding** (User's Guide 16-8 to 16-9, 5-5).
  Wherever the category hierarchy is shown (category manager, category
  box, assignment profile), ALT-− collapses the family the highlight is in
  (its own children if it has any, otherwise its parent's) and pressed
  twice collapses every family; ALT-= expands the highlighted family and
  pressed twice expands everything. A collapsed parent shows "...". The
  assignment profile still shows categories the item is assigned to. Our
  choices: collapsed families are a display setting kept for the session
  (shared by all those screens, not saved in the file and not undone), and
  moving a category into a collapsed family expands it so it stays in
  sight. In a view, the same keys collapse and expand the current section
  (twice: all sections), shown with "§".
- **R34 ✅ Item Properties box** (User's Guide 4-13 to 4-15). F6 on an
  item (or Item ▸ Properties) shows its text (ENTER/F2 edits), note
  (ENTER/SPACE opens it), statistics (number of categories, entry date) and
  every assignment in hierarchy order: dates in parentheses, conditional
  assignments marked "(c)". DEL breaks an assignment (the Entry date cannot
  be removed); F4 or ENTER changes a date; typing assigns a category, with
  automatic completion over all categories (R32), asking for the date when
  a date category is chosen; INS creates exactly the typed name under MAIN;
  F3 opens the assignment profile. Not done: note files.
- **R35 ✅ Marked items** (User's Guide 13-1 to 13-4, 4-5, 4-17). F7 marks
  an item (♦); on a section head it marks every item in the section, or
  unmarks them when all are marked. ALT-F7 unmarks everything; ALT-J jumps
  to the next marked item in the view. With items marked, these commands
  first ask "Marked items (N) / Current item": F4 done (marked items are
  all set done), ALT-F4 discard (then Y/N), DEL remove from the current
  section, ALT-F2 When date, ALT-F10 move (the items keep their order),
  ALT-M MakeAssign (category box; also for a single item), and F3, which
  shows a group assignment profile: a number beside each category says how
  many marked items are in it, and SPACE assigns or unassigns them all. Our
  deviation: marks belong to the item, not to one section, so a marked item
  shows marked everywhere; a moved item leaves the first section of the
  current view that holds it. Not done: copying marked items (no item copy
  yet).

## 6. Out of scope for now

Macros, printing to a printer, import/export of structured files,
networking/file reservations, the Metro accessories.
