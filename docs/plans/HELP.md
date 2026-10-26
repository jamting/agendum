# Agenda's help, in our own words

**Status:** steps 1 and 2 done (v0.56.0); step 3 under way: batch 1, items and categories, with Agenda's keyword index (v0.57.0), and batch 2, views, sections and columns (v0.58.0), 2026-10-26; next batch: dates and alarms. The last required step of the truthful clone (`AGENDA_PARITY.md`, The steps).

Lotus Agenda's F1 help: a topic for where you are, bold links between topics, an index, a search, key charts and a way back (`docs/reference/Agenda 2.0 Help File.html`: 332 topics, about 61,000 words: 159 boxes, 132 how-to and concept topics, 28 menus, 13 key charts). Agendum's help keeps Agenda's keys and structure exactly and has texts of its own: terse, with a Hundred Acre Wood flavour in an opening line and the examples, quoting no Milne and using no Disney or Shepard pictures (meeting 2026-10-22, § 7a). How it is built: ADR 0047.

## What it covers (meeting 2026-10-26, § 5)

- **Generated topics**, made from what the program already knows, so they never fall out of date: one for every box (its fields and their help lines), every menu (its entries and their descriptions), every place (today's F1 texts) and the key charts (the keymaps).
- **Hand-written how-to and concept topics** for every task Agendum supports, Agenda's list below as the checklist; what Agendum does not have is left out, not written up.

## The keys (meeting 2026-10-26, § 6; the owner's choice: Agenda's exactly)

| Key | In help |
| --- | --- |
| F1 | How to Use Help |
| ↑ ↓ ← → HOME END | highlight a bold link; a letter highlights the next link starting with it |
| ENTER | open the highlighted link |
| PGUP PGDN | scroll the topic |
| F3 | Index: every topic |
| F5 | Find: type a word, a list of the topics with it; ALT-N / ALT-P step through them |
| F6 | Keys: the key charts. Its first links are **Commands you can run here** (today's F1 `c`, ENTER still runs one) and **Describe a key** (today's `d`); the charts are today's `a` |
| F8, BACKSPACE | Review: back through the topics seen |
| F9, ESC | leave help |

Habit changes (settled): any other key no longer leaves help; `c`, `d` and `a` are reached through F6; ↑ ↓ move between links.

## The steps (meeting 2026-10-26, § 8)

1. [x] (2026-10-26, v0.56.0; the owner tries it before the tag) **The frame**: the help screen with Agenda's keys and key bar, links, Index, Find, Review and F6 Keys; the generated topics; today's F1 texts as the place topics; the checks (every box, menu and place has a topic; every link leads to one; every key a topic names is bound there). The owner tries it, then it is tagged.
1b. [x] (2026-10-26, v0.56.0) **Find as Agenda's** (the owner's choice, 2026-10-26): F5 opens Agenda's **Find Topic** box ("Topic to find:"), and ENTER its **Select Help Screen** box, a list of the matching topics: the arrows and ENTER read one, ESC goes back to the topic being read; its help line "Highlight Help screen to display. Then use ALT-N or ALT-P to display next/previous help screen from list." (checked in Agenda 2.0, 2026-10-26).
2. [x] (2026-10-26; approved: "thats very good", a Wood touch only where natural) **Three sample topics** for the owner to approve the tone before the rest are written: Views, Undiscard an Item, Enter Items.
3. [ ] **The rest, in batches by subject**, each tagged (batch 1, items and categories, and Agenda's keyword index: v0.57.0; batch 2, views, sections and columns: v0.58.0; 2026-10-26): items and categories; views, sections and columns; dates and alarms; conditions and actions; files and the trash; notes; macros. **Agenda's kind of index** comes with them (the owner's choice, 2026-10-26): each written topic lists its index entries on an `INDEX` line (`INDEX  Add > Columns; Columns > Add`), generated topics get theirs from what they are (a box under its name and under Boxes), and the index pages show headings with sub-entries and "See also", as Agenda's ("Actions ▸ Attach to a category, Clear, Copy …"); until then F3 lists titles.
4. [ ] **Done** when the checklist below has nothing open: the help is done, and with it the clone (`AGENDA_PARITY.md`, Declared done).

## The checklist: Agenda's how-to and concept topics

Each is `open`, `ours` (with the topic's file), `covered by` another topic, or `left out` with the reason. Generated topics (boxes, menus, places, key charts) are not listed: the checks keep them complete.

| Agenda's topic | Ours |
| --- | --- |
| Agenda 2.0 Help File | the frame: the help's title |
| How to Use Help | ours: `lib/agendum/tui/help/topics/how-to-use-help.txt` |
| Find a Help Topic | the frame: F5 Find |
| Help Index | the frame: F3 Index |
| AgendaTown J The Cast J AgendaTown | open |
| Portrait/Landscape Font List | left out: printing (SPEC § 6) |
| Print Preview Mode | left out: printing (SPEC § 6) |
| Confirm Assignments | open |
| Go to a Section | ours: `go-to-a-section.txt` (batch 2) |
| Copy Conditions/Actions | open |
| Reposition a Category in the Hierarchy | ours: `reposition-a-category-in-the-hierarchy.txt` (batch 1) |
| Macro Manager | open |
| Record a Macro | open |
| Macro Manager Indicators | open |
| Macros | open |
| Variables in a Macro | open |
| About Macro Commands | open |
| Macro Command Syntax | open |
| Special Variables in Macros | open |
| Macro Editor | open |
| Attach an External Macro File | left out: external files (meeting 2026-10-25, § 5) |
| Note Editor | open |
| Edit Mode | open |
| Select from a Choice List | open |
| About Printing | left out: printing (SPEC § 6); Print a Document covers ours |
| Set Up Printers | left out: printing (SPEC § 6) |
| Lay Out a Printed Document | left out: printing (SPEC § 6) |
| Preview a Printed Document | left out: printing (SPEC § 6) |
| Print a Document | open |
| Use a Print Settings File | left out: printing (SPEC § 6) |
| Manipulate a Category List | open |
| About Agenda | open |
| Starter Applications | open |
| About Indicators | open |
| Mode & Message Indicators | open |
| View Indicators | open |
| Value Range Symbols | open |
| Category Manager Indicators | open |
| Quit Agenda | open |
| Suspend a Session | left out while Launch is optional (AGENDA_PARITY) |
| Access a Network | left out: networks (SPEC § 6) |
| Erase a File | open |
| File Size Limits | open |
| Import/Export Information | open |
| Copy the Structure of an Agenda File | open |
| Import/Export STF Files | open |
| Add a Column | ours: `add-a-column.txt` (batch 2) |
| Modify Column Properties | ours: `modify-column-properties.txt` (batch 2) |
| Adjust the Column Width | ours: `adjust-the-column-width.txt` (batch 2) |
| Remove a Column | ours: `remove-a-column.txt` (batch 2) |
| Create a File | open |
| Description and Password for a New File | open |
| Retrieve an Existing File | open |
| Save a File | open |
| Back Up a File | open |
| Abandon a File | open |
| Copy a File | open |
| Enter Items | ours: `enter-items.txt` (tone sample) |
| Edit Items and Categories | ours: `edit-items-and-categories.txt` (batch 1) |
| Discard an Item | ours: `discard-an-item.txt` (batch 1) |
| Undiscard an Item | ours: `undiscard-an-item.txt` (tone sample) |
| Break an Item's Assignment | ours: `break-an-items-assignment.txt` (batch 1) |
| Mark or Unmark Items | ours: `mark-or-unmark-items.txt` (batch 1) |
| Move Sections, Columns, or Items | ours: `move-sections-columns-or-items.txt` (batch 2) |
| Add a Section | ours: `add-a-section.txt` (batch 2) |
| Change Properties of a Section | ours: `change-properties-of-a-section.txt` (batch 2) |
| Add a View | ours: `add-a-view.txt` (batch 2) |
| Enter Categories | ours: `enter-categories.txt` (batch 1) |
| Create a Date Category | open |
| Edit Categories | covered by Edit Items and Categories |
| Select a Category | covered by Automatic Completion and Assign an Item to a Category |
| Discard a Category | ours: `discard-a-category.txt` (batch 1) |
| Assign an Item to a Category | ours: `assign-an-item-to-a-category.txt` (batch 1) |
| Enter a Note | open |
| Use a Category Note as a Column Head | ours: `use-a-category-note-as-a-column-head.txt` (batch 2) |
| Sort Sections in a View | ours: `sort-sections-in-a-view.txt` (batch 2) |
| Sort Items | ours: `sort-items.txt` (batch 2) |
| Attach a Filter | ours: `attach-a-filter.txt` (batch 2) |
| Attach a Numeric Filter | ours: `attach-a-numeric-filter.txt` (batch 2) |
| Attach a Date Filter | ours: `attach-a-date-filter.txt` (batch 2) |
| Change a Filter | ours: `change-a-filter.txt` (batch 2) |
| Clear a Filter, Condition, or Action | open |
| Remove a Section | ours: `remove-a-section.txt` (batch 2) |
| Use Child Categories as Section Heads | open |
| Columns | ours: `columns.txt` (batch 2) |
| Numeric Columns | ours: `numeric-columns.txt` (batch 2) |
| Date Columns | ours: `date-columns.txt` (batch 2) |
| Item Columns | ours: `item-columns.txt` (batch 2) |
| Files | open |
| Items | ours: `items.txt` (batch 1) |
| Sections | ours: `sections.txt` (batch 2) |
| Views | ours: `views.txt` (tone sample) |
| View Manager | ours: `view-manager.txt` (batch 2) |
| Categories | ours: `categories.txt` (batch 1) |
| Date Categories | open |
| Unindexed Categories | ours: `unindexed-categories.txt` (batch 2) |
| Notes | open |
| View Types | ours: `view-types.txt` (batch 2) |
| The Category Hierarchy | ours: `the-category-hierarchy.txt` (batch 1) |
| Sorting | ours: `sorting.txt` (batch 2) |
| Filters | ours: `filters.txt` (batch 2) |
| Automatic Completion | ours: `automatic-completion.txt` (batch 1) |
| Confirm Mode | open |
| Category Manager | ours: `category-manager.txt` (batch 1) |
| Conditions | open |
| Actions | open |
| Automatic Assignments | open |
| Explicit and Conditional Assignments | open |
| Use the Pop-Up Calendar | open |
| Numeric Categories | ours: `numeric-categories.txt` (batch 2) |
| Select a File | open |
| Create a Datebook View | open |
| Create a Show View | ours: `create-a-show-view.txt` (batch 2) |
| Show a Schedule for Any Day | open |
| Designate an Item as Done | ours: `designate-an-item-as-done.txt` (batch 1) |
| Assignment Profile for an Item | ours: `assignment-profile-for-an-item.txt` (batch 1) |
| Set an Alarm for an Item | open |
| Enter Dates and Times | open |
| Search for Text in Items and Notes | ours: `search-for-text-in-items-and-notes.txt` (batch 2) |
| Change Screen Colors | open |
| Attach an External File as a Note | left out: external note files (meeting 2026-10-25, § 5) |
| Change a Column Head | ours: `change-a-column-head.txt` (batch 2) |
| Alphabetize View Names | ours: `alphabetize-view-names.txt` (batch 2) |
| Attach an Assignment Condition to a Category | open |
| Attach an Assignment Action to a Category | open |
| Change the Value of a Condition or Action | open |
| Attach a Date Condition | open |
| Attach a Numeric Condition | open |
| Browse Through Dates | open |
| Alphabetize Categories | ours: `alphabetize-categories.txt` (batch 1) |
| Reposition Names in a List | open |
| Index | the frame: F3 Index |
