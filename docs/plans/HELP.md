# Agenda's help, in our own words

**Status:** planned (meeting 2026-10-26, §§ 5–8); the last required step of the truthful clone (`AGENDA_PARITY.md`, The steps). Nothing built yet.

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

1. [ ] **The frame**: the help screen with Agenda's keys and key bar, links, Index, Find, Review and F6 Keys; the generated topics; today's F1 texts as the place topics; the checks (every box, menu and place has a topic; every link leads to one; every key a topic names is bound there). The owner tries it, then it is tagged.
2. [ ] **Three sample topics** for the owner to approve the tone before the rest are written.
3. [ ] **The rest, in batches by subject**, each tagged: items and categories; views, sections and columns; dates and alarms; conditions and actions; files and the trash; notes; macros.
4. [ ] **Done** when the checklist below has nothing open: the help is done, and with it the clone (`AGENDA_PARITY.md`, Declared done).

## The checklist: Agenda's how-to and concept topics

Each is `open`, `ours` (with the topic's file), `covered by` another topic, or `left out` with the reason. Generated topics (boxes, menus, places, key charts) are not listed: the checks keep them complete.

| Agenda's topic | Ours |
| --- | --- |
| Agenda 2.0 Help File | the frame: the help's title |
| How to Use Help | the frame: F1 in help |
| Find a Help Topic | the frame: F5 Find |
| Help Index | the frame: F3 Index |
| AgendaTown J The Cast J AgendaTown | open |
| Portrait/Landscape Font List | left out: printing (SPEC § 6) |
| Print Preview Mode | left out: printing (SPEC § 6) |
| Confirm Assignments | open |
| Go to a Section | open |
| Copy Conditions/Actions | open |
| Reposition a Category in the Hierarchy | open |
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
| Add a Column | open |
| Modify Column Properties | open |
| Adjust the Column Width | open |
| Remove a Column | open |
| Create a File | open |
| Description and Password for a New File | open |
| Retrieve an Existing File | open |
| Save a File | open |
| Back Up a File | open |
| Abandon a File | open |
| Copy a File | open |
| Enter Items | open |
| Edit Items and Categories | open |
| Discard an Item | open |
| Undiscard an Item | open |
| Break an Item's Assignment | open |
| Mark or Unmark Items | open |
| Move Sections, Columns, or Items | open |
| Add a Section | open |
| Change Properties of a Section | open |
| Add a View | open |
| Enter Categories | open |
| Create a Date Category | open |
| Edit Categories | open |
| Select a Category | open |
| Discard a Category | open |
| Assign an Item to a Category | open |
| Enter a Note | open |
| Use a Category Note as a Column Head | open |
| Sort Sections in a View | open |
| Sort Items | open |
| Attach a Filter | open |
| Attach a Numeric Filter | open |
| Attach a Date Filter | open |
| Change a Filter | open |
| Clear a Filter, Condition, or Action | open |
| Remove a Section | open |
| Use Child Categories as Section Heads | open |
| Columns | open |
| Numeric Columns | open |
| Date Columns | open |
| Item Columns | open |
| Files | open |
| Items | open |
| Sections | open |
| Views | open |
| View Manager | open |
| Categories | open |
| Date Categories | open |
| Unindexed Categories | open |
| Notes | open |
| View Types | open |
| The Category Hierarchy | open |
| Sorting | open |
| Filters | open |
| Automatic Completion | open |
| Confirm Mode | open |
| Category Manager | open |
| Conditions | open |
| Actions | open |
| Automatic Assignments | open |
| Explicit and Conditional Assignments | open |
| Use the Pop-Up Calendar | open |
| Numeric Categories | open |
| Select a File | open |
| Create a Datebook View | open |
| Create a Show View | open |
| Show a Schedule for Any Day | open |
| Designate an Item as Done | open |
| Assignment Profile for an Item | open |
| Set an Alarm for an Item | open |
| Enter Dates and Times | open |
| Search for Text in Items and Notes | open |
| Change Screen Colors | open |
| Attach an External File as a Note | left out: external note files (meeting 2026-10-25, § 5) |
| Change a Column Head | open |
| Alphabetize View Names | open |
| Attach an Assignment Condition to a Category | open |
| Attach an Assignment Action to a Category | open |
| Change the Value of a Condition or Action | open |
| Attach a Date Condition | open |
| Attach a Numeric Condition | open |
| Browse Through Dates | open |
| Alphabetize Categories | open |
| Reposition Names in a List | open |
| Index | the frame: F3 Index |
