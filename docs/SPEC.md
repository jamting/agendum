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
- **R43 ✅ Item dependencies** (User's Guide 13-12 to 13-16; Lotus Q&A
  "Hiding Done and Dependent Items"). ALT-O makes the current item depend
  on the marked items (its prerequisites), after a Y/N question, adding to
  any it has; with nothing marked, ALT-O on a dependent item offers to
  clear its dependencies. An item cannot depend on itself, even through
  others. While a prerequisite is not done the item waits, shown with "&";
  discarding a prerequisite drops it. View ▸ Hide ▸ Pending (Agenda's "Hide
  dependent items", "[Hide Dependent]" in the title) hides waiting items
  until every prerequisite is done or discarded, also when done items are
  hidden too (the Q&A's bug). Item Properties shows "Dependencies: depends
  on 2 · 1 depends on it". As in Agenda, a dependent item can still be
  marked done or discarded first. Search ▸ Depends and Search ▸ Prereqs
  (Agenda's Utilities Show Depends / Show Prereqs) list, in the Show View,
  the items depending on the highlighted one or the items it depends on:
  One level, All levels (the whole chain), or Every item in the file that
  has dependents (or prerequisites); ALT-F8 returns.

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
- **R14c ✅ Date languages** (not in Agenda). Dates and times can be typed
  in another language than English, chosen when the program starts:
  `--lang=swedish`, with an optional second language, `--fallback=english`,
  whose phrases are read as well (where both match the same words, the
  main language wins; without a fallback only the main language and ISO
  dates are read). It applies to every date typed: item text, date
  columns, the When prompt and date filters. Nothing else changes: menus,
  messages and how dates are shown stay as they are, and the file does
  not record the language. Each language is a pack
  (`Agenda.Core.DateLanguage`): its words, phrase patterns, day/month
  order and clock. Swedish reads weekdays ("fredag", "på fre", "nästa
  fredag", "förra måndagen", "i fredags" = the latest past Friday), days
  ("idag", "i morgon", "i övermorgon", "i går", "i förrgår"), "den 5
  november", "5:e nov", "den femte november", "5/11" as day/month, "om två
  dagar", "för 3 veckor sedan", "nästa vecka", "i slutet av månaden",
  times on a 24-hour clock ("kl 15", "kl. 9.30", "15:30"), "förmiddag",
  "eftermiddag", "i kväll", "om 2 timmar", and recurring dates ("varje
  måndag", R14a). Bare abbreviations ("fre",
  "sön") count in item text only after "på", "till" or "senast" ("tor" not
  at all, being a name); "nu" and a lone "morgon" are not read.
- **R14a ✅ Recurring dates** (User's Guide 6-10, 7-11 to 7-12). A date
  with "each", "every" or "evry" recurs: "every Monday", "every other
  Monday", "every day", "every 2 weeks", "every month", "every quarter",
  "every three months", "every year", "the 30th of every month", "the
  fifteenth of each month" (Swedish: "varje måndag", "varannan fredag",
  "var tredje månad", "varje kvartal", "den 15:e varje månad"). The first
  date is the base date: the next such weekday (today if it is today), the
  day of the month this month or next, or today for the others. The item
  keeps the rule (`Item.recurrence`, language-neutral), read from its text
  or typed into the When column / ALT-F2; an explicit plain When date, or
  an edit that removes the phrase, ends it. Marking a recurring item done
  (F4, the profile's Done, or bulk done) dates it done and adds a copy
  right after it: same text, note, time, alarm and assignments, with the
  next date counted from the base date; months keep their day (the 30th
  falls on the 28th in February and on the 30th again in March), so the
  cases Agenda 2.0 got wrong in Lotus's support Q&A (the 30th drifting,
  "every quarter" as every six months, "every three months" as two) come
  out right. Item Properties shows the rule ("When (2026-10-12) · every
  Monday"), and F4 says when the next one is. Not done: the "Can use
  recurring dates" property of date categories (only When recurs),
  recurring items in datebook views, and "every day starting …".
- **R14d ⏳ More date phrases.** Working days ("in five working days"),
  "this quarter", "first Wednesday in November", "next April", dates from
  notes, "$Monday" (a relative date kept as first read), and settings for
  date order (day/month) and the start of the week.
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
- **R15a ✅ Date and numeric conditions** (User's Guide 20-5 to 20-7). A
  category's conditions can name a date or numeric category: choosing one
  in the conditions box opens the Date Condition or Numeric Condition box
  (the filter box of R28a): Show items (Assigned, Not assigned = without a
  date or number), Start and End date (or Minimum and Maximum; blank ends
  are open, both blank means any), Inside or Outside range. Items in the
  range are assigned conditionally and let go when they leave it, when
  their date or number changes, and, for relative dates ("beginning of
  this week" to "end of this week"), when the date changes: the clock
  tick re-checks every item on a new day. Dates are read in the reader's
  date languages (R14c). A category cannot have a condition on itself.
  The condition shows like a filter ("if When 2026-10-05..2026-10-09").
- **R15d ⏳ Text conditions** beyond the category name and short name
  ("Also match"; User's Guide chapter 19).
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
- **R28a ✅ Date and numeric filters** (User's Guide 11-5 to 11-12).
  Choosing a date or numeric category in the filter box opens the Date
  Filter or Numeric Filter box: Show items (Assigned, the default, or Not
  assigned: items without a date or number), Start and End date (or
  Minimum and Maximum value; blank leaves that end open, both blank means
  any date or number) and Items should be (Inside or Outside range).
  Relative dates ("monday", "today") are kept as typed and read again
  every day, so "monday" to "friday" is always this week. The filter
  shows in brackets ("[When 2026-11-05..2026-11-09]", "not" for outside).
  An item typed into the view or section gets the start date or minimum
  (with only an end: the end; outside the range: the day or number just
  before the start, or just after the end). ENTER applies, DEL removes
  the filter, ESC cancels. Not done: browsing the date filter (View
  Browse, ALT-B; with datebook views).
- **R29 ✅ Numeric columns** (User's Guide chapter 8). A numeric category
  holds a number for each item assigned to it; the number is a value of
  the assignment, not a category. A standard category becomes numeric
  with Category Properties ▸ Type (only that way; a numeric category cannot
  change back); its children, if any, are removed and their items get the
  child's name as their number ("112" → 112, other names → 0), items
  assigned to the category itself get 0, and Agenda asks first when items
  or children are affected. A category with grandchildren cannot be
  converted. Typing in a numeric column enters a number (signs,
  parentheses for negatives, a currency or % symbol, thousands separators
  and "3.22e+12" are accepted; anything else is refused); F2 edits it in
  full, DEL removes it, and the title bar shows "#" while the highlight is
  in a numeric column. Numbers are right-aligned and shown in the column's
  format (View ▸ Column ▸ Properties): label or currency symbol (None, $,
  %, ¢, £, ¥), decimal places (2; numbers are rounded for display only),
  thousands separator, negative style (-1 or (1)), and the calculations
  shown at the bottom of every section: count, total (the default),
  average, minimum, maximum. A number too wide for its column is shown in
  scientific notation. Items sort by their number (R36), Item Properties
  shows and edits it, the assignment profile asks for it, and printing to
  a file includes the calculations. Our choices: numbers are binary
  floating point, as in Agenda; the decimal and thousands characters
  default to "." and "," until personal preferences exist (Utilities
  Customize); calculation lines are not shown under collapsed sections.
  Not done: the "% of total" column, section-wide calculation settings
  (Section Properties ▸ Select numeric functions), choosing the category
  type when adding a column, and numeric ranges in conditions and filters
  (with the date filters, next on the roadmap).
- **R36 ✅ Sorting items** (User's Guide chapter 15). A view has sort
  settings for all its sections; a section can override them or use the
  view's. Up to two keys (primary, then a secondary for ties): item text;
  a category — its children in hierarchy order or alphabetically, the
  date for a date category, the number for a numeric one; or a category
  note — a chosen line (Line number, default 1) of the note on the child
  the item is in, compared as text ignoring case (User's Guide 15-18: a
  town on line 2 of each person's note). Each key has an order (ascending,
  descending) and puts items without a value at the bottom or top. Ties
  keep entry order. Set in the Sort box (View ▸ Order, View ▸ Section ▸
  Sort). Our choice: sorting
  is applied whenever the view is shown, like Agenda's "When item is
  entered" setting, so "On leaving a section" and ALT-S re-sorting are not
  needed. ALT-F5 in the category manager sorts the highlighted category's
  children alphabetically (after Y/N); in the view manager it sorts the
  views. The view's Sort box also sorts the section heads (User's Guide
  15-20): Section sorting None (the order they were added in), Category
  order (as in the hierarchy), Alphabetic or Numeric (names that are not
  numbers last), and Section order ascending or descending; the sections
  are shown sorted, and GO TO lists them as shown. Not done: Agenda's
  Numeric and Date sequences for a category's children.
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
  saved when it is closed, so all replacements are one undo step. After a
  single (not global) replacement, ALT-S replaces the next occurrence
  (confirming first if asked to), as the Help's "Search & Replace in
  Note/Macro Box" describes.
- **R40 ✅ Colour themes** (Setting Up Agenda 1-25 to 1-31). The screen is
  drawn with a theme chosen at start: `classic` (blue and white, like DOS
  Agenda; the default) or `mono` (bold, dim, underline and reverse only).
  `--theme NAME` or `--mono` choose it; the NO_COLOR environment variable
  selects mono unless `--theme` is given. The theme is a personal
  preference, not part of the file, as in Agenda, where Utilities
  Customize set Color (Mono, Color, Plasma or Custom, with a colour for
  each screen element) for all files. Not done: choosing the theme or
  custom colours inside the program (Utilities Customize, on the roadmap).
- **R41 ✅ Date display format** (User's Guide 6-20 to 6-22, 7-13 to 7-15).
  File ▸ Properties sets how the file displays dates and times, as
  Agenda's global Display format: Date format (Agenda's 14 orders, from
  MMDDYY to DDMMMYYYY), Date separator (- . , space : /), Clock (24 or 12
  hr; 12 shows am/pm) and Show day of week, with a formatted sample. It is
  stored in the file and used everywhere a date is shown: date columns,
  the title bar clock, Item Properties, the alarm list, messages and
  printing. Our choices: the default is YYYYMMDD with "-" and a 24-hour
  clock (ISO 8601) rather than Agenda's MMDDYY with "/" and 12 hours;
  dates with a month name always use spaces; dates offered for editing
  stay ISO 8601. Not done: per-column overrides (Column Properties),
  Display date and/or time, Day #, Week # and Relative formats, the am/pm
  and hm time options, and the Input format settings.

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
| ALT-F5 | GO TO a section (R42) | Sort a family |
| ALT-F10     | Move item                                                           | Move under a new parent |
| ALT-D/U/R/L | Add section below/above, column right/left                          |                         |
| INS         | New item / additional column entry                                  | New category below      |

Category manager navigation (from the manual): ↑/BACKSPACE, ↓/ENTER,
HOME = parent, END = last of family, CTRL-PGUP/PGDN = previous/next
sibling, CTRL-HOME/END = first/last.

- **R42 ✅ The original keys** (Help: "Agenda Key and Menu Charts", in
  `docs/reference/Agenda 2.0 Help File.html`). Keys follow Agenda's charts;
  where we added a key of our own it must not take one Agenda used for
  something else. In views: ALT-F5 GO TO (a list of the view's section
  heads; ENTER highlights the chosen one), ALT-N / ALT-P next / previous
  view, ALT-W save, ALT-G retrieve, ALT-Q quit, ALT-V show/hide empty
  sections, ALT-K show/hide the key map, ALT-I insert an item. In the
  category manager: ALT-R insert a child, ALT-L insert an "uncle" (a
  sibling of the parent, after it), ALT-D / ALT-I insert a sibling below,
  ALT-U above. In notes: ALT-D / ALT-T insert today's date / the time,
  ALT-N / ALT-P go to the note of the next / previous item (or category).
  ALT-F5 used to open the Sort box (R36); the Sort box is now reached
  through the menu. ALT-K and ALT-Q also work in the managers and in notes
  (ALT-Q saves the note first). In a note, ALT-N / ALT-P save it and move
  the highlight with them: in a view to the next / previous item (or, for
  a section's note, section), in the category manager to the next /
  previous category; elsewhere they do nothing. Not done: a category added
  to a family whose other members are all sections of a view does not
  become a section of that view (User's Guide 16-11).
  Later, with their features: ALT-F9 copy, ALT-Y yank back, ALT-H hop,
  ALT-B browse, ALT-C calendar, ALT-O dependency, ALT-E / ALT-X execute
  conditions and actions, ALT-Z run macro, ALT-S sort now.

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

The macro command language (Working with Macros, chapters 2–3; Learn-mode
keystroke macros are on the roadmap), printing to a printer and print
preview, TXT2STF definition files, networking/file reservations, application
protection, the Metro accessories.
