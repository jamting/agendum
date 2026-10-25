# Screens and boxes of the TUI

A map of every screen, box and control-panel mode, how to reach each one, and what it opens in turn. For keys in detail see `docs/KEYBOARD.md` and the F1 help; for the rules behind each box, the SPEC rule named in the tables.

## How screens stack

Everything the TUI shows on top of the current view is a **mode** on a stack, `state.modes` (`Agendum.TUI.State`): opening a box pushes one, ESC pops it and returns to what was underneath. `Agendum.TUI.Update.handle/2` sends each key to the mode on top; `Agendum.TUI.Render` draws the stack. Modes come in three kinds:

- **Full screens** replace the view: the category manager, the view manager and the note editor. Help is one too, but drawn as a box over most of the screen (more of a small one) over what it was opened from, which fades behind it.
- **Boxes** are drawn over the view (or over a full screen) in a frame with a title. A box opened from a box sits one line lower and two columns right.
- **Control-panel modes** use only the two lines at the top: the menu, prompts, Y/N questions, searching and moving items.

Each mode is a map with a `type` (the atom in the tables below) and its own fields (cursor, the category or item it is for, a purpose).

## The map

The view is home. The main paths from it:

```mermaid
flowchart LR
    View(["View (home)"])
    View -- "F10 or /" --> Menu["Menu"]
    View -- F1 --> Help["Help"]
    View -- F9 --> CatMgr["Category manager"]
    View -- F8 --> ViewMgr["View manager"]
    View -- F5 --> Note["Note editor"]
    View -- "F6 on an item" --> ItemProps["Item Properties"]
    View -- "F6 on a section head" --> SectProps["Section Properties"]
    View -- "F3 on an item" --> Profile["Assignment profile"]
    View -- "F3 in a column" --> Picker["Category picker"]
    View -- ALT-F5 --> GoTo["Go to section"]
    View -- ALT-F6 --> SearchBox["Search box"]
    View -- "ALT-F10" --> MoveItem["Moving items"]
    View -- "a key with items marked" --> Scope["Scope box"]
    Menu -- "File ▸ Properties" --> FileProps["File Properties"]
    Menu -- "Utilities ▸ Customize" --> Customize["Utilities Customize"]
    Menu -- "Utilities ▸ Execute" --> Execute["Execute box"]
    Menu -- "Utilities ▸ Questions" --> Questions["Questions box"]
    Menu -- "View ▸ Column ▸ Properties" --> ColProps["Column Properties"]
    Menu -- "View ▸ Column ▸ Add" --> ColAdd["Column Add"]
    Menu -- "View ▸ Column ▸ Properties on the item text" --> ItemCol["Item Column Properties"]
    Menu -- "View ▸ Properties" --> ViewProps["View Properties"]
    ViewProps -- "Item sorting" --> Sort["Sort box"]
    SectProps -- "Item sorting" --> Sort
    Menu -- "Utilities ▸ Show ▸ Alarm" --> Alarms["Alarm list"]
    CatMgr -- F6 --> CatProps
    ItemProps -- F3 --> Profile
    Note -- ALT-F6 --> NoteSearch["Note search"]
    SearchBox -- ENTER --> Searching["Searching"]
```

Category Properties and File Properties open boxes of their own:

```mermaid
flowchart LR
    CatProps["Category Properties"]
    CatProps -- "Type" --> TypeChoice["Choice: type"]
    CatProps -- "Exclusive children" --> ExclChoice["Choice: exclusive conflicts"]
    CatProps -- "Conditions" --> CondPicker["Picker: conditions"]
    CondPicker -- "a date or numeric category" --> RangeCond["Range filter (condition)"]
    CatProps -- "Also assign" --> AssignPicker["Picker: actions"]
    AssignPicker -- "a date or numeric category" --> Action["Action box"]
    CatProps -- "Excludes" --> ExclPicker["Picker: negative links"]
    CatProps -- "Advanced settings, date category" --> DateRule["Date settings"]
    CatProps -- "Advanced settings, standard category" --> CatMatch["Text matching"]
    CatProps -- "Note" --> Note["Note editor"]
    FileProps["File Properties"]
    FileProps -- "Global date settings" --> DateSettings["Global date settings"]
    DateSettings -- "Display format" --> DisplayFormat["Display Format"]
    DateSettings -- "Input format" --> InputFormat["Input Format"]
    FileProps -- "Auto-assign settings" --> AutoAssign["Auto-assign settings"]
    FileProps -- "File statistics" --> FileStats["File statistics"]
    Customize["Utilities Customize"] -- "Input format" --> InputFormat
    ColProps["Column Properties"]
    ColProps -- "F3 on Column head" --> ColHead["Picker: column head"]
    ColAdd["Column Add"] -- "F3 on Column head" --> ColHead
```

## Everything, by where it is reached

Indentation shows what opens what. `type` is the mode's type; the module draws or handles it.

- **View** (no mode): the current view's sections, items and columns. `Agendum.TUI.Update.ViewKeys`, `Agendum.TUI.Layout`, `Agendum.TUI.Render.View`.
  - **Menu** `:menu` (F10 or `/`): File, Item, Category, View, Search, Undo, Redo, Print, Quit. `Agendum.TUI.Menu`. Its commands open most of the boxes below; the menu path is given with each.
  - **Help** `:help` (F1, wherever the keys are not typing): a text about where you are, then `c` the command list (typing narrows it, ENTER runs the highlighted command), `d` describe key, `a` all the keys, made from the keymaps (`Agendum.TUI.Render.Help`) (R65). Drawn as a box over the faded screen (R65c). `Agendum.TUI.HelpScreen`.
  - **Prompt** `:prompt`: one line of text in the control panel (a file name, a new view's name, a category name). `Agendum.TUI.Update.Prompts`.
    - **Select File** `:select_file` (F3 in a prompt for a file name): the folder's subfolders and the files that fit, to pick one (R51). `Agendum.TUI.Boxes.SelectFile`.
  - **Question** `:confirm`: a Y/N question (discard, save changes, make a date category) in a small untitled box, as Agenda's (screenshots 36, 141): the question with its answer highlighted, Yes at first. `Agendum.TUI.Update.Prompts`.
    - **Picker** `:picker` for the Date category, End category and Section.
    - **Prompt** `:prompt` for a time (Start at / End at of a day) or the base date.
  - **View Properties** `:view_props` (View ▸ Properties of a standard view, F6 on a view in the view manager): the view's name, Item sorting, Section sorting and Order, the Hide settings, Section separators, Number items (R79), View statistics, and on the right its Sections (add, remove, move) and Filter, laid out as Agenda's (R78). `Agendum.TUI.Boxes.ViewProps`.
    - **Sort** `:sort` for Item sorting; **Picker** `:picker` for the filter or a new section's category (F3).
    - **Section Properties** `:section_props` for F6 on a section.
    - **View Statistics** `:view_stats` (View statistics ...): the marked items, sections and items in the view, as Agenda's; any key returns. `Agendum.TUI.Boxes.ViewStatsBox`.
  - **Section Properties** `:section_props` (View ▸ Section ▸ Properties, F6 on a section head): the section's head, Item sorting, Section statistics, Filter and its columns (R61). As **Section Add** (View ▸ Section ▸ Add, `adding` set): blank, with Insert, Below or Above the current section; the section is added once its head is chosen. `Agendum.TUI.Boxes.SectionBox`.
    - **Picker** `:picker` for the section head or the filter.
    - **Sort** `:sort` for Item sorting; **Column Add** `:column_add` for INS.
    - **Select Numeric Functions** `:numeric_functions`: Count, Total, Average, Minimum, Maximum for the section's numeric columns. `Agendum.TUI.Boxes.NumericFunctionsBox`.
  - **Choice** `:choice` (View ▸ Add, after the name): Standard or Datebook.
  - **Choice** `:choice` (View ▸ Column ▸ Remove on a column linked into other sections): All sections in view or Current section only (R55).
  - **Browsing** `:browse` (View ▸ Browse, ALT-B, in a datebook view or a view with a date filter): the view flips to other periods, or its date filter moves, until ENTER keeps it or ESC goes back (R47, R48). `Agendum.TUI.Moves.Browse`.
    - **Prompt** `:prompt` for a date to go to (ALT-F5).
  - **Column width** `:column_width` (View ▸ Column ▸ Width): the control panel shows the highlighted column's width; ← →, a typed number or SHIFT-? (fit, R22a) change it in the view until ENTER keeps it or ESC goes back; on the item text, the section's item column (R55). `Agendum.TUI.Moves.ColumnWidth`.
  - **Moving a column** `:column_move` (View ▸ Column ▸ Move, ALT-F10 on a column head): ← → move it in its section, shown at once, until ENTER keeps it or ESC puts it back (R55); on the item text, the item column. `Agendum.TUI.Moves.ColumnMove`.
  - **Moving a section** `:section_move` (View ▸ Section ▸ Move, ALT-F10 on a section head): the sections collapsed, ↑ ↓ move it, ENTER keeps it or ESC puts it back (R62). `Agendum.TUI.Moves.SectionMove`.
  - **Calendar** `:calendar` (F3 in a date column; ALT-C anywhere in a view): the pop-up calendar, to pick a date (and time) for the entry or to look one up (R46). `Agendum.TUI.Boxes.CalendarBox`.
    - **Prompt** `:prompt` for a time (F6) or a date to go to (typing).
  - **Scope** `:scope`: with items marked, whether a command (F3, F4, ALT-F2, ALT-F4, ALT-F9, ALT-F10, ALT-M, DEL) acts on the highlighted item or all marked ones (R35). `Agendum.TUI.Update.Marked`.
  - **Moving items** `:move_item` (ALT-F10, Item ▸ Reposition): the item follows the cursor until ENTER (R26). `Agendum.TUI.Update.Marked`.
  - **Copy** `:copy_items` (ALT-F9): the view's sections; ENTER puts the item(s) in the chosen one as well (R42). `Agendum.TUI.Boxes.CopyBox`.
  - **Note editor** `:note` (F5): a full screen for an item's note; also a category's note from Category Properties or the category manager. `Agendum.TUI.Typing.TextEdit`, `Agendum.TUI.Update.Notes`.
  - **What to copy** `:what_to_copy` (F3, F4 or ALT-F4 with nothing marked, in a note or a line being typed): Agenda's untitled one-field box, Word, Line or All text. `Agendum.TUI.Boxes.WhatToCopyBox`.
    - **Note search** `:note_search` (ALT-F6 in a note): search and replace, then Y/N per match (R39). `Agendum.TUI.Typing.NoteSearch`.
  - **Item Properties** `:item_props` (F6 on an item, Item ▸ Properties): text, note, statistics, dependencies, every assignment (R34, R43). `Agendum.TUI.Boxes.ItemProperties`.
  - **Set Alarm** `:set_alarm` (ALT-A, Item ▸ Alarm): Date category and Minutes before, as Agenda's; ENTER sets the alarm (R38). `Agendum.TUI.Boxes.SetAlarmBox`.
    - **Assignment profile** `:profile` (F3).
    - **Item Properties** of a dependency (ENTER on one), on top.
    - **Note editor** `:note` (ENTER on Note).
  - **Assignment profile** `:profile` (F3 on an item): every category with the item's assignments marked; SPACE assigns. `Agendum.TUI.CategoryScreens.Profile`.
  - **Group profile** `:group_profile` (F3 with items marked, "all marked"): the same for several items (R35). `Agendum.TUI.CategoryScreens.Profile`.
  - **Category picker** `:picker`: choose a category from the hierarchy, with search. `Agendum.TUI.CategoryScreens.Picker`. Its `purpose` says what the choice does:
    - a column entry (F3 in a column), assigning items (ALT-M, Item ▸ MakeAssign), a section's category (F3 on a head), a new section (ALT-D, ALT-U) or column (ALT-R, ALT-L), a new view's first section
    - filters (View Properties ▸ Filter, Section Properties ▸ Filter, R28); a date or numeric category opens the **Range filter** box `:range_filter` (`Agendum.TUI.Boxes.RangeFilterBox`, R28a)
    - sort keys from the Sort box, the Execute box's root, moving a category (ALT-F10 in the category manager), conditions, actions and negative links (from Category Properties)
  - **Category Properties** `:props` (F6 on a section head; F6 in the category manager), in Agenda's two columns (screenshot 74): name, parent (shown), short name, Also match, note, exclusive children and special actions on the left; type, name matching, conditions, actions and negative links on the right; advanced settings across the bottom; a date or numeric category shows only the name, type, note, special actions, actions, statistics and advanced settings, with blank rows for the rest (R6a). `Agendum.TUI.CategoryScreens.Properties`. Note, Statistics and Advanced settings show "..." and open boxes of their own with SPACE.
    - **Category statistics** `:category_stats` (Statistics ...): the items in the category, its children, the sections it heads, and the view filters, conditions and actions that name it; nothing to change.
    - **Choice** `:choice`: a list of choices with an explanation: the category's type (Standard, Numeric, Date; R6a), how to resolve items that break exclusive children (R7a) or a move (R7b). `Agendum.TUI.CategoryScreens.Choices`.
    - **Picker** `:picker` for Conditions, Also assign and Excludes (R15, R15b, R9).
      - **Range filter** `:range_filter` as a condition on a date or numeric category (R15a).
      - **Action box** `:action_box`: a date or numeric action (R15b). `Agendum.TUI.Boxes.ActionBox`.
    - **Date settings** `:date_rule` (Advanced settings of a date category, R6b). `Agendum.TUI.Boxes.DateRuleBox`.
    - **Text matching** `:category_match` (Advanced settings of a standard category, R16b). `Agendum.TUI.Boxes.CategoryMatchBox`.
    - **Note editor** `:note`.
  - **Category manager** `:catmgr` (F9): full screen of the hierarchy, drawn as Agenda's (2026-10-25): the names, two columns a level, a mark two left of the name (♪ a note, ☼ a date category, # a numeric one), ┌ ├ └ before the children of an exclusive family ([ for a lone child), no counts or tags, no time at the top; add, rename, promote, demote, move, sort, discard (R2–R8). `Agendum.TUI.CategoryScreens.Manager`.
    - **Category Properties** `:props` (F6), **Note editor** `:note` (F5), **Help** `:help` (F1), **Picker** `:picker` (ALT-F10, where to move), **Choice** `:choice` (conflicts of a move).
  - **View manager** `:viewmgr` (F8): a box over the view, as Agenda's (screenshot 40): the views' names, * before a datebook view, ► before the view shown (R68); switch, add, rename, reorder, discard (DEL or F4), list by recently used (F5), and F6 for the highlighted view's View Properties (R78). `Agendum.TUI.Boxes.ViewManager`.
  - **Go to** `:goto` (ALT-F5): jump to a section (R42). `Agendum.TUI.Boxes.GoTo`.
  - **Run a command** `:run_by_name` (CTRL-X, almost anywhere): the commands that can run there, found by name or initials, each with its key; ENTER runs the highlighted one where CTRL-X was pressed (R65d). `Agendum.TUI.Boxes.RunByName`.
  - **Choices** `:choice_list` (F3 on a setting in a box that has a list of choices): its choices, the current one first; ENTER takes the highlighted one (§5). `Agendum.TUI.Boxes.ChoiceListBox`.
  - **Search box** `:search_box` (ALT-F6, Utilities ▸ Show ▸ Match): what to find, in item text, note or both, the direction, ignoring case (R37). `Agendum.TUI.Boxes.SearchBox`.
    - **Searching** `:searching`: ALT-N / ALT-P step through matches, F7 marks. A file search shows the Show View instead.
  - **Sort box** `:sort` (Item sorting in View Properties or Section Properties): the sort keys of a view or a section (R36). `Agendum.TUI.Boxes.SortBox`.
    - **Picker** `:picker` for a key's category or note category.
  - **File Properties** `:file_props` (File ▸ Properties): Insert new columns in (R55), and two "..." rows opening Agenda's boxes, nested as in Agenda 2.0; drawn from a layout like Agenda's (screenshot 130). `Agendum.TUI.Boxes.FileProperties`.
    - **Global date settings** `:date_settings` (Global date settings): the week, quarter, year and times of day (R14e). `Agendum.TUI.Boxes.DateSettingsBox`.
      - **Display format** `:display_format` (Display format): how the file shows dates, with a sample (R41, R41a). `Agendum.TUI.Boxes.DisplayFormatBox`, rows from `Agendum.TUI.Boxes.DateFormatRows`.
      - **Input format** `:input_format` (Input format): the person's number order, date separator and clock, saved as preferences (R41b). `Agendum.TUI.Boxes.InputFormatBox`.
    - **Auto-assign settings** `:auto_assign` (Auto-assign settings): text matching for the file and Confirm assignments (R16, R16a). `Agendum.TUI.Boxes.AutoAssignBox`.
    - **File statistics** `:file_stats` (File statistics ...): the items, items with notes, categories and the average assignments, as Agenda's (screenshot 140); nothing to change. `Agendum.TUI.Boxes.FileStatsBox`.
  - **Feeds** `:feeds` (File ▸ Transfer ▸ Feeds): RSS and Atom feed subscriptions; INS subscribes (two prompts), ENTER reads now, F how often, K how long entries stay, DEL unsubscribes, I and E import and export OPML (prompts for the file) (R75). `Agendum.TUI.Extras.FeedsBox`.
  - **Calendars** `:calendars` (File ▸ Transfer ▸ Calendars): calendar subscriptions; INS subscribes (two prompts), ENTER reads now, F and A change how often and how far ahead, DEL unsubscribes (R45). `Agendum.TUI.Extras.CalendarsBox`.
  - **Customize** `:customize` (Utilities ▸ Customize): the person's theme, date language and fallback language, sounds and the Extras switch, saved as preferences (R40, R14c, R76, R77). `Agendum.TUI.Boxes.CustomizeBox`.
    - **Input format** `:input_format` (Input format).
  - **Column Properties** (View ▸ Column ▸ Properties, on a column entry): `:column_props`, one box for every column as in Agenda (screenshot 142): head, category type, width and Link with other sections (R55); a standard column's Format, with Line number and Column title for Category note (R56, screenshot 127); below them a numeric column's number format and calculations (R29) or a date column's own date format or the global defaults (R41a). `Agendum.TUI.Boxes.ColumnBox`.
    - **Picker** `:picker` for the column head (F3 on Column head).
  - **Item Column Properties** (View ▸ Column ▸ Properties on the item text): `:item_column`, the section head, Set width (Automatically or Manually), Width or Minimum width, Link with other sections (R55). `Agendum.TUI.Boxes.ItemColumnBox`.
    - **Picker** `:picker` for the section head (F3 on Section head).
  - **Column Add** (View ▸ Column ▸ Add): `:column_add`, a new column's head, its category type (a standard head can become date or numeric), width, a standard column's Format (R56), Position (right or left of the current column) and Insert in (all sections or this one, overriding the file's setting; R55). ENTER adds it. `Agendum.TUI.Boxes.ColumnAddBox`.
    - **Picker** `:picker` for the column head (F3 on Column head).
  - **Execute** `:execute` (Utilities ▸ Execute): apply conditions and actions to existing items, from a root category (R15e). `Agendum.TUI.Boxes.ExecuteBox`.
    - **Picker** `:picker` for the root.
  - **Questions** `:questions` (Utilities ▸ Questions): confirm suggested assignments, item by item (R16). `Agendum.TUI.Boxes.QuestionsBox`.
  - **Show Schedule** `:schedule` (Utilities ▸ Show ▸ Sched): one date's items in the Show View (R49). `Agendum.TUI.Boxes.ScheduleBox`.
    - **Picker** `:picker` for the date category, section head and filter.
    - **Prompt** `:prompt` for the date; **Calendar** `:calendar` (F3).
  - **Macros** `:macros` (ALT-F3, also from notes and the category manager): the macro manager; INS names a new macro, F7 learns its keystrokes, ENTER runs it (R50). `Agendum.TUI.Macros`.
    - **Prompt** `:prompt` for a new macro's name.
    - **Choice** `:choice` (F7 on a macro with keystrokes): replace or append.
    - **Note editor** `:note` (F2): the macro edit screen, its keystrokes as text.
    - **Macro Properties** `:macro_props` (F6): name, keystrokes, attached key, where it can run (R50). `Agendum.TUI.Boxes.MacroProps`.
      - **Prompt** `:prompt` for the name or the key.
  - **Alarm list** `:alarm_list` (Utilities ▸ Show ▸ Alarm): current and past alarms (R38). `Agendum.TUI.Boxes.AlarmList`.

- **While you were away** `:away` (by itself, after the splash screen or as a file is retrieved, only when alarms came due while the file was closed): those alarms, grouped by text (R70). `Agendum.TUI.Boxes.AwayBox`.

- **Imported from Agenda** `:ag_import` (by itself, after File ▸ Transfer ▸ Import or `agendum OLD.AG` imported a Lotus Agenda file): what came over, what was left out, and the items filed differently from Agenda; CTRL-P writes it to a text file (R72). `Agendum.TUI.Boxes.ImportReportBox`. Before it, for a file with a password, a **Prompt** `:prompt` whose text shows as stars.

- **Publish the blog** `:publish` (File ▸ Transfer ▸ Publish): the micro-blog's settings, its posts and drafts categories, title, address, folder and upload (R74). `Agendum.TUI.Extras.PublishBox`. ENTER reads the folder, then:
  - **Publish: what will change** `:publish_preview`: the files publishing adds, changes and removes, before anything is written; ENTER writes and uploads (R74). `Agendum.TUI.Extras.PublishPreviewBox`. An SFTP server that wants a password asks in a **Prompt** `:prompt` whose text shows as stars.

- **Developer tools** `:devtools` (ESC ?, hidden, from anywhere but while typing): a full screen of debugging facts and a key tester; see `docs/KEYBOARD.md`. `Agendum.TUI.DevTools`.

Commands that act at once and open nothing (F4 done, F7 mark, ALT-O dependencies after its question, Undo, Save) are not listed.

## By type

| `type`               | Kind          | Module                                   | Reached from                                      | SPEC           |
| -------------------- | ------------- | ---------------------------------------- | ------------------------------------------------- | -------------- |
| `:menu`              | control panel | `Agendum.TUI.Menu`                       | F10 or `/`                                        | §5             |
| `:prompt`            | control panel | `Agendum.TUI.Update.Prompts`             | commands that ask for a line of text              | §5             |
| `:confirm`           | box           | `Agendum.TUI.Update.Prompts`             | commands that ask Y/N                             | §5             |
| `:scope`             | box           | `Agendum.TUI.Update.Marked`              | a command with items marked                       | R35            |
| `:copy_items`        | box           | `Agendum.TUI.Boxes.CopyBox`              | ALT-F9 on an item                                 | R42            |
| `:move_item`         | control panel | `Agendum.TUI.Update.Marked`              | ALT-F10, Item ▸ Reposition                        | R26            |
| `:searching`         | control panel | `Agendum.TUI.Boxes.SearchBox`            | the Search box                                    | R37            |
| `:help`              | full screen   | `Agendum.TUI.HelpScreen`                 | F1 (then `c` commands, `d` describe, `a` all keys) | §5, R65, R65c  |
| `:note`              | full screen   | `Agendum.TUI.Update.Notes`               | F5, Item Properties, Category Properties          | §5             |
| `:catmgr`            | full screen   | `Agendum.TUI.CategoryScreens.Manager`    | F9                                                | R2–R8          |
| `:viewmgr`           | box           | `Agendum.TUI.Boxes.ViewManager`          | F8                                                | §5             |
| `:picker`            | box           | `Agendum.TUI.CategoryScreens.Picker`     | many (see above)                                  | §5             |
| `:profile`           | box           | `Agendum.TUI.CategoryScreens.Profile`    | F3 on an item, Item Properties                    | §5             |
| `:group_profile`     | box           | `Agendum.TUI.CategoryScreens.Profile`    | F3 with items marked                              | R35            |
| `:props`             | box           | `Agendum.TUI.CategoryScreens.Properties` | F6 on a section head or in the category manager   | §5             |
| `:choice`            | box           | `Agendum.TUI.CategoryScreens.Choices`    | Category Properties, moves in the manager         | R6a, R7a, R7b  |
| `:choice_list`       | box           | `Agendum.TUI.Boxes.ChoiceListBox`        | F3 on a setting with choices in a box             | §5             |
| `:category_stats`    | box           | `Agendum.TUI.Boxes.CategoryStatsBox`     | Category Properties ▸ Statistics                  | §5             |
| `:item_props`        | box           | `Agendum.TUI.Boxes.ItemProperties`       | F6 on an item, Item ▸ Properties                  | R34, R43       |
| `:set_alarm`         | box           | `Agendum.TUI.Boxes.SetAlarmBox`          | ALT-A, Item ▸ Alarm                               | R38            |
| `:goto`              | box           | `Agendum.TUI.Boxes.GoTo`                 | ALT-F5                                            | R42            |
| `:search_box`        | box           | `Agendum.TUI.Boxes.SearchBox`            | ALT-F6, Utilities ▸ Show ▸ Match                  | R37            |
| `:note_search`       | box           | `Agendum.TUI.Typing.NoteSearch`          | ALT-F6 in a note                                  | R39            |
| `:sort`              | box           | `Agendum.TUI.Boxes.SortBox`              | Item sorting in View or Section Properties        | R36            |
| `:range_filter`      | box           | `Agendum.TUI.Boxes.RangeFilterBox`       | a filter or condition on a date/numeric category  | R28a, R15a     |
| `:run_by_name`       | box           | `Agendum.TUI.Boxes.RunByName`            | CTRL-X                                            | R65d           |
| `:action_box`        | box           | `Agendum.TUI.Boxes.ActionBox`            | Also assign on a date/numeric category            | R15b           |
| `:date_rule`         | box           | `Agendum.TUI.Boxes.DateRuleBox`          | Advanced settings of a date category              | R6b            |
| `:category_match`    | box           | `Agendum.TUI.Boxes.CategoryMatchBox`     | Advanced settings of a standard category          | R16b           |
| `:file_props`        | box           | `Agendum.TUI.Boxes.FileProperties`       | File ▸ Properties                                 | R55, R14e      |
| `:file_stats`        | box           | `Agendum.TUI.Boxes.FileStatsBox`         | File Properties ▸ File statistics                 | §5             |
| `:date_settings`     | box           | `Agendum.TUI.Boxes.DateSettingsBox`      | File Properties ▸ Global date settings            | R14e           |
| `:display_format`    | box           | `Agendum.TUI.Boxes.DisplayFormatBox`     | Global date settings ▸ Display format             | R41, R41a      |
| `:input_format`      | box           | `Agendum.TUI.Boxes.InputFormatBox`       | Global date settings or Customize ▸ Input format  | R41b           |
| `:customize`         | box           | `Agendum.TUI.Boxes.CustomizeBox`         | Utilities ▸ Customize                                  | R40, R14c      |
| `:calendars`         | box           | `Agendum.TUI.Extras.CalendarsBox`         | File ▸ Transfer ▸ Calendars                       | R45            |
| `:feeds`             | box           | `Agendum.TUI.Extras.FeedsBox`             | File ▸ Transfer ▸ Feeds                           | R75            |
| `:auto_assign`       | box           | `Agendum.TUI.Boxes.AutoAssignBox`        | File Properties ▸ Auto-assign settings            | R16a           |
| `:column_props`      | box           | `Agendum.TUI.Boxes.ColumnBox`            | View ▸ Column ▸ Properties                        | R55, R29, R41a |
| `:column_add`        | box           | `Agendum.TUI.Boxes.ColumnAddBox`         | View ▸ Column ▸ Add                               | R55            |
| `:item_column`       | box           | `Agendum.TUI.Boxes.ItemColumnBox`        | View ▸ Column ▸ Properties on the item text       | R55            |
| `:execute`           | box           | `Agendum.TUI.Boxes.ExecuteBox`           | Utilities ▸ Execute                                | R15e           |
| `:questions`         | box           | `Agendum.TUI.Boxes.QuestionsBox`         | Utilities ▸ Questions                              | R16            |
| `:alarm_list`        | box           | `Agendum.TUI.Boxes.AlarmList`            | Utilities ▸ Show ▸ Alarm                                   | R38            |
| `:away`              | box           | `Agendum.TUI.Boxes.AwayBox`              | Opening a file with alarms due while it was closed | R70           |
| `:ag_import`         | box           | `Agendum.TUI.Boxes.ImportReportBox`      | Importing a Lotus Agenda file                     | R72            |
| `:publish`           | box           | `Agendum.TUI.Extras.PublishBox`           | File ▸ Transfer ▸ Publish                         | R74            |
| `:publish_preview`   | box           | `Agendum.TUI.Extras.PublishPreviewBox`    | ENTER in the Publish box                          | R74            |
| `:calendar`          | box           | `Agendum.TUI.Boxes.CalendarBox`          | F3 in a date column, ALT-C                        | R46            |
| `:view_props`        | box           | `Agendum.TUI.Boxes.ViewProps`            | View ▸ Properties, F6 in the view manager         | R78            |
| `:view_stats`        | box           | `Agendum.TUI.Boxes.ViewStatsBox`         | View Properties ▸ View statistics                 | R78            |
| `:section_props`     | box           | `Agendum.TUI.Boxes.SectionBox`           | View ▸ Section ▸ Properties, F6 on a section head | R61            |
| `:numeric_functions` | box           | `Agendum.TUI.Boxes.NumericFunctionsBox`  | Section Properties ▸ Select numeric functions     | R61, R29       |
| `:browse`            | control panel | `Agendum.TUI.Moves.Browse`               | View ▸ Browse, ALT-B                              | R47, R48       |
| `:column_width`      | control panel | `Agendum.TUI.Moves.ColumnWidth`          | View ▸ Column ▸ Width                             | R22a, R55      |
| `:column_move`       | control panel | `Agendum.TUI.Moves.ColumnMove`           | View ▸ Column ▸ Move, ALT-F10 on a column head    | R55            |
| `:section_move`      | control panel | `Agendum.TUI.Moves.SectionMove`          | View ▸ Section ▸ Move, ALT-F10 on a section head  | R62            |
| `:schedule`          | box           | `Agendum.TUI.Boxes.ScheduleBox`          | Utilities ▸ Show ▸ Sched                                 | R49            |
| `:macros`            | box           | `Agendum.TUI.Macros`                     | ALT-F3                                            | R50            |
| `:macro_props`       | box           | `Agendum.TUI.Boxes.MacroProps`           | F6 in the macro manager                           | R50            |
| `:select_file`       | box           | `Agendum.TUI.Boxes.SelectFile`           | F3 in a file-name prompt                          | R51            |
| `:splash`            | full screen   | `Agendum.TUI.Splash`                     | at start; any key or three seconds close it       | R52            |
| `:devtools`          | full screen   | `Agendum.TUI.DevTools`                   | ESC ? (hidden)                                    | —              |

`test/agendum/tui/screens_doc_test.exs` fails when a mode type is added without being listed here.
