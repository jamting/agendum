# Wol's Agendum — behaviour specification

What Wol's Agendum does, and what it clones from Lotus Agenda ("Agenda" below): distilled from US patent 5,115,504 ("Information
Management System", Belove, Kapor, Kaplan et al., Lotus 1992) and the Lotus
Agenda 2.0 manuals. Rules are numbered so tests and commits can refer to them.
✅ = implemented and tested, ⏳ = planned (see `ROADMAP.md`).

## 1. Concepts

| Concept               | Meaning                                                                                                    | Code                   |
| --------------------- | ---------------------------------------------------------------------------------------------------------- | ---------------------- |
| **Item**              | A free-form piece of text (up to a few lines), with an optional note. Exists independently of categories.  | `Agendum.Core.Item`     |
| **Category**          | A named node in one hierarchy rooted at **MAIN**.                                                          | `Agendum.Core.Category` |
| **Link / assignment** | An independent many-to-many link between an item and a category (the patent's "link structures").          | `Agendum.Core.Links`    |
| **View**              | A saved arrangement: **sections** (each headed by a category) and **columns** (each headed by a category). | `Agendum.Core.View`     |
| **Date category**     | Entry, When, Done and ones the user makes: categories whose membership is an item's date.                  | `Database.item_date/3` |

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
- **R6a ✅ Date categories the user makes** (User's Guide 6-3, 7-2 to
  7-4). Besides Entry, When and Done, any standard category without
  grandchildren can become a date category (Due, Review, End): Category
  Properties ▸ Type offers Numeric or Date. Its children whose names are
  dates ("November 20, 1990", "today") become their items' dates, the
  others are dropped, and items assigned to the category itself get no
  date; when items or children are affected, Agenda's question comes
  first ("Make Review a date category? children become dates; dropped:
  after the meeting (Y/N)"). Like Agenda, a date category cannot change
  back, matches no text, and has no children, exclusivity or negative
  links. Each item has at most one date and time in it, typed in its
  column ("next friday 3pm"), set in Item Properties or by an action; it
  makes the item a member, works in sorting, filters and conditions, and
  is cleared with DEL. Assigning dates automatically (Assign item date,
  Which one, the Done and When keys) is R6b.
- **R6b ✅ How date categories get dates** (User's Guide 7-5 to 7-8).
  Category Properties ▸ Date settings opens a date category's Advanced
  settings box (SPACE/→ next choice, ← previous; each change one undo
  step). Assign item date: Never; from the clock When item is entered,
  When item text is edited (also on entry), When note text is edited,
  When item or note text is edited, When item is assigned (on entry and
  on joining another category) or When item is assigned or edited; or
  From the item text, From the note text or From the item or note text.
  Which one (1–10, for the text choices) takes the nth date: a date and
  the time next to it count as one, a time alone is today's ("Status
  meeting from 10:00 to 2:30": When takes 10:00, an End category with
  Which one 2 takes 2:30). Set date from Done key / When key: F4 or ALT-F2
  also sets this date (F4 the current date and time, ALT-F2 the When
  date). Defaults as Agenda's: Entry when entered, When from the item
  text with the When key, Done never with the Done key, a new date
  category never; Done always takes the Done key and When the When key.
  Dates from the clock keep the time, except Entry and Done, which keep
  the day; Entry always gets the day an item is entered. A date set by
  hand (typed, Item Properties, ALT-F2, F4) stays when the text changes;
  dates from text are read once, as for When (R14).
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
- **R9 ✅ General negative links** (not in Agenda 2.0; the patent's
  negative links, FIG. 6, which Agenda only offered between siblings as
  R7). Category Properties ▸ Excludes opens a category list in which
  ENTER toggles a negative link (marked "x") between the two categories:
  no item may then be in both, or in their subcategories. Assigning an
  item to one (or below it), directly, by a category link or by an
  action, takes it out of the other and its subcategories; text matching
  never puts an item in both, and an assignment the item has wins over a
  new text match. The link is kept on both categories, shown in the
  manager ("not with Vacation") and dropped when either is discarded. It
  is refused between a category and itself, its parents or children,
  MAIN and date or numeric categories, and while items are in both ("2
  items are in both Work and Vacation; move them first"); a category
  cannot be moved under one it excludes.
- **R43 ✅ Item dependencies** (User's Guide 13-12 to 13-16; Lotus Q&A
  "Hiding Done and Dependent Items"). ALT-O makes the current item depend
  on the marked items (its prerequisites), after a Y/N question, adding to
  any it has; with nothing marked, ALT-O on a dependent item offers to
  clear its dependencies. An item cannot depend on itself, even through
  others. While a prerequisite is not done the item waits, shown with "&";
  discarding a prerequisite drops it. View ▸ Hide ▸ Pending (Agenda's "Hide
  dependent items", "[Hide Dependent]" in the title) hides waiting items
  until every prerequisite is done or discarded, also when done items are
  hidden too (the Q&A's bug). Item Properties lists by name the items it
  depends on ("Depends on") and those depending on it ("Needed by"), done
  ones ticked √; SPACE on one opens its Item Properties (ESC comes back),
  DEL removes that one dependency. As in Agenda, a dependent item can still be
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
  in another language than English, chosen in File ▸ Customize (Date
  language, Fallback language; saved in the person's preferences, R41b)
  or for one session with `--lang=swedish`, with an optional second
  language, `--fallback=english`,
  whose phrases are read as well (where both match the same words, the
  main language wins; without a fallback only the main language and ISO
  dates are read). It applies to every date typed: item text, date
  columns, the When prompt and date filters. Nothing else changes: menus,
  messages and how dates are shown stay as they are, and the file does
  not record the language. Phrases kept in the file and read again each
  time (a date filter's ends, a datebook's base date, a date action's
  date) are read in the person's languages and then in English, so a file
  made in English, such as a starter file, works in every language
  (ADR 0029). Each language is a pack
  (`Agendum.Core.DateLanguage`): its words, phrase patterns, day/month
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
  recurring items in datebook views and date filters (planned:
  `docs/plans/RECURRING_OCCURRENCES.md`), and "every day starting …".
- **R14d ✅ More date phrases** (User's Guide 6-7, 6-10 to 6-11, 7-16).
  Working days ("in five working days", "3 working days ago") skip
  Saturday and Sunday. Quarters ("this/next/last quarter", "end of the
  quarter", "first quarter"; the first to fourth quarter is this year's
  unless it has ended) and years ("end of the year"). The nth or last
  weekday of a month ("first Wednesday in November", put in the future
  like other dates without a year; "the last Friday of the month",
  "second Monday of next month") and a day of a month ("the 15th of next
  month"). A month alone means its first day: on its own ("April") it is
  this year's unless the month is over, "this April" this year's, "next
  April" the first after this month, "last April" the last before it;
  "end of next March" is its last day. In item text a month alone counts
  only after "next", "last", "this", "in", "by", "until" or "during" ("May"
  only after "next" or "last"; in Swedish only full names, so "i jul"
  stays Christmas). Calendar notation can use a month abbreviation
  ("Nov/12/90"). Swedish has the same phrases ("om fem arbetsdagar",
  "första onsdagen i november", "i slutet av nästa mars").
- **R14e ✅ Global date settings** (User's Guide 7-13 to 7-17). File
  Properties ▸ Global date settings opens Agenda's Global Date Settings
  box (boxes nest as in Agenda: File Properties holds Global date
  settings ... and Auto-assign settings ...; Global Date Settings holds
  Display format ..., Input format ... and the settings below; SPACE or →
  opens a "..." row, ESC goes back one box), saved in the file:
  Beginning and End of week (Mon and Fri: "this week" and "next week"
  start on the first day, "end of week" is the last, "this Monday" is in
  that week, and working days are the days from the first to the last);
  First quarter (the month quarters start in, Jan); Beginning of year
  (the month "this year" starts in, Jan; the year ends the day before the
  next one starts); Month alone means (First day, Last day or Day 2–31, a
  short month's last day if it has fewer); and the times of Morning
  (8:00), Afternoon (14:00) and Evening (17:00, also "tonight"). Morning
  also starts the twelve hours that times without am/pm fall in (with
  9:00, "at 8:00" is 8 pm). Settled differently from Agenda: number
  order stays with the reader's date language (R14c, ADR 0009), not the
  file; quarters and years start on the 1st of a month; Agenda's separate
  End of year is the day before the next Beginning of year. The
  settings apply to dates read from then on, and to relative dates in
  filters and conditions, which are read anew.
- **R14f ✅ Fixed relative dates and dates from notes** (User's Guide
  6-7, 7-6 to 7-7, 7-11). A "$" before a relative date in a date range
  of a filter or condition ("$Monday", "$ end of next week") reads it
  once, when the range is set, and keeps that date (shown as a date
  from then on); without "$" the words are read again each day.
  When's Assign item date (R6b) says where When dates are read from:
  From the item text (default), the note text, the item or note text
  (the item's first, else the note's) or Never (what Utilities ▸ Dating
  toggles). A note's date is read when the note is saved, by the same
  rules as item text (read once; removing it clears the date; a date set
  by hand stays).
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
- **R15d ✅ Text conditions** (User's Guide 19-2 to 19-5). Category
  Properties ▸ Also match holds words and phrases that pull items into the
  category as its name does: `;` separates alternatives (any), `,`
  conditions that must all hold; a word or phrase matches when its words
  are there, in any order, by the file's matching settings (R16a), and
  in parentheses only in that order (`(meet with)`); `^` matches its
  words as they are, ignoring no suffixes (`^eats`); `!`
  before one means the item must not contain it (`Cost,!Deduction`), `~`
  that case must match (`~LOTS`); `?` is one character and `*` any
  characters within a word (`Budget??`, `sl*`); `\` makes the next
  character plain text. Text conditions work even when the category does
  not match its own name. New ones reach existing items with Recalc. Not
  done: Agenda's `"` (exclude words).
- **R15b ✅ Actions** (User's Guide chapter 21). When an item joins a
  category, by the user, a condition or another action, the category's
  actions run once: Category Properties ▸ Assignment actions lists them
  ("Sales, -Receivables, When=tomorrow, Amount=150"); in its box ENTER on
  a category cycles assign (a category link, R8) → remove (break the
  item's assignment there) → none, and a date or numeric category opens
  the Date / Numeric Action box: give items a date (an expression read
  when the action runs, in the reader's languages) or a number, or remove
  it. Special action: None ("No action" in the box, as Agenda), Mark items done (today, recurring items get
  their next one) or Discard items. A parent's actions also run for items
  that join its children, children's first; special actions run last.
  Actions make explicit assignments, which stay when the triggering one
  is broken, and do not run again when an item changes while it stays in
  the category. Not done: the Export special action (with structured
  files, Milestone 4) and turning actions off per category or file.
- **R15e ✅ Utilities Execute** (User's Guide 20-19 to 20-21, 21-17). New
  conditions, text conditions and actions do not reach items already in
  the file until executed. Category ▸ Execute opens the Execute box: Apply
  conditions of (a category and its children; MAIN for all), Against (all
  items, the current item, the marked items, the items in the section or
  the view) and Apply actions to (new assignments only, or old & new:
  the actions also run for assignments the items already had). ALT-X
  executes everything on all items; ALT-E the highlighted category's
  family (in a view: the section's category). Category ▸ Recalc still
  re-runs automatic assignment and dating for every item.
- **R16 ✅ Suggested assignments** (User's Guide 19-9, 19-12). File
  Properties ▸ Auto-assign settings ▸ Confirm assignments: Never (the
  default; text matches are assigned at once), Always, or Sometimes (only
  partial matches, R16a, are suggested; full ones are made). Suggested:
  an item's text matches become suggestions
  instead, "?" shows in the title while any wait, and Category ▸ Questions
  (Agenda's Utilities Questions) shows each such item in turn with its
  suggested categories: SPACE picks one, TAB all, ENTER assigns the picked
  ones (explicitly, so an edit does not take them away) and goes to the
  next item, ESC stops. Editing an item asks again about what its new text
  matches; discarding the item or the category drops the question.
- **R16a ✅ Text matching settings** (User's Guide 19-7 to 19-12, 19-15
  to 19-16). File Properties ▸ Auto-assign settings opens Agenda's
  Auto-assign Global Settings box (SPACE/→ next choice, ← previous; each
  change one undo step): Text matching On/Off (Off: no names or text
  conditions match); Match on Item text (default), Note text or Both
  item & note (a note is matched when saved, and a match from it breaks
  when it stops matching, R15c); Required match strength: Exact match -
  100% (default; every word of a name, short name or text condition, in
  any order), Partial match - 50% (at least half) or Minimal match (one
  word), as in the manual's "Suggestions for design"; Confirm assignments
  (R16); Ignore text enclosed by: " " (default, also “ ”), < >, ' ', { },
  [ ], # #, ( ), / /: that text is left out ('set a "margin" command'
  does not go to Margin); Ignore suffixes Yes (default): -able, -al, -ly,
  -ally, -d, -ed, -er, -est, -ible, -ing, -ment, -s, -es, -wise, and for
  words ending in y -ied, -ier, -ies, -iful, -ily, so Show matches shows,
  showing and showed; words of three letters or fewer match exactly ("buy"
  is not "buying"); Ignore accents No (default; Yes: résumé matches
  resume). Words are read as Agenda does: a word starts with a letter or
  digit and may hold ' - _ ("can't", "high-capacity"); a possessive 's
  is dropped. A text condition in parentheses must have its words in
  that order ("(meet with)"), and "^" before one matches its words as they
  are, ignoring no suffixes ("^eats"). A name with other characters
  ("C++") matches as written. Proper names and titles: R16c.
- **R16b ✅ Text matching for one category** (User's Guide 19-8,
  19-14 to 19-15). Category Properties ▸ Advanced settings of a standard
  category (for a date category it holds R6b's date settings) sets Text
  matching, Match on, Required match strength, Confirm assignments,
  Ignore suffixes and Ignore accents for that category only; each is
  Global (the file's, shown in brackets: "Global (Item text)") until set,
  and cycles back to Global. Ignore text enclosed by is the file's only.
  A category matches with its own settings (Budget on the note while
  others match the item text), suggests or assigns by its own Confirm
  assignments, and the category manager marks its own Match on with
  "T= Note" as Agenda does. The row sums up what the category sets
  ("Match on: Note text") or says Global.
- **R16c ✅ Proper names and titles** (User's Guide 19-17). A category
  name or short name with two or more consecutive capitalized words holds
  a proper name ("Nancy Wohl"; hence the manual's advice to write
  "Status report", not "Status Report"). The name matches when the text
  has its last name, exactly (no suffixes ignored), alone ("Send it to
  Wohl"), after a title ("Mrs. Wohl") or after one of its own first names,
  but not after another capitalized word ("John Wohl" is someone else)
  and not on the first name alone; a capitalized word starting the text
  or a sentence does not count ("Call Wohl"). Required match strength does
  not apply to the name; other words of the category name match as usual
  ("visit Nancy Wohl" matches "Visiting Mrs. Wohl"). Titles, with or
  without a period: Mr, Ms, Miss, Mrs, Messrs, Dr, M, MM, Monsieur,
  Madame, Mme, Mmes, Mademoiselle, Mlle, Mlles, Herr, Hr, Frau, Fr,
  Fräulein, Fri, Fru, Fröken, Frk. "Michael Schaeffer" in an item matches
  Michael, Schaeffer and Michael Schaeffer, not Michael Rowles.
- **R15c ✅ Text matches as conditional assignments** (User's Guide 18-3).
  An assignment made because the item's text matched a category (its name,
  short name or text conditions) is conditional, marked "(c)" in Item
  Properties, and is broken when the text no longer matches and no other
  condition holds ("Meet with John" in Meetings; edited to "Telephone
  John", it leaves). An assignment the user makes is explicit and stays.

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
  (User's Guide 19-2). Each section has its own columns (R55).
- **R22a ✅ Fit column to contents** (Agenda's SHIFT-? in View ▸ Column ▸
  Width, User's Guide 5-21). SHIFT-? while choosing a width sets the
  highlighted column's width to the
  widest of its head and the entries of the items the view shows at that
  moment (collapsed sections left out), with full names rather than short
  ones and its calculation lines; at least 3, at most 80. It is done once:
  the width does not follow later changes. One undo step. A linked column
  (R55) fits the entries of every section it is in.
- **R55 ✅ Columns per section** (User's Guide 3-16, 3-27, 5-22 to 5-25;
  screenshots 42, 60, 127). A column belongs to one section or to all.
  - Added to all sections (the default), it is *linked*: one column shown
    in several sections, so changing its width or format in one changes
    all of them. Added to one section, it is not linked and changes alone.
    Each column added is a column of its own, even with the head of
    another: a section can show When twice, and removing or widening one
    leaves the other alone (as Agenda does, checked in DOSBox).
  - View ▸ Column ▸ Move, or ALT-F10 on a column head (User's Guide 5-20):
    ← → (or < >) move the highlighted column in its section, shown at
    once; ENTER keeps the place (one undo step), ESC puts it back. Only
    the current section changes, even for a linked column, which stays
    linked. On the item text it moves the item column among the columns
    (not in a datebook view, whose item text stays first): the columns
    left of it are drawn before the bullet, and → ← go through the columns
    as they are shown. A column added right or left of the item text or
    of a column (ALT-R, ALT-L, the Column Add box) lands there, and the
    item column keeps its place when columns are added or removed.
  - Where the other sections get it (ours; Agenda does not say): beside
    the same column as where it was added (after the column on its left,
    or else before the one on its right), at the end when the section has
    neither: in a section with two of that head, beside the one linked
    to it.
  - Removing a column that is linked into other sections asks: *All
    sections in view* (it goes from every section it is in; other columns
    of the same head stay) or *Current section only*.
  - A new section (ALT-D, ALT-U) gets the linked columns of the section the
    cursor was in (ours).
  - Each section's item text fills the width its own columns leave, so a
    column every section has stays in the same place (screenshots 42, 60).
  - Item Column Properties (View ▸ Column ▸ Properties on the item text;
    User's Guide 3-18 to 3-19, Help "Item Column Properties Box"): the
    Section head (F3 picks another); Set width Automatically (the default:
    as wide as the section's columns leave, at least Minimum width, 10) or
    Manually (Width, the columns following right after it; Manually starts
    at the width the text has then); Link with other sections (Yes by
    default): linked item columns change together, No makes one change
    alone, Yes again takes the linked ones' settings. Widths 5 to 200
    (Agenda: 77, its screen). A new section gets the linked ones'
    settings. Each change is one undo step. A datebook view's item text
    always fills what its columns leave.
  - A datebook view's slots share one set of columns (R47).
  - Files from before this keep every column in every section, linked.
    Files that marked columns only as linked (formats 25, 26) get one
    column for the first linked column of a head in each section, another
    for the second, and so on.
  - File Properties ▸ Insert new columns in (screenshots 130, 131): All
    sections (the default) or Current section, for the file; it decides
    where ALT-R and ALT-L put a new column.
  - A new column is 16 wide for a date category (a date and a time), 12
    for others.
  - Column Properties ▸ Link with other sections (screenshot 127): No
    unlinks the column, which changes alone from then on. Yes links it to
    a linked column of its head that is not yet in its section, taking
    its width and formats; when there is none, to an unlinked column of
    its head with the same width and formats in each other section
    (Agenda: "the same column head, category type, format, and width").
    Yes on a linked column changes nothing.
  - Column Properties ▸ Column head (screenshot 144): F3 (or SPACE) picks
    another category from the whole hierarchy; the column and the columns
    linked to it show it instead, staying a column of their own; an
    unlinked one changes alone.
  - Typing on Column head, in Column Properties or the Column Add box
    (User's Guide 3-17: "the name of a new or existing category"), gives
    the category of that name, case aside, or a new one under MAIN; a
    name several categories have is left to F3. ESC drops the name. In
    Column Properties the head changes with it, one undo step; in Column
    Add a new category is made at once and the column waits for ENTER.
  - The column heads on a section head line can be highlighted (→ / TAB,
    User's Guide 5-22, 5-25), so an empty section's columns can be reached:
    DEL removes the column (asking which sections, as above), F3 replaces
    the column head, F6 opens Column Properties, and F2 renames the head's
    category (ours; the manual does not say).
  - Column Properties is one box for every column, as in Agenda
    (screenshot 142): Column head, Category type (shown), Width (→ ← by
    one) and Link with other sections at the top; below a rule, a numeric
    column's Numeric Column Properties (R29) or a date column's Date
    Column Properties (R41a), with formatted samples.
  - View ▸ Column ▸ Add opens the Column Add box (User's Guide 3-15 to
    3-18): Column head (typed, or F3, SPACE or → picks it; ENTER without
    one too),
    Category type (Standard, Date or Numeric: a standard head, or none yet,
    can be given another type, which it gets when the column is added,
    after the question Category Properties asks when children or items
    would change; a date or numeric head keeps its type, as in Agenda;
    User's Guide 3-17), Width (→ ← by one, starting at the default for
    the type), Position (Right of current column, the default, or Left) and
    Insert in (All sections or Current section), which starts at the
    file's Insert new columns in and overrides it for this column. ENTER
    adds the column, one undo step; ALT-R and ALT-L skip the box. The
    View ▸ Column menu follows Agenda's (screenshot 9): Properties, Add,
    Remove, Move, Width.
  - View ▸ Column ▸ Width (User's Guide 5-21 to 5-22): the control panel
    shows the highlighted column's width; ← → change it by one, a typed
    number replaces it, SHIFT-? fits it (R22a), at least 1 and at most 80.
    The view shows the new width at once; ENTER keeps it (one undo step,
    in every linked section), ESC goes back. On the item text (a section
    head or an item) it is the section's item column: it starts at the
    width the text has, a width chosen sets it Manually (5 to 200), and
    SHIFT-? fits it to the longest item text or section name of the
    sections it is linked with, within what the columns leave.
- **R56 ✅ Standard column formats** (User's Guide 5-26 to 5-37; Help
  "Standard Column Properties/Add Box"; screenshot 127). Column
  Properties ▸ Format, for a standard column, in it and its linked
  columns:
  - Name only (the default): the names of the head's descendants the item
    is assigned to (`*` when the head has no children).
  - Parent:Category: each with its parent's name before it ("Sales:Tom").
  - Ancestor: the head's child each is under ("Sales" for Tom), once.
  - Star (*): `*` when the item is in the head, directly or through a
    descendant; Yes/No: `Y` or `N` the same way.
  - Category note: line Line number (1 to 999) of the notes of the
    categories Name only would show, without a label before a colon
    ("Telephone: 555-1234" shows "555-1234"), headed by Column title (at
    most 69 characters; the head's name when blank) instead of the head;
    File ▸ Print uses the title too.
  - Too narrow, Name only, Parent:Category and Ancestor use short names.
  - Typing (User's Guide 5-31 to 5-37): in a Star column SPACE stars an
    item (assigning it to the head itself, unless it is in it already) or
    unstars it (out of the head and every category under it); in a Yes/No
    column Y and N do the same. Other letters type a name, as in Name only.
    DEL unstars too. In a Category note column the text typed, or edited
    with F2, becomes that line of the note of the item's category there
    (the first, if several), after the label the line had; DEL empties it;
    an item with no category there is told so. One undo step each.
  - The Column Add box has Format too, for a standard column, with Line
    number and Column title for Category note; a Star or Yes/No column
    starts 2 wide (User's Guide 5-31, 5-33), so a column can be 1 wide
    (Agenda's 1 to 76; ours up to 80).
- **R57 ✅ Hide column heads** (User's Guide 5-14 to 5-15, 15-21;
  screenshots 55, 67, 69, 71, 143). A view setting, No by default: with
  Yes, column heads show only on the first section head on the screen
  (after scrolling, the first one shown), so heads that every section
  repeats are not drawn again; the other section heads keep their names.
  Set with View ▸ Hide ▸ Column heads (Agenda: View Properties ▸ Hide
  column heads; ours until View Properties is a box; in a datebook view
  also its settings box, as Agenda's), one undo step. Our
  choices: a section head whose column head is highlighted shows its
  heads, so the highlight can be seen; File ▸ Print to a file still names
  each column, as it labels every entry with it. In a datebook view the
  first slot on the screen shows them.
- **R58 ✅ Section separators** (User's Guide 5-12, 15-21; screenshots 48,
  54, 143). A view setting, No by default: with Yes, each section head is a
  line across the screen, the section's name and its column heads on it,
  in place of the blank line before the section, so more fits on the
  screen. The highlight on a section head covers its name only. Set with
  View ▸ Section ▸ Lines (Agenda: View Properties ▸ Section separators;
  its index has them under "Lines"; ours until View Properties is a box;
  in a datebook view also its settings box), one undo step. With Hide column heads (R57), the other section heads are
  their names on a plain line. Our choices: a datebook view's slots are
  lines either way (R47); File ▸ Print to a file has no lines, as Agenda
  printed none ("The lines between sections do not appear when you
  print").
- **R59 ✅ The note symbol and NOTE for what is highlighted** (User's
  Guide 12-2 to 12-4; screenshot 126). In a view, ♪ at the right of the
  control panel's second line shows that what the highlight is on has a
  note: the item, the section head's category, a column head's category,
  or the category a column entry stands for, the first the entry shows
  (a Star or Yes/No entry: the head, when the item is in it). A date or
  a number is no category, so it has no note. NOTE (F5) opens that note:
  in a column, the column head's or the entry's category's (Agenda:
  "Highlight the item or category"), where it used to open the item's;
  on a date, number or empty entry it says "No category here to have a
  note". Item ▸ Note still opens the item's note.
- **R60 ✅ The Activities Planner starter file** (ADR 0028; Starter Applications;
  screenshots 37-144). A file shipped with Agendum,
  `starters/planner.agendum`, which a person copies and fills in, as
  Agenda's `apps\planner` was. No items. Its categories: People (Sample
  Person), Project (Sample Project), Tasks, Activity (Calls, Meetings,
  Mail, Reading, Follow up, Issues, Ideas), Expenses, Priority (High,
  Medium, Low), Contact List, Type (Lodging, Breakfast, Lunch, Dinner,
  Entertainment, Air, Transportation, Miscellaneous), Report ID (Sample
  Trip) and the numeric Amount; Priority, Type and Report ID have
  exclusive children. Short names and Also match find them in an item's
  text (Calls: Phone, Telephone; Lodging: Hotel, Motel, Inn). Catch-alls
  take what the others miss, by conditions: Unassigned (−People, Tasks),
  No Priority Assigned (−Priority, Tasks), No Type (Expenses, −Type);
  Miscellaneous Activity, Miscellaneous Project and No Purpose are there
  to assign by hand. An amount makes an item an expense (Amount's action
  Expenses). Its views: Tasks (where it opens), Activities and Priorities
  (with columns that differ per section), Calls (with Phone #, line 1 of
  the person's note), Completed This Week and Overdue (date filters),
  three expense views (Expenses only, totals, lines between sections),
  People, Projects, and the datebooks Today, Tomorrow, This Week, Next
  Week and This Month. Its macros, run from views: Customize date
  settings (File ▸ Properties), Hide/Display done items (View ▸ Hide ▸
  Done) and Print current view (Print). Our choices: the file's date settings are Agendum's defaults
  (Agenda's are American: weeks from Sunday, dates MDY, amounts in $);
  the Contacts view, which Agenda's "Create/Update contact list" macro
  made, is in the file, and Sample Person's note has the phone number and
  company it shows. The macros that need the command language (Sort items
  in view, Create/Update contact list) are left out.
- **R61 ✅ Section Properties** (Help "Section Properties/Add Box"; User's
  Guide 5-5 to 5-10). One section's settings in one box, opened with View
  ▸ Section ▸ Properties or F6 (PROPS) on a section head, as in Agenda
  (F6 on a section head used to open the head category's properties; F6
  on the box's Section head does that now). Section head: a typed name
  (a new category if no category has it) or F3 picks one; Item sorting
  opens the section's sort (R36); Section statistics says how many items
  the section shows; Select numeric functions (only in a section with a
  numeric column; User's Guide 8-10) opens a box of Count, Total,
  Average, Minimum and Maximum, Yes or No, for every numeric column of
  the section at once: they are the columns' own calculations (R29), so a
  linked column changes in its other sections too, and a function shows
  Yes when every numeric column has it; Filter opens the section's filter (R28); Columns
  lists the section's columns in their order with the item column as
  `<Items>`: DEL removes a column from this section only (the item
  column stays), ALT-↑ ↓ move a column or the item column (Agenda:
  ALT-F10), INS adds a column right of the highlighted one (Column Add,
  R55). Each change is one undo step. Not in a datebook view, whose
  sections are its dates (R47).
- **R62 ✅ Moving a section** (User's Guide 5-8 to 5-9). ALT-F10 (MOVE)
  on a section head, or View ▸ Section ▸ Move from anywhere in a
  section, moves it within its view: every section is shown collapsed
  (§ and its item count), ↑ ↓ (or < >) move it, ENTER keeps the new
  place (one undo step; the sections open again) and ESC puts it back.
  Only this view changes, not the category hierarchy. The file is not
  changed while it moves (ADR 0026). Our choices: a view that sorts its
  sections (View Properties ▸ Section sorting) says so instead, as the
  sort would put the section back; a datebook view's sections are its
  dates (R47).
- **R63 ✅ Marking, copying, cutting and pasting in a note** (User's
  Guide 14-4 to 14-8). F7 MARK anchors a region at the cursor; moving the
  cursor stretches it, either way and over lines, and it shows marked; F7
  again drops it, and typing drops it first. F3 COPY keeps the marked
  text, F4 CUT keeps it and takes it out, ALT-F4 DELETE takes it out
  without keeping it; with nothing marked each asks Word (at the cursor,
  or just before it), Line or All text. F2 PASTE puts the text kept at
  the cursor and keeps it, so it can be pasted again; one piece is kept,
  for the session, across notes. In a note F4 is CUT, as in Agenda (it
  used to close the note: ESC and F5 do). Not done: the same keys in
  item text and category names, and the system clipboard.
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
  with Category Properties ▸ Type or Column Add ▸ Category type (R55; a
  numeric category cannot change back); its children, if any, are removed and their items get the
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
  thousands separator, negative style (-1 or (1)), Display % of total (a
  "% tot" column beside the numbers, 5 wide, with each number's share of
  its section's total, rounded, as "12%"; nothing typed there, and
  printing to a file adds it after the number; User's Guide 8-7), and the
  calculations
  shown at the bottom of every section: count, total (the default),
  average, minimum, maximum (per column, or for all the numeric columns
  of a section at once with Section Properties ▸ Select numeric
  functions, R61). A number too wide for its column is shown in
  scientific notation. Items sort by their number (R36), Item Properties
  shows and edits it, the assignment profile asks for it, and printing to
  a file includes the calculations. Our choices: numbers are binary
  floating point, as in Agenda; the decimal and thousands characters
  are the person's (R54), "." and "," by default; calculation lines are not shown under collapsed sections.
  Not done: section-wide calculation settings (Section Properties ▸ Select
  numeric functions), and numeric ranges in conditions and filters (with
  the date filters, next on the roadmap).
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
  each occurrence is highlighted and a Yes/No box asks "Replace this
  occurrence?" (as the other questions; asked even with Confirm mode
  off, R54): Yes replaces it, No skips it, ESC stops. The box moves
  below the occurrence when it would cover it.
  Our choices: the search starts at the cursor and, when nothing is found
  after it, continues from the top (backward: the bottom), since a note
  opens with the cursor at its end; a global replacement covers the whole
  note; the box remembers its last settings; no length limit (Agenda
  allowed 25 characters); text never matches across lines. Each
  replacement is an undo step of its own (the note is saved as it is
  made; a global replacement without confirming is one step); the
  occurrence asked about stays highlighted behind the question box. After a
  single (not global) replacement, ALT-S replaces the next occurrence
  (confirming first if asked to), as the Help's "Search & Replace in
  Note/Macro Box" describes.
- **R40 ✅ Colour themes** (Setting Up Agenda 1-25 to 1-31). The screen is
  drawn with a theme chosen at start: `classic` (the default: Agenda 2.0's
  colours, from screenshots of the real program, ADR 0018), `mono` (bold,
  dim, underline and reverse only), or one of six terminal colour schemes
  (`docs/THEMES.md`): `modus_operandi`, `modus_vivendi`, `alabaster`,
  `zenburn`, `ayu` and `borland`.
  File ▸ Customize (Agenda's Utilities Customize) changes it at once and
  saves it in the person's preferences file (R41b); `--theme NAME` or
  `--mono` choose it for one session; the NO_COLOR environment variable
  selects mono unless `--theme` or the preferences name a theme. The
  theme is a personal preference, not part of the file, as in Agenda,
  where Utilities Customize set Color (Mono, Color, Plasma or Custom,
  with a colour for each screen element) for all files. Custom colours
  are not planned: a new look is a new theme (ADR 0022).
  - `classic`: black text on a grey screen; section heads, column heads and
    column entries in blue; the highlight white on red; title bar and
    control panel white (hints yellow) on blue; boxes cyan in a solid blue
    frame, the title centred in the frame, with a black shadow below and
    to the right, and the screen behind them greyed out; the category
    manager on cyan; help yellow on blue. The VGA colours are exact on
    terminals that take 24-bit colour (`COLORTERM=truecolor`), the nearest
    ANSI colours elsewhere.
  - A box opened from another box sits one line lower and two columns
    further right, so the one beneath still shows, and the titles of the
    boxes beneath are dimmed (our choice).
  - `mono` has the same parts in bold, dim and reverse video: the control
    panel in reverse video, the highlighted line in bold, box titles and
    dimmed titles, the faded screen behind a box.
  - The terminal schemes share one layout in their own colours
    (`Agendum.TUI.Terminal.Theme.Palettes`): the screen in the scheme's background
    and foreground; the control panel, menus and the line being edited in
    its selection colours; the highlight in its cursor colours; the
    highlighted line, boxes and the key bar on a tint of the background;
    heads, entries and box frames in its blue. Exact on 24-bit terminals;
    elsewhere they use the terminal's default colours and its ANSI
    colours, so a terminal set to the same scheme still shows it. Typed
    as `modus-operandi` or `Modus Operandi` too.
  - Our choices: the highlighted line is drawn in a lighter shade across
    the whole screen, so it shows when the highlight is in a column; Agenda
    put a » in front of it instead.
- **R41 ✅ Date display format** (User's Guide 6-20 to 6-22, 7-13 to 7-15).
  File ▸ Properties ▸ Global date settings ▸ Display format sets how the
  file displays dates and times, as Agenda's global Display format: Date format (Agenda's 14 orders, from
  MMDDYY to DDMMMYYYY), Date separator (- . , space : /), Clock (24 or 12
  hr; 12 shows am/pm) and Show day of week, with a formatted sample. It is
  stored in the file and used everywhere a date is shown: date columns,
  the title bar clock, Item Properties, the alarm list, messages and
  printing. Our choices: the default is YYYYMMDD with "-" and a 24-hour
  clock (ISO 8601) rather than Agenda's MMDDYY with "/" and 12 hours;
  dates with a month name always use spaces; dates offered for editing
  stay ISO 8601. More options and date columns of their own: R41a. The
  Input format settings: R41b.
- **R41b ✅ Input format** (User's Guide 7-14, 7-17). How a person types
  dates and times: Number order (MDY, MYD, DMY, DYM, YDM, YMD; "12/11/90"
  in DMY is 12 November 1990, and a month and day alone keep the order's
  sequence, "12/11" in DMY), Input date separator (/ - . , :; it replaces
  the slash, also after a month name: "nov.12") and Input clock (12 hr:
  "3:00" is 3 pm, between Morning and 12 hours later; 24 hr: as written).
  Each is "Language (…)" until set: the date language's numeric order,
  "/" and clock. Our choice (ADR 0008, 0013): these belong to the person,
  not the file, unlike Agenda; Global date settings ▸ Input format opens the
  box ("yours, for every file"), and a change applies at once, is not
  undone with the file, and is saved in the person's preferences file
  (`~/.config/agendum/preferences`, or under `$XDG_CONFIG_HOME`), plain
  `key = value` lines, which File ▸ Customize also writes (theme, date
  languages; it opens this box too). Only the setting changed is saved,
  never one a flag gave for the session. `--number-order`, `--date-separator` and `--clock`
  set them for one session. ISO dates (2026-10-20) are always read; with
  ":" as separator, "3:30" is a date, as in Agenda.
- **R41a ✅ More date display options** (User's Guide 6-19 to 6-22,
  7-14 to 7-15). The Display format box has all of Agenda's Display Format box,
  in its order: Display date and/or time (Date time, Date only, Time date,
  Time only; a date column with only a date shows the date, and with Time
  only nothing), Show day of week, Date format, Date separator, Clock,
  Show am/pm (Yes: "3:25pm", No: "3:25") and Time separator (":" or hm:
  "3h30m"). Date format adds Agenda's counts: <Day> # ("317"), Day #
  ("Day 317"), <Week> # ("46"), Week # ("Week 46"), Relative and Relative
  # ("1 day", "-2 days"). Relative shows Today, Tomorrow, Yesterday, and
  "nxt Sun" or "lst Fri" within six days, as Agenda 2.0 does (Lotus Q&A
  "Relative Date Format is Displayed for only Seven Days"); other dates
  are shown in the global format. Our choices: weeks are ISO 8601 weeks
  (the manual's sample says Week 45 for 13 Nov 1990, a US count; ISO says
  46); the title bar clock and alarms always show date and time, and
  relative formats are used only in date columns (elsewhere, ISO 8601 or
  the global format). View ▸ Column ▸ Properties on a date column opens
  the Date Column Properties box: Settings says Global defaults until a
  setting is changed, then Local settings, and the column keeps its own
  format while the file's changes; SPACE on Settings goes back to the
  global defaults. Relative dates are counted from today when the view
  is drawn.

## 5. User interface (Agenda 2.0 conventions)

Screen: Agenda's two-line control panel, the body, and a function-key bar.
The control panel shows the file with the indicators (marks, mode such as
READY / EDIT / MENU / CAT MGR) and the time on its first line, and what is
shown on its second: the view with its filter and hide settings, or
"Category Manager", "Note for: …", "Help". The menu (its
entries, then the highlighted entry's commands or description), a prompt
(its label, then the field), a message or a hint take it over while
they last; messages and hints keep the indicators beside them and go on into the second line when long, as Agenda's help
lines did. While a box is open, the control panel says what its
highlighted field does and which keys change it ("Choose to insert new
columns in one or all sections in the view."; screenshots 130 to 143);
a list box (Go to, Copy, Calendars…) has one such help for the whole box.
A message comes first. The texts follow Agenda's (its F1 help's tables
of settings), with Agendum's keys (`Agendum.TUI.Boxes.FieldHelp`). In the menu,
ESC backs up one level; a box, prompt or question opened from the menu
goes back to the menu level it was chosen from on ESC, and ESC again backs
up until the view, as in Agenda (User's Guide 2-13: "back up one step at a
time"); finished any other way (ENTER), it goes back to the view.
The view manager is a box over the view, as Agenda's (screenshot 40):
the views' names in order, * before a datebook view, an arrow where the
list goes on; ENTER shows the highlighted view, ESC goes back to the one
shown, F4 (or DEL) discards one. Our choice: Agenda's view manager showed
no more, so each view's sections are no longer listed beside its name.
A Y/N question is a small box without a title, as Agenda's (screenshots
36, 141): the question, then its answer highlighted, Yes at first; SPACE
(or an arrow) switches it, ENTER accepts the answer shown, ESC cancels.
Our choice: Y and N answer at once (Agenda's first letter only picked
the answer).
A box's bottom edge says how to finish it, in Agenda's words
(screenshots 130, 138, 144): "Press ENTER when done, ESC to cancel" on a
settings box, "Press ENTER to accept, ESC to cancel" on a box to choose
from, "Press ESC when done" on a category list where ENTER switches
choices (filters, conditions, actions, Excludes). In every settings box
ENTER is done and ESC cancels, as in Agenda: its changes show at once,
and ESC puts the file and your preferences back as they were when the
box opened (one undo step, which undo reverses); a box opened from a box
cancels only its own changes, and work done in a full screen opened from
a box (a note, the macro edit screen) stays. ESC while typing in a field
only stops the typing (`Agendum.TUI.Boxes.BoxCancel`). In a box the arrows move
between settings as in Agenda (User's Guide 2-16, `Agendum.TUI.Boxes.BoxNav`):
→ or TAB right one setting, or on to the next when there is none to the
right; ← or SHIFT-TAB left, or back to the previous; ↓ ↑ to the next or
previous row, onto the setting nearest the same place (from a right-hand
setting to the right-hand one below, or the left one when the row has
only that); HOME / END the first / last. On a text or date being typed
(Search, a range filter, an action's value), ← → HOME END move in the
text instead. A setting is changed with SPACE (the next choice), edited
with F2, picked from with F3; a number (a width, decimal places, a line
number) is typed, and so are Morning, Afternoon and Evening (SPACE asks).
On a setting with a list of choices, as in Agenda, a letter picks the
next choice starting with it ("r": Relative; one undo step), and F3
(CHOICES) lists them in a box, the current one first. The choices are
what SPACE goes through (`Agendum.TUI.Boxes.BoxChoices`); on a setting that is
typed, letters are typed as before. In Category Properties, as Agenda
(screenshot 74), Note, Statistics and Advanced settings show "..." and
SPACE opens each one's box; Statistics (Agenda's Category Statistics)
counts the items in the category, its children, the sections it heads,
and the view filters, conditions and actions that name it. File
Properties has File statistics ..., Agenda's File Statistics box
(screenshot 140): the items, the items with notes, the categories (MAIN
too), and the average items per category and categories per item, both
counting the assignments stored with the items, rounded down (as Agenda
2.0 counts them, checked on its PLANNER file); Agenda's Unused space and
Items in trash are left out. Our choices: the
function-key bar stays one line with the keys'
names and labels side by side (Agenda had two lines of ten fixed slots).
When the screen is wide enough for all of them, it shows fuller labels
("F8 View manager", "INS/CTRL-N Add a category"); otherwise Agenda's short
ones ("F8 VwMgr").

| Key         | View                                                                | Category manager        |
| ----------- | ------------------------------------------------------------------- | ----------------------- |
| F1          | Help                                                                |                         |
| F2          | Edit item / section head / column entry                             | Rename                  |
| F3 | Choices (category box for a column; assignment profile for an item) | |
| F4          | Done                                                                |                         |
| F5          | Note of the item, or of the category highlighted (R59)              | Note                    |
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
  ALT-F9 COPY (User's Guide 13-8 to 13-9): the Copy box lists the view's
  sections, the current one highlighted; ENTER puts the item (or, after
  asking, the marked items) in the chosen one as well, assigned to its
  head and keeping its other sections, one undo step. It is the same
  item, not a duplicate; a mutually exclusive section head takes it away
  from the old one (R15). Our choices: Agenda put the copy at the bottom
  of the section, but a file's items have one order, so it shows in its
  usual place; not in a datebook view, whose sections are dates.
  ALT-Y yank back (User's Guide 4-10): the item last taken out of a
  section with DEL goes into the current section, below the highlighted
  item (on a section head, in its usual place), assigned to the section's
  head, one undo step; it can go back where it was or anywhere else. One
  is remembered, and removing marked items does not count, as in Agenda;
  after a yank there is nothing left to yank. Not done: Agenda's ALT-Y
  also recovered the latest discarded item from the trash, which we do
  not have yet (CTRL-Z undoes a discard). Not in a datebook view.
  ALT-H hop (User's Guide 13-9): the highlighted item's next occurrence,
  in a later section of this view, else in the next view that shows it
  (the view manager's order, round to the first; the control panel names
  the view; ALT-F8 goes back); "No other occurrence" when it shows only
  once. Items in collapsed sections are not found.
  In a note (User's Guide 12-8 to 12-9): ALT-F7 MAKEITM asks Word, Line
  or All text and makes that text a new item in the section the
  highlight is in, below the note's item, taking it out of the note
  (line breaks become spaces; past 350 characters the rest is the new
  item's note); the shorter note and the item are one change. Only in a
  note opened from a view. ALT-F2 MAKECAT makes the word at the cursor
  (its punctuation off) a new category under a parent picked from the
  hierarchy; the note keeps it (past 69 characters the rest is the
  category's note). With text marked (R63), both take the marked text
  without asking.
  Later, with their features:
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
  item (or Item ▸ Properties) shows its text (F2 edits), note
  (SPACE or F2 opens it), statistics (number of categories, entry date) and
  every assignment in hierarchy order: dates in parentheses, conditional
  assignments marked "(c)". DEL breaks an assignment (the Entry date cannot
  be removed); F4 changes a date or number; ENTER closes the box (§5);
  typing assigns a category, with
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
  current view that holds it. ALT-F9 copies the marked items, or the
  current one, to another section (R42).

## 5a. Data interchange

- **R44 ✅ JSON export and import** (not in Agenda; ADR 0010). File ▸
  Transfer ▸ Export writes the whole file as readable JSON (the name
  offered is the file's, with `.json`); File ▸ Transfer ▸ Import reads one
  and opens it as a new, untitled file, to be saved under a name (the open
  file is replaced, as with Retrieve; nothing is merged). Like Retrieve
  and New, and as Quit already did, it first asks "Save changes first?
  (Y/N, ESC to cancel)" when the open file has unsaved changes: Y saves
  (asking for a name if it has none) and goes on, N goes on, ESC cancels. Everything in the
  file survives a round trip: categories and their properties, items with
  their assignments, dates, numbers, dependencies and suggestions, views,
  and the file's settings; the person's own settings (theme, languages,
  input format) are not in it. Import checks types and references and
  says what is wrong and where; a file that fails opens nothing. The
  schema is `docs/JSON_FORMAT.md`. Agenda's own transfer format (STF) is
  on the roadmap.
- **R45 ✅ Calendar subscriptions** (not in Agenda). File ▸ Transfer ▸
  Calendars lists the file's subscriptions to calendars on the web
  (iCalendar `.ics`, `https://` or `webcal://`). INS asks for the address
  and a name; the name is the category the events go in (made under MAIN,
  without name matching, unless one of that name exists), and the
  calendar is read at once. ENTER reads it now; F sets how often it is
  read while Agenda runs (every hour, the default; every 6 hours; every
  day; only on request), A how far ahead it imports (30, 90 by default,
  180 or 365 days); DEL unsubscribes, Y also discarding its items, N
  keeping them. Each calendar shows when it was last read, or why that
  failed. A read mirrors the calendar: an event from today up to the
  window ahead becomes an item in the category, its title the item text
  (read like typed text, so text matching files it too), its description
  the note, and its start the When date and time, set as by hand; its
  end (DTEND, or DURATION) goes in the date category Ends, made under MAIN
  the first time an event has one (a category of that name that is not a
  date category is left alone): a timed event's end date and time, an
  all-day event's last day when it lasts more than one, a repeating
  event's end keeping its length on the next date; a
  repeating event becomes one item on its next date, with Agenda's
  recurrence (R14a) when it repeats the same way (daily, weekly on one
  day, monthly on one day, yearly, every n of them), else only that next
  date; a series that has ended is not imported. A later read changes
  only what the calendar changed (the person's edits to text and note,
  their categories and done marks stay), and an event gone from the
  calendar or cancelled removes its item; an item the person discarded is
  not brought back, and past events keep their items. A read is one undo
  step; a scheduled read is quiet unless something changed. Reading
  happens in the background (the screen does not wait), with the
  system's certificates checked. Our choices: there is no time-zone
  database; a time in a named zone is converted by the calendar's own
  definition of that zone (VTIMEZONE: its offsets and yearly
  daylight-saving rules, as calendars from Google, Apple and Microsoft
  include them) to UTC, and UTC times to local time by the system's rules;
  a zone the calendar does not define is taken as local time. A repeating
  event keeps the local time of its first occurrence, so where the
  calendar's zone and yours change to summer time on different days, a
  few weeks of a year may be an hour off; alarms, attendees and
  exceptions to repeating events are not read. Subscriptions are saved
  in the file and in its JSON.
- **R46 ✅ Pop-up calendar** (User's Guide 6-14 to 6-17; Help "Use the
  Pop-Up Calendar"). F3 (CHOICES) on a column entry in a date column opens
  a month calendar on the entry's date, or on today when it has none;
  ALT-C opens it anywhere in a view, on today, for reference. ← → move a
  day, ↑ ↓ a week, HOME / END to the first / last day of the month, PGUP /
  PGDN the same day a month back / ahead, CTRL-← / CTRL-→ a year (Mac:
  `<` / `>`); a month or year move keeps the day where the month has it.
  Typing a date ("next friday", "2027-03-15") jumps there (Agenda shows
  what is typed at the top: here the control panel's prompt); F6 (SETTIME)
  asks for a time to go with the date (empty: none). ENTER sets the date,
  and the time, in the entry as if typed there (so When is set by hand,
  R14, date rules and conditions follow, one undo step); for reference it
  closes. ESC changes nothing. Dates run from 1 AD to 5000, as in Agenda.
  Our choices: the week starts on the file's Beginning of week (R14e;
  Agenda's screen started on Sunday), the calendar keeps the entry's time
  unless F6 changes it, and Agenda's Set Time box (SPACE between hours and
  minutes, GREY + / −) is a typed time.
- **R47 ✅ Datebook views** (User's Guide chapter 10, 10-1 to 10-14; Help
  "View Add box", "Browse Through Dates"). A datebook view is like a page
  of an appointment book: its sections are time slots, all headed by one
  category. Settings: Date category (When by default) places items by
  their date; End category (optional, a date category) shows an item in
  every slot up to its end ("Status meeting" 14:00 to 17:00 shows at 14,
  15 and 16); Section, the head of every section (the date category by
  default; Meetings shows only meetings); Period, Day, Week (default),
  Month or Quarter; Interval, what a slot covers: 15 min, 30 min or Hourly
  (default) for a day, Daily or Weekly (default) for a month, Daily,
  Weekly (default) or Monthly for a quarter, a week having a slot per day;
  Start at / End at, the hours of a day (default the file's Morning and
  Evening, 8:00 and 17:00) or the days of a week (default the file's
  beginning and end of week, Mon and Fri); Base date on, a relative or
  absolute date ("today", "tomorrow", "next week", "2026-11-05") read each
  time the view is shown, the period being the one it falls in (a month's
  and quarter's weeks run from the file's beginning to end of week and may
  reach into the next month; quarters start in the file's first quarter
  month). An item shows in a slot when its date (and time) in the date
  category falls in it; an item typed into a slot is filed under the
  Section category and dated at the slot's start, with its time in a day
  view, as if typed in the date column (so "Status meeting" typed under
  16:00 today is When today 16:00). Restrictions as in Agenda: a datebook
  view cannot become a standard view, its sections cannot be added,
  removed or filtered one by one (view filters apply to all). Deleting a
  category it uses falls back to When. Our choice: in a day view, items
  with that date but no time are in a first slot named after the day,
  above the hours; items timed outside Start at to End at are not shown.
  In the TUI: View ▸ Add (or INS in the view manager) asks for the name,
  then the Type, Standard or Datebook; a datebook view starts with
  Agenda's defaults and opens its Datebook settings box, which View ▸
  Properties shows again (SPACE picks a category or types a time or base
  date, SPACE/→ ← cycle Period, Interval and a week's days, DEL clears the
  End category; a time without am/pm is read as everywhere, R14b). Each
  slot's head is a line across with its name, in the file's date format
  ("── Mon 2026-10-12 ──", "10:00", "Mon 2026-09-28 → Fri 2026-10-02",
  "October 2026"), without a blank line above; the control panel says
  "Datebook for: When" (the Section) at the top right, and the view
  manager marks datebook views with *. Typing into a slot dates the item;
  ALT-D/U, DEL or F3 on a slot, collapsing, section filter and sort, and
  ALT-F10 say why not. Browsing (View ▸ Browse or ALT-B, BROWSE at the
  top right): ← → (or < >) show the previous / next period, ALT-F5 asks
  for a date and shows its period, ENTER keeps the period shown (the base
  date becomes its date, one undo step; a view based on "today" then stays
  there until Base date on is set again, as in Agenda) and ESC goes back;
  while browsing nothing else can be done. Standard views with date
  filters are browsed too (R48), and Show Schedule shows one date (R49).
- **R48 ✅ Browsing date filters** (Help "Browse Through Dates"). In a
  standard view, View ▸ Browse or ALT-B moves the date filter of the
  highlighted section, when it has one, else the view's: ← / → a day,
  CTRL-← / CTRL-→ (or ↑ / ↓) a week, PGUP / PGDN a month, CTRL-PGUP /
  CTRL-PGDN (⌥↑ / ⌥↓ on a Mac) a year; ALT-F5 moves the range to start on
  a typed date. Each end of a date range is read against today, moved,
  and shown as a fixed date (the view's line shows them; open ends stay
  open; numeric ranges and category criteria do not move); items come and
  go as the dates move. ENTER keeps the moved dates in the filter, one
  undo step ("today".."end of this week" becomes, a week on,
  "2026-10-19".."2026-10-23": fixed, no longer following today, as in
  Agenda); ESC puts the filter back. Without a date filter, ALT-B says so.
  BROWSE shows at the top right, and nothing else can be done meanwhile.
- **R49 ✅ Show Schedule** (User's Guide 10-14 to 10-16; Help "Show
  Schedule Box"; Agenda's Utilities Show Sched). Search ▸ Schedule opens
  the Show Schedule box: Date category (When by default; must be a date
  category), Section head (the date category by default), Date (today;
  typed, or F3 for the pop-up calendar, R46) and Filter (categories whose
  items to show, + assigned or − not assigned, as in a view filter). SPACE
  changes the highlighted setting, ENTER shows the items of that date in
  the Show View under the section head, ESC cancels. The date is a date
  filter on the Show View ("[When 2026-12-14..2026-12-14]"), so ALT-B
  browses it to other days (R48). The Show View starts afresh each time it
  is used, by a schedule, a search (R37) or a dependency list (R43): its
  section and filter are those of the last use.
- **R50 ✅ Learn-mode macros** (Working with Macros, chapter 1). A file
  keeps macros (Agenda allowed 100): each has a name of up to 35
  characters, unique case aside, its keystrokes, the key it is attached to
  (a key belongs to one macro at a time) and where it can be run from:
  views, notes and the category manager (Yes by default) and, for an
  attached key, everywhere else (No). They are listed in the macro
  manager's order, which can be changed or sorted by name. Keystrokes are
  kept as text in Agenda's notation (1-12 to 1-14): text as typed, other
  keys as names in braces, read in any case: `{ENTER}`, `{TAB}`,
  `{ShfTAB}`, `{BS}`, `{DEL}`, `{INS}`, `{ESC}`, `{UP}` `{DOWN}` `{LEFT}`
  `{RIGHT}`, `{HOME}` `{END}`, `{PGUP}` `{PGDN}`, `{CtlLeft}` and the
  other CTRL arrows, `{F1}`..`{F12}`, `{AltF1}`.., `{ShfF1}`.., `{AltD}`
  (ALT and a letter), `{CtlN}` (CTRL and a letter). As in Agenda, a
  misspelt name is typed as written, line breaks are not keys and the
  spaces that start a continuation line are left out (a line's end keeps
  them). Ours: `{LBRACE}` and `{RBRACE}` type braces; keys Agenda had no
  name for get one in its style (`{AltBS}`, `{AltShfD}`). Saved in the
  file (format 24) and its JSON. ALT-F3 (MACRO) opens the macro manager:
  INS (or CTRL-N, or typing) names a new macro; F7 (LEARN) closes the
  manager and records: LEARN shows at the top right, every key does its
  usual work and is recorded, in views, notes, the category manager and
  boxes alike (keys, not their meanings: F7 recorded in the category
  manager marks when played in a view); ALT-F3 (or ALT-Z) stops ("Learn
  mode is off: Weed has 19 new keys"). F7 on a macro with keystrokes asks
  whether to replace or append them. ENTER on a macro runs it where you
  were; ALT-Z runs the macro run last again. A run plays the keys one by
  one as if typed, saving, opening files or asking questions on the way
  (the shell runs each key's effects before the next), and is one undo
  step; a run that changed nothing is none. Our choices: ALT-F3 and ALT-Z
  do nothing over a line being typed, a prompt, a question or the menu (in
  Learn mode they still stop); within a run ALT-Z does nothing (Agenda
  could not record it); runs started from runs stop 8 deep ("Macros
  started 8 deep; stopped"); no beep on each recorded key. In the manager
  F2 opens the macro edit screen, the note editor with the keystrokes as
  text (a line after each {ENTER}; saved on leaving), F6 the Macro
  Properties box: Name (F2 or SPACE renames), Keystrokes (edits them), Attach to
  key (SPACE asks for one key in the notation, `{F4}`, `{ShfF4}`,
  `{CtlE}`; DEL detaches; ALT-F1, ALT-F3 and ALT-Z cannot be attached) and
  Run from View, Note, Category manager and, for an attached key only,
  Everywhere else (SPACE switches Yes / No). An attached key runs its
  macro where the macro may run, instead of its own command; a function key
  attached to a macro shows the macro's name in the key bar. Within a run
  an attached key does its own work, as in Agenda; `{CALL Name}` runs
  another macro (Agenda's {CALL}), and Learn mode records a key attached
  to a macro as such a call, not the keys that macro plays. DEL deletes a
  macro after asking, ALT-F5 sorts the list by name. Ours: ALT-↑ / ALT-↓
  move a macro in the list, as in the view manager (Agenda: ALT-F10 then
  ENTER). Not done: the macro command language (Working with Macros,
  chapters 2–3), external macro files, protection and hidden macros.
- **R51 ✅ Select File box** (User's Guide 22-4 to 22-5; Help "Select a
  File"). A prompt for a file name (File ▸ Retrieve or CTRL-O, File ▸ New,
  saving under a name, File ▸ Transfer ▸ Import and Export, printing to a
  file) says "F3 lists files"; F3 shows the Select File box for the folder
  of what is typed (or of the open file): `../` to go up, the subfolders
  (ending in `/`, Agenda's `<DIR>`) and the files the prompt can use
  (`.agendum` and `.agenda`, `.json`, or `.txt`), hidden ones left out.
  ↑ ↓ PGUP PGDN HOME END move; typing narrows the list to names that
  contain what is typed; ENTER opens a folder, or puts the file's whole
  path in the prompt, where ENTER then uses it as if typed; F7 shows when
  each was last changed (Agenda's DATES); ESC goes back to the prompt as
  it was. Ours: file names keep their extensions (Agenda left them out);
  Agenda's F4 (delete), F6 (EXPAND), F8 (descriptions), F9 (rename) and
  INS are not offered.
- **R52 ✅ Startup** (screenshot `docs/reference/screens/image0001-raw.png`).
  Agendum starts with a splash screen laid out as Agenda's: a box over an
  empty screen with the WOL block, the title "W O L ' S   A G E N D U M",
  the tagline "Hoo's in control? You are.", the release, "Copyright JW&D +
  WOL. All rites reserved.", Name and Company, and a word on sharing. Name
  is `name` in the preferences, else the login name; Company is `company`
  (shown only when set). Any key, which does nothing else, or three seconds
  take it away. When no file was named (and not `--demo` or `--rabbit`), the prompt "File
  to open or create:" waits under it, offering the last file used (F3
  lists files, R51); a file that exists opens, one that does not starts a
  new file there, saved on the first save; ESC leaves an untitled file.
  The last file opened or saved is kept as `last_file` in the preferences.
  Ours: Agenda asked for the file in its File Retrieve box and kept
  Name/Company from installation.
- **R53 ✅ Typing in the view manager** (User's Guide 9-5; Starter
  Applications 1-10). Typing in the view manager highlights the next view,
  round the list, whose name starts with the letters typed (any case);
  more letters narrow it down, BACKSPACE takes one back, and "Find:"
  beside the title shows them. A letter that fits no view starts again
  from that letter, so typing the same letter again goes on to the next
  view with it; a letter no view starts with is ignored. Any other key
  forgets what was typed. ENTER shows the highlighted view.
- **R54 ✅ More preferences** (Setting Up Agenda 1-25 to 1-28; User's
  Guide 2-22 to 2-23). More of Agenda's Utilities Customize settings, in
  File ▸ Customize, kept in the person's preferences file like the rest
  (ADR 0008):
  - ✅ **Display key map** (Yes, the default, or No): whether the key bar
    shows at the bottom of the screen. ALT-K shows or hides it and, as
    the setting, is kept for next time (`key_map = no` in the file).
  - ✅ **Confirm mode** (Yes, the default, or No): with No, Agendum does
    what was asked without "are you sure?" questions: discarding items,
    categories and views, deleting macros, clearing dependencies, sorting
    a family, changing a category's type, making an item depend on
    others. Questions whose Y and N do different things are still asked:
    "Save changes first?" and, when unsubscribing, whether to discard the
    calendar's items too. Undo (R30) still reverses what was done.
  - ✅ **Auto-save interval** (User's Guide 22-8): a file with a name and
    unsaved changes is saved once no key has been pressed for that many
    minutes, with the usual "Saved" message. Off (the default) or 1 to 60
    minutes; File ▸ Customize steps through 1, 2, 5, 10, 15, 20, 30, 45
    and 60, and `auto_save = N` in the file takes any of them. An untitled
    file is never saved by itself. A save that fails is tried again an
    interval later.
  - ✅ **Decimal separator** ("." the default, or ",") and **Thousands
    separator** ("," the default, ".", or a space; Setting Up Agenda 1-25,
    1-28): how numbers are shown and read everywhere: column entries and
    calculations, typed numbers, range filters and conditions, actions,
    Item Properties, and category names read as numbers. The two are never
    the same: with a decimal comma the thousands separator is a dot unless
    a space is chosen. They belong to the person's input format, so they
    reach the core with the clock (`Agendum.Core.Context`), as dates do
    (`decimal_separator` and `thousands_separator = space` in the file).

## 6. Out of scope for now

The macro command language (Working with Macros, chapters 2–3; Learn-mode
keystroke macros are on the roadmap), printing to a printer and print
preview, TXT2STF definition files, networking/file reservations, application
protection, the Metro accessories.
