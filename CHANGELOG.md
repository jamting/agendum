# Changelog

What changed in each version of Wol's Agendum, for the person using it. Versions follow [semantic versioning](https://semver.org): before 1.0.0, the minor number (0.**3**.0) goes up with every major feature or change to the file format, the patch number (0.3.**1**) with fixes. Each version is tagged in git (`v0.2.0`). The roadmap's record of finished work ([`docs/ROADMAP_DONE.md`](docs/ROADMAP_DONE.md)) lists every finished item; git log has the detail.

## Unreleased

- A box's **category field** (a column's or a section's head, a new section) **completes as you type**, as in Agenda: AUTOC, `1 of 2 matching categories. Current choice: …`, and ENTER takes the match shown. F5 or INS take exactly what you typed; F2 edits the name as it is.
## 0.45.0 — 2026-10-25

Editing as in Lotus Agenda.

- A **category name**, a **column entry** or a **date** is typed on the control panel's **second line**, as in Agenda, under its words: `Category name:`, `Date:`, or automatic completion's `1 of 2 matching categories. Current choice: High`. The list, the cell or the box keeps showing what is there until you press ENTER; a new category is a blank row in the category manager.
- While a column entry offers names, **AUTOC** shows and the key bar is Agenda's: **F3 Choices** (the column's list), **F5 NewCat**, **F7 PrevSel**, **F8 NextSel**. ALT-N, ALT-P and INS still work.
- While you **type an item**, the top line stays the **File line**, as in Agenda, with the date and **EDIT** where the time was (no more "Type the new item; ENTER to finish").
- While you **type a line** (an item, a category name, a column entry, a prompt, a box's field), the key bar shows Agenda's editing keys in their slots: **F7 Mark**, **F3 Copy**, **F4 Cut**, **F2 Paste**, and **ALT-F4** deletes the marked text. With nothing marked, F3 and F4 ask whether to take the word or all the text. What you copy in a note pastes into a line too.
- **F5** while typing an item keeps the text and opens the item's note; **F1** opens the help, and ESC comes back to the typing.

## 0.44.0 — 2026-10-25

The keys Lotus Agenda's box bars name, in every box.

- **F2 (EDIT)** in a settings box edits the highlighted setting's text, with the cursor after it: a name, a number, a category. On a "..." setting it opens it, as SPACE does; on a list of choices it does nothing, as in Agenda.
- **F6 (PROPS)** opens the Category Properties of the category in the highlighted field: a column's head, a schedule's date category, a sort key's category, a suggested category in Questions.
- **F8 (DEFAULT)** shows in every settings box, and says nothing on a setting without a default, as Agenda.
- In the **assignment profile** and the category lists, **F7 (INCLCAT)** switches the highlighted category as SPACE does and **F6** opens its properties (F6 no longer closes the profile). In a list of several categories (a filter, conditions, actions, excludes) **F4 (CLRCATS)** takes them all out.

## 0.43.0 — 2026-10-25

The key bar as in Lotus Agenda while a box or the menu is open.

- In a **box**, the key bar shows Agenda's **ten F-key slots**, as in a view (`Help │ Edit │ Choices │ … │ Props │ │ Default`), instead of a line of hints. The slots follow the highlighted field: **F4 Values** shows on Item Properties' Assigned to, and View Properties' Sections list has no **Default**.
- In the **menu**, a choice list, Go To and the statistics boxes the bar says **Help** alone, as Agenda's.
- A key that does nothing in a box yet leaves its slot empty: some of Agenda's F2 Edit, F6 Props and F8 Default are still to be built.
- While you type in a field, the bar keeps its hints for now (the Editing step).

## 0.42.0 — 2026-10-25

The control panel as in Lotus Agenda while a box is open, and the view's hide settings in Agenda's bracket.

- While a **box** is open (and in the view manager, the assignment profile and a question), the two top lines are the box's alone: the field's help, on two lines when long, with no file, time or view.
- While you **type in a box's field**, the top line is blank but for **EDIT** (or AUTOC) at the right; the help comes back when you finish.
- The view's **hide settings** follow its name in one bracket, as Agenda's: `View: Projects [Hide empty, done]`, right after a filter (`[-Contact List][Hide done]`). A datebook's **Datebook For:** starts at column 40, the bracket cut short before it with "..". **[No Auto Dates]** stays at the right.

## 0.41.1 — 2026-10-25

- The view manager's **►** (with Extras on) stands a column further left, apart from a datebook view's *.

## 0.41.0 — 2026-10-25

The control panel's symbols as in Lotus Agenda.

- The control panel marks a **date value with ☼** and a **number with #** at the right of the View line, beside ♪, as Agenda does (# was on the top line).
- **WRKG** shows at the top right while a calendar or feed is read in the background, Agenda's word for working in the background.
## 0.40.0 — 2026-10-25

Symbols as in Lotus Agenda: · before column entries, ‼ for done, and the category manager drawn as Agenda's.

- The **category manager** looks like Agenda's: just the names, indented by level, with **♪** (a note), **☼** (a date category) or **#** (a numeric one) before them, and **┌ ├ └** marking the children of an exclusive family. The counts, "aka" names, "date"/"exclusive" words and condition/action/Excludes tags are gone (Category Properties still shows them).
- A **done item** shows **‼**, Agenda's mark for done, where it showed √.
- A filled **column entry** has a small **·** before it, as in Lotus Agenda (the item is in that column's category); numbers have none.
## 0.39.0 — 2026-10-25

Views drawn as in Lotus Agenda: indented rows, ♪ and ♦ in their places, and » on the highlighted row.

- **» on the highlighted row**, as in Lotus Agenda: with the item text highlighted, » stands just before the first column, and the highlight is only as wide as the text; with a column entry highlighted, » takes the bullet's place.
- **Rows as in Lotus Agenda**: items are indented four spaces; an item with a note shows **♪** in the bullet's place, a marked item **♦** right after it, and the text starts in the seventh column (wrapped lines too). A section head whose category has a note shows **♪** in front of its name. Item text is three columns narrower.
## 0.38.0 — 2026-10-25

Mode words as in Lotus Agenda.

- **Mode words as in Lotus Agenda**: the top right shows no word when you are ready, and only Agenda's words otherwise (EDIT, AUTOC, BROWSE, LEARN; INS/OVR in a note). PROPS, MENU, CHOICES, CAT MGR and the other words of ours are gone; the category manager shows no time, as Agenda's.
## 0.37.0 — 2026-10-25

Choice lists as in Lotus Agenda; the texts now follow Agenda's.

- **F3 choice lists** are titled "Choices", with nothing in the bottom edge, as in Agenda.
- Column Add's **Category type** goes Standard → Numeric → Date, Agenda's order.
- Fixed: a column's Format offered Zettel id while Extras was off.
## 0.36.0 — 2026-10-25

Messages in Lotus Agenda's words.

- **Messages in Agenda's words**: where Lotus Agenda had a message for the same situation, Agendum now says what Agenda said, e.g. "The highlight isn't on an item.  Highlight the item you want and repeat the command." and "The date you entered isn't valid.  Type a valid date." About 60 messages; those for Agendum's own features stay as they were.
## 0.35.0 — 2026-10-25

The Questions box and datebook views' properties as in Lotus Agenda.

- A **datebook view's View Properties** is the whole box, as in Agenda: name, item sorting, the Hide settings, filter and statistics, with the datebook's own settings (Date category, End category, Section, Period, Interval, Start at, End at, Base date on) in the right column instead of Sections. The separate "Datebook settings" box is gone.
- **Utilities ▸ Questions** looks like Agenda's: "Suggested categories for" the item, each category as Parent:Child with **?** before it (**\*** once picked), "Press ENTER to accept". With none waiting, a box says so, and any key closes it.
## 0.34.0 — 2026-10-25

More boxes as in Lotus Agenda, and the splash screen tidied.

- **Item Column Properties** shows **Width**, the item text's width now, as Agenda's; typing a width sets it by hand (Set width becomes Manually).
- **Macro Properties** is laid out as Agenda's: **Contents** (SPACE opens the keystrokes) and, under **Macro can be run from:**, View, Note, Category manager and Everywhere else.
- **Display Format** (File Properties ▸ Global date settings) is drawn as Agenda's, like a date column's Column Properties: two columns, the sample centred, and no clock settings while dates show the date only.
- Four more box titles as Agenda's: **Display Format**, **Input Format**, **Macro Properties** and **Search**.
- The **splash screen**: the owl and "W O L" stand on the box itself, with no dark block around them.

## 0.33.0 — 2026-10-25

The sort box as in Lotus Agenda.

- The **sort box** (View or Section Properties ▸ Item sorting) is laid out as Lotus Agenda's: **Primary sort key** and **Secondary sort key**, each showing only the settings that apply (Order and Sort n/a's for Item text; Category, Sequence and Line number when they apply). The second key now has all the settings the first has.
- **SPACE on Sort on** goes None → Item text → Category → Category note and keeps the category; **Category** is a row of its own, where SPACE or F3 picks another.
- **Section sorting** is set in View Properties only (it was in the sort box too).
- A section's sort box says **(View default)** while it uses the view's sorting; any change makes it the section's own, and **ALT-F8** goes back (the "As the view" choice is gone).
## 0.32.0 — 2026-10-25

Settings boxes as in Lotus Agenda: their titles, words and a few habits, found by comparing every box with Agenda's own.

- **Box titles as in Lotus Agenda**: "File Properties", "Item Properties", "Category Properties", "Section Properties" (no name in the title), "Global Date Settings", "Auto-assign Global Settings", "Utilities Customize", "Execute", "Item Sorting in All Sections" / "in Current Section", and a category's "Advanced Settings for Calls;Phone;Telephon...".
- Settings in Agenda's words: **Ignore item text enclosed by**, **Set the item date from Done key** / **When key**, **Item statistics**, and Execute's **Apply conditions attached to category and children of**. These boxes write their labels as Agenda's, "Label:" with the values in a column.
- The **Category, File and View Statistics** boxes close with any key, as Agenda's ("Press any key to continue").
- A **date column's Column Properties** shows only the settings for what the column displays, as Agenda's: no clock settings for Date only, no date format for Time only. "(Global defaults)" or "(Local settings)" is a line under its title; the Settings row is gone, and **ALT-F8** goes back to the global defaults.

## 0.31.3 — 2026-10-25

- **Category Properties** of a date or numeric category shows only the settings it has, as in Lotus Agenda: name, type, note, special actions, assignment actions, statistics and advanced settings. Short name, Also match, Match category name, Exclusive children, Assignment conditions and Excludes are left out, as blank rows, and the cursor skips them. What a category had there before it changed type is kept, not shown.

## 0.31.2 — 2026-10-25

- Fixed: moving in a long view was sluggish, as in a News view with many feeds. A key there now takes about a third of the time it did.

## 0.31.1 — 2026-10-24

- **F8** and **ALT-F8** also work in the other settings boxes: Global Date Settings, Display Format, Auto-assign settings, a category's text matching and a date category's date settings, Datebook settings, Item Column Properties, Select Numeric Functions, Macro Properties and the input format. Each goes back to what something new gets: a new file's, a new datebook's, a new macro's, "Global" for a category's text matching.

## 0.31.0 — 2026-10-24

F8 (DEFAULT) and ALT-F8 (DFLTALL) in settings boxes, as in Lotus Agenda.

- **F8** puts the highlighted setting back to its default; **ALT-F8** puts back every setting of the box. The default is what something new gets: a new view's settings, a new category's, a fresh start's preferences; a date column goes back to the file's date format (File Properties).
- In View, Section, Category, Column and File Properties, Utilities ▸ Customize and the Sort box. A name, or a setting with no default, stays as it is ("This setting has no default").
- Like every change in a box, it applies on ENTER; ESC puts it all back.

## 0.30.0 — 2026-10-24

Category lists opened from a box, as in Lotus Agenda.

- In a **filter** list (View or Section Properties ▸ Filter), the **conditions**, **actions** and **Excludes** lists and the Schedule's filter, **SPACE** switches the highlighted category (once included, twice not included, then off). Before, ENTER did.
- **ENTER** (or ESC) closes the list and keeps what you switched; the bottom edge says "Press ENTER to accept".
- Typing a name still jumps to it; while you type, SPACE goes on typing the name ("Sample Person") and ENTER ends the typing, staying in the list.
- In the **Assignment Profile** (F3 on an item), SPACE assigns or unassigns, and ENTER now closes it.
- Fixed (from 0.29.0): a macro that closed an open settings box and then changed the file could not be undone.

## 0.29.0 — 2026-10-24

Settings boxes apply their changes on ENTER, as in Lotus Agenda.

- While a settings box is open (View Properties, Section Properties, Item or Category Properties, Customize …), the view **behind** it stays as it was; the box shows your new values. **ENTER** applies them, and the view changes then. ESC still puts everything back.
- After ENTER, **one CTRL-Z undoes the whole box**, not one setting at a time. A box closed with ESC leaves nothing to undo.
- An auto-save waits until the box is closed.

## 0.28.0 — 2026-10-24

The menus' names and order as in Lotus Agenda. Keys are unchanged; two letters typed in the menu change.

- **Item ▸ MakeAssign** (was Categorize): F10 `i` `m` (was `c`). The Item menu in Agenda's order: Properties, MakeAssign, Discard, BrkAssign, Reposition, Alarm.
- **View ▸ Section ▸ Add** replaces Below and Above (`a`; `b` is gone) and opens Agenda's **Section Add** box: the section head, **Insert** (Below current section, or Above: SPACE switches), and, once the head is typed or picked, the new section's sorting, filter and columns. ESC takes it all back. ALT-D and ALT-U still add below and above at once.
- The View menu in Agenda's order (Properties, Add, Browse, Discard, Column, Section), and File ▸ Transfer lists Import before Export.

## 0.27.0 — 2026-10-24

The F10 menu in Lotus Agenda's shape: `File  Item  Category  View  Print  Utilities  Quit`.

- **Utilities** is back, as in Agenda: Customize (was in File), Execute and Questions (were in Category), and **Show**: Match, Prereqs, Depends, Alarm and Sched (were the Search menu: File, Prereqs, Depends, Alarms, Schedule).
- **Undo** and **Redo** left the top line; CTRL-Z and CTRL-Y do them, as before.
- Entries for keys left the menus, their keys unchanged: Item ▸ Note (F5), When (ALT-F2), Show (F3), Finished (F4), Mark (F7), Unmark (ALT-F7); View ▸ Last (ALT-F8); Search ▸ View (ALT-F6).
- **A new file**: File ▸ Retrieve and a name that is not a file yet asks "Create the new file …?" and makes it. File ▸ New is gone.
- File ▸ Dating is gone: turn off dates read from text in the When category's properties (Date settings ▸ Assign item date ▸ Never). View ▸ Rename is gone: F2 in the view manager. Category ▸ Recalc is gone from the menu: CTRL-X, Recalc.

## 0.26.0 — 2026-10-24

Menu entries Lotus Agenda had for commands Agendum had only on keys, and the category manager's own menu.

- **F10 in the category manager** opens its menu, as in Agenda: Category ▸ Properties, Add, Discard (on the highlighted category), Return and Quit. Before, F10 went back to the view; F9 and ESC still do.
- In a view's menu: **Item ▸ BrkAssign** (as DEL on an item: the item leaves the section), **Category ▸ Properties** and **Category ▸ Discard** (the category of the section head you are on). Elsewhere they say, as Agenda does, "The highlight isn't on a category."

## 0.25.0 — 2026-10-24

What the function keys do with ALT, CTRL and SHIFT, on the key bar, as Lotus Agenda showed it while the key was held.

- **ALT-K** now shows, in turn: the **ALT keys** (`AltF2 When`, `AltF4 Discard`, `AltF10 Move` …), the **CTRL keys**, the **SHIFT keys**, then **hides** the bar, then the plain keys again. Before, ALT-K only showed or hid it.
- The CTRL and SHIFT keys are where macros are attached: a macro on SHIFT-F10 shows there by its name.
- Hiding the bar now takes four presses of ALT-K (or File ▸ Customize ▸ Display key map). Hidden or shown is kept for next time, as before; Agendum always starts on the plain keys.

## 0.24.2 — 2026-10-24

- The key bar is now made from the keys themselves, so it always says what a key does. You'll notice it in two places: in the category manager **F10** reads `To View` (it goes back to the view, as F9 does), and with the extras on, a very wide screen (about 170 columns) shows the commands' full names, `Category manager` included.
- **ALT-F3** (the macro manager) is now listed in F1's help with the keys that work everywhere, and can be run from there.

## 0.24.1 — 2026-10-24

- **CTRL-F1 to CTRL-F10** are keys of their own, as in Lotus Agenda: a macro can be attached to one (`{CtlF4}`). Before, CTRL-F4 acted as plain F4 and marked the item done. With nothing attached, they do nothing.

## 0.24.0 — 2026-10-24

The key bar is Lotus Agenda's: two lines, ten fixed slots.

- In a **view**, a **note** and the **category and view managers**, the bar at the foot of the screen now has a slot for each function key, F1 to F10, the key above its label, as in Agenda. **F10 Menu** is always there, even at 80 columns (before, it did not fit).
- A key that does nothing in a place leaves its slot empty, so every key stays in the same place.
- Agenda's labels: `Vw Mgr`, `Cat Mgr`. With the extras on and a wide screen, fuller ones (`View manager`).
- The bar takes two lines, so a view shows one row fewer. ALT-K still hides it.
- Boxes, the menu and moves keep their one-line hints for now, on the bottom line.

## 0.23.1 — 2026-10-24

A safety net: a mistake inside Agendum can no longer crash it and lose unsaved work in that particular way.

- Nothing you see changes. When a key asks for something Agendum does not know how to do (as ALT-N on the last note once did, 2026-10-17), the key now does nothing and the debug log (`AGENDUM_LOG`) says `unknown effect skipped`, instead of the program stopping.

## 0.23.0 — 2026-10-23

Editing a recurring date keeps it recurring, as in Lotus Agenda.

- **ALT-F2** and **F2 in the When column** on a recurring item now offer its rule with its first date, e.g. `every Monday (starting 2026-10-19)`, and `at 9:00am` after it when it has a time. Before, they offered the date alone, and ENTER turned the item into a plain date.
- Press ENTER to keep it as it is, or change the words: `every Wednesday (starting 2026-11-04)` changes both the rule and the first date. A first date that is not on the rule's day moves on to the next one.
- In Swedish: `varje måndag (från 2026-10-19) kl 09:00`.
- Agenda's own wording, `every Mon (strtng 10/19/2026)`, is read too.

## 0.22.0 — 2026-10-23

Recurring items show on every date they recur, as in Lotus Agenda.

- In a **datebook**, "Swim every day" now shows on each day of the week from its first date on, and "Stand-up every Monday at 9am" in the 9:00 slot of every Monday, not only on the first one. A week or month slot shows it once.
- A view **filtered on a date range** (View Properties ▸ Filter ▸ When) lists the recurring items that fall in it on any of their dates, and their **When column shows that date** (the first one in the range). Without a filter, the When column shows the first date, as before.
- It is still one item: F4 on any of its rows marks it done and adds the next one, as before; discarding it removes it from every date.
- Editing the date of a recurring item still offers the date alone (accepting it ends the repeating); showing the rule there, as Agenda does, is the next change.

## 0.21.0 — 2026-10-23

The menus lose the shortcut entries that Lotus Agenda's menus never had. Everything they did is still there, where Agenda put it:

- **View ▸ Filter**, **View ▸ Order** and **View ▸ Hide** (Done, Empty, Inherited, Pending, Column heads): in **View ▸ Properties** (Filter, Item sorting and the Hide rows).
- **View ▸ Section ▸ Filter** and **Sort**: in **View ▸ Section ▸ Properties** (F6 on a section head). **Section ▸ Lines** is View Properties ▸ Section separators, and **Section ▸ Collapse** is ALT-− / ALT-=.
- **View ▸ Manager** and **Category ▸ Manager**: F8 and F9, as before.
- The Planner's "Hide/Display done items" macro now goes through View Properties.

## 0.20.1 — 2026-10-23

- On a narrow screen (80 columns) the key bar no longer cuts a label mid-word ("ENTER Do"). Keys that do not fit are left out whole. In a box ENTER and ESC go first, since the box's bottom edge already says "Press ENTER when done, ESC to cancel".

## 0.20.0 — 2026-10-23

Number items, the last row of Agenda's View Properties box.

- **View Properties ▸ Number items** (on the row of Filter): Yes numbers the items in every section, 1, 2, 3 …, as Agenda does. Each section starts again at 1, and only the items shown are counted, so a hidden done item leaves no gap. The number comes before the item's text, and the text moves four columns to the right.
- A datebook view has the same setting in its settings box.
- File ▸ Print puts the numbers before the items too.
- Number items in a Lotus Agenda `.AG` file is now brought over when you import it.
- The file format changes (version 39): files saved by this version do not open in older ones.

## 0.19.0 — 2026-10-23

View Properties, as in Lotus Agenda: a view's settings in one box.

- **View ▸ Properties** on a standard view opens the View Properties box, laid out as Agenda's: View name, Item sorting, Section sorting and its Order, Hide empty sections, Hide done items, Hide dependent items, Hide inherited items, Hide column heads, Section separators and View statistics on the left; the view's **Sections** and its **Filter** on the right. A datebook view's View ▸ Properties still opens its datebook settings.
- **F6 in the view manager** (F8) opens the highlighted view's properties. ENTER takes you back to the view manager, in the view you were in.
- In Sections, ↓ and ↑ walk the sections. Type a name (or press INS) to add a section below the highlighted one, or F3 to pick its category; DEL removes a section, F6 shows its Section Properties. **ALT-F10** picks a section up: ↑ ↓ carry it, ENTER puts it down. ALT-↑ and ALT-↓ move it a place at once.
- SPACE on View statistics shows a small box, as Agenda's: the marked items, sections and items in the view; any key closes it. HOME and END go to View name and View statistics.
- Every change shows at once and is one undo step; ESC puts back everything changed in the box.
- View ▸ Hide, Filter, Order and Section ▸ Lines are still in the menus for now.

## 0.18.0 — 2026-10-23

The Extras switch: Agendum behaves like Lotus Agenda unless you ask for more.

- A new row in File ▸ Customize, **Extras**, is off at first. While it is off, Agendum's own additions are hidden: the blog (Publish), the feeds, the calendar subscriptions, the Zettel ids and links, CTRL-V to open a link, the view manager's ► and F5, and the longer key bar labels on a wide screen. Their keys do nothing, and the menus, F1 and CTRL-X leave them out.
- While it is off, feeds and calendars are not read in the background.
- While it is off, alarms that came due while the file was closed ring when it opens, as in Agenda, without the "While you were away" box.
- Your data stay as they are: Zettel ids, feed entries, the News view and the blog's settings are kept and shown. **To keep using the blog, the feeds and Zettel ids, turn Extras on once** (File ▸ Customize ▸ Extras, SPACE). It is kept in your preferences (`extras = yes`).

## 0.17.0 — 2026-10-23

The extras on a shelf of their own, inside the program. Nothing changes on the screen.

- The micro-blog, the feeds, the Zettel ids and links, and the calendar subscriptions now live apart from Agenda's own features in the code (ADR 0044), ready for the Extras switch that will hide them.
- The file format is now version 38. Every file you have still opens. A file saved by this version does not open in 0.16.2 or older: they refuse it rather than misread it.

## 0.16.2 — 2026-10-23

A fix in the feed reader.

- F3 now lists files at the OPML prompts of File ▸ Transfer ▸ Feeds (I imports a feed list, E exports one), as at every other prompt for a file: the folder's `.opml` and `.xml` files.

## 0.16.1 — 2026-10-22

A fix in the note editor.

- In a note longer than the screen, ↑ moves the cursor up the screen; the note scrolls only when the cursor reaches the top row (before, the cursor stayed on the bottom row and the note scrolled under it).

## 0.16.0 — 2026-10-17

Agenda's sounds.

- Agendum beeps as Agenda did, with Agenda's own tones: a high beep when the category you are typing comes down to one match, a low one when nothing matches (a new category), a beep with every error message, a click for each key recorded in Learn mode, and Agenda's two-pitch tune when an alarm rings. They play through your computer's speaker (`afplay` on a Mac, `paplay` or `aplay` on Linux); without one, or over ssh, the terminal's bell rings instead.
- File ▸ Customize has Sound (No: no sounds at all) and Agenda's Beep on auto-completion.

## 0.15.0 — 2026-10-17

The note editor, as Agenda's (steps 1 to 5 of its plan).

- The note editor's top line is Agenda's: "Note for:   …" (in the macro editor "Edit macro:  …") with the line you are on, INS and EDIT on the right. Messages show over it until the next key. The key bar follows Agenda's order, with F5 Return.
- F10 in a note opens the note's own menu, as in Agenda: Import puts a text file in at the cursor, Export writes the note to a text file (F3 lists the folder's text files), Clear empties the note (it asks first, and one undo brings the text back), Return goes back, Quit leaves Agendum.
- ESC in a note now asks "Discard changes?" when you changed it, as Agenda did: No (shown first, ENTER) saves as before, Yes puts the note back as it was when you opened it. F5 saves and goes back without asking, and so do ALT-N and ALT-P.
- Editing keys in a note, as Agenda's: CTRL-← / CTRL-→ (⌥← ⌥→) move by a word, ⌥⌫ or CTRL-W and ALT-W delete the word before or after the cursor, CTRL-K deletes to the end of the line, ALT-M starts a new line, PGUP / PGDN move a page, CTRL-HOME / CTRL-END (⌥< ⌥>) go to the start and end of the note.
- INS (or CTRL-N) switches a note between inserting and typing over (OVR in the header). TAB types spaces to the next tab stop; File ▸ Properties ▸ Tab size sets how far apart they are (5, as Agenda).
- In a note, ALT-F9 moves the word, line or marked text onto the end of the item's text (or the category's name), ALT-F8 copies the marked items (with their notes) into the note, and ALT-C types a date chosen in the calendar.
- Files are saved in a new format (37), for the Tab size; older files open as before.
- Fixed: deleting a macro from a macro manager opened over its own Properties box no longer crashes.
- Fixed: ALT-N or ALT-P on the last note, and a note search that finds nothing more, beep and say so instead of crashing.

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
