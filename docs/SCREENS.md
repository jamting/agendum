# Screens and boxes of the TUI

A map of every screen, box and control-panel mode, how to reach each one, and
what it opens in turn. For keys in detail see `docs/KEYBOARD.md` and the F1 help;
for the rules behind each box, the SPEC rule named in the tables.

## How screens stack

Everything the TUI shows on top of the current view is a **mode** on a stack,
`state.modes` (`Agenda.TUI.State`): opening a box pushes one, ESC pops it and
returns to what was underneath. `Agenda.TUI.Update.handle/2` sends each key to
the mode on top; `Agenda.TUI.Render` draws the stack. Modes come in three kinds:

- **Full screens** replace the view: the category manager, the view manager,
  help and the note editor.
- **Boxes** are drawn over the view (or over a full screen) in a frame with a
  title. A box opened from a box sits one line lower and two columns right.
- **Control-panel modes** use only the two lines at the top: the menu, prompts,
  Y/N questions, searching and moving items.

Each mode is a map with a `type` (the atom in the tables below) and its own
fields (cursor, the category or item it is for, a purpose).

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
    View -- "F6 on a section head" --> CatProps["Category Properties"]
    View -- "F3 on an item" --> Profile["Assignment profile"]
    View -- "F3 in a column" --> Picker["Category picker"]
    View -- ALT-F5 --> GoTo["Go to section"]
    View -- ALT-F6 --> SearchBox["Search box"]
    View -- "ALT-F10" --> MoveItem["Moving items"]
    View -- "a key with items marked" --> Scope["Scope box"]
    Menu -- "File ▸ Properties" --> FileProps["File Properties"]
    Menu -- "File ▸ Customize" --> Customize["Customize (yours)"]
    Menu -- "Category ▸ Execute" --> Execute["Execute box"]
    Menu -- "Category ▸ Questions" --> Questions["Questions box"]
    Menu -- "View ▸ Column ▸ Properties" --> ColProps["Column Properties"]
    Menu -- "View ▸ Order / Section ▸ Sort" --> Sort["Sort box"]
    Menu -- "Search ▸ Alarms" --> Alarms["Alarm list"]
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
    DateSettings -- "Display format" --> DisplayFormat["Display format"]
    DateSettings -- "Input format" --> InputFormat["Input format (yours)"]
    FileProps -- "Auto-assign settings" --> AutoAssign["Auto-assign settings"]
    Customize["Customize (yours)"] -- "Input format" --> InputFormat
    ColProps["Column Properties"]
    ColProps -- "numeric column" --> NumCol["Numeric column"]
    ColProps -- "date column" --> DateCol["Date column"]
```

## Everything, by where it is reached

Indentation shows what opens what. `type` is the mode's type; the module draws
or handles it.

- **View** (no mode): the current view's sections, items and columns.
  `Agenda.TUI.Update`, `Agenda.TUI.Layout`, `Agenda.TUI.Render`.
  - **Menu** `:menu` (F10 or `/`): File, Item, Category, View, Search, Undo,
    Redo, Print, Quit. `Agenda.TUI.Menu`. Its commands open most of the boxes below;
    the menu path is given with each.
  - **Help** `:help` (F1; also from the category manager): keys and commands.
    `Agenda.TUI.Render`.
  - **Prompt** `:prompt`: one line of text in the control panel (a file name,
    a new view's name, a category name). `Agenda.TUI.Update`.
    - **Select File** `:select_file` (F3 in a prompt for a file name): the
      folder's subfolders and the files that fit, to pick one (R51).
      `Agenda.TUI.SelectFile`.
  - **Question** `:confirm`: a Y/N question (discard, save changes, make a
    date category). `Agenda.TUI.Update`.
  - **Datebook settings** `:datebook_props` (View ▸ Properties of a datebook
    view; after View ▸ Add with Type Datebook): its categories, period,
    interval, start and end, base date (R47). `Agenda.TUI.DatebookBox`.
    - **Picker** `:picker` for the Date category, End category and Section.
    - **Prompt** `:prompt` for a time (Start at / End at of a day) or the base date.
  - **Choice** `:choice` (View ▸ Add, after the name): Standard or Datebook.
  - **Browsing** `:browse` (View ▸ Browse, ALT-B, in a datebook view or a
    view with a date filter): the view flips to other periods, or its date
    filter moves, until ENTER keeps it or ESC goes back (R47, R48).
    `Agenda.TUI.Browse`.
    - **Prompt** `:prompt` for a date to go to (ALT-F5).
  - **Calendar** `:calendar` (F3 in a date column; ALT-C anywhere in a
    view): the pop-up calendar, to pick a date (and time) for the entry or
    to look one up (R46). `Agenda.TUI.CalendarBox`.
    - **Prompt** `:prompt` for a time (F6) or a date to go to (typing).
  - **Scope** `:scope`: with items marked, whether a command (F3, F4, ALT-F2,
    ALT-F4, ALT-F10, ALT-M, DEL) acts on the highlighted item or all marked
    ones (R35). `Agenda.TUI.Update`.
  - **Moving items** `:move_item` (ALT-F10, Item ▸ Reposition): the item
    follows the cursor until ENTER (R26). `Agenda.TUI.Update`.
  - **Note editor** `:note` (F5, Item ▸ Note): a full screen for an item's
    note; also a category's note from Category Properties or the category
    manager. `Agenda.TUI.TextEdit`, `Agenda.TUI.Update`.
    - **Note search** `:note_search` (ALT-F6 in a note): search and replace,
      then Y/N per match (R39). `Agenda.TUI.NoteSearch`.
  - **Item Properties** `:item_props` (F6 on an item, Item ▸ Properties):
    text, note, statistics, dependencies, every assignment (R34, R43).
    `Agenda.TUI.ItemProperties`.
    - **Assignment profile** `:profile` (F3).
    - **Item Properties** of a dependency (ENTER on one), on top.
    - **Note editor** `:note` (ENTER on Note).
  - **Assignment profile** `:profile` (F3 on an item, Item ▸ Show): every
    category with the item's assignments marked; SPACE assigns.
    `Agenda.TUI.CategoryScreens`.
  - **Group profile** `:group_profile` (F3 with items marked, "all marked"):
    the same for several items (R35). `Agenda.TUI.CategoryScreens`.
  - **Category picker** `:picker`: choose a category from the hierarchy,
    with search. `Agenda.TUI.CategoryScreens`. Its `purpose` says what the choice
    does:
    - a column entry (F3 in a column), assigning items (ALT-M, Item ▸
      Categorize), a section's category (F3 on a head), a new section (ALT-D,
      ALT-U) or column (ALT-R, ALT-L), a new view's first section
    - filters (View ▸ Filter, Section ▸ Filter, R28); a date or numeric
      category opens the **Range filter** box `:range_filter`
      (`Agenda.TUI.RangeFilterBox`, R28a)
    - sort keys from the Sort box, the Execute box's root, moving a category
      (ALT-F10 in the category manager), conditions, actions and negative
      links (from Category Properties)
  - **Category Properties** `:props` (F6 on a section head; F6 in the
    category manager): name, short name, type, exclusive children, matching,
    conditions, actions, negative links, special actions, advanced settings,
    note. `Agenda.TUI.CategoryScreens`.
    - **Choice** `:choice`: a list of choices with an explanation: the
      category's type (Standard, Numeric, Date; R6a), how to resolve items
      that break exclusive children (R7a) or a move (R7b).
    - **Picker** `:picker` for Conditions, Also assign and Excludes (R15,
      R15b, R9).
      - **Range filter** `:range_filter` as a condition on a date or numeric
        category (R15a).
      - **Action box** `:action_box`: a date or numeric action (R15b).
        `Agenda.TUI.ActionBox`.
    - **Date settings** `:date_rule` (Advanced settings of a date category,
      R6b). `Agenda.TUI.DateRuleBox`.
    - **Text matching** `:category_match` (Advanced settings of a standard
      category, R16b). `Agenda.TUI.CategoryMatchBox`.
    - **Note editor** `:note`.
  - **Category manager** `:catmgr` (F9, Category ▸ Manager): full screen of
    the hierarchy; add, rename, promote, demote, move, sort, discard (R2–R8).
    `Agenda.TUI.CategoryScreens`.
    - **Category Properties** `:props` (F6), **Note editor** `:note` (F5),
      **Help** `:help` (F1), **Picker** `:picker` (ALT-F10, where to move),
      **Choice** `:choice` (conflicts of a move).
  - **View manager** `:viewmgr` (F8, View ▸ Manager): full screen of the
    views; switch, add, rename, reorder, discard. `Agenda.TUI.ViewManager`.
  - **Go to** `:goto` (ALT-F5): jump to a section (R42). `Agenda.TUI.GoTo`.
  - **Search box** `:search_box` (ALT-F6, Search ▸ View or File): what to
    find, in item text, note or both, the direction, ignoring case (R37). `Agenda.TUI.SearchBox`.
    - **Searching** `:searching`: ALT-N / ALT-P step through matches, F7
      marks. A file search shows the Show View instead.
  - **Sort box** `:sort` (View ▸ Order, View ▸ Section ▸ Sort): the sort keys
    of a view or a section (R36). `Agenda.TUI.SortBox`.
    - **Picker** `:picker` for a key's category or note category.
  - **File Properties** `:file_props` (File ▸ Properties): two "..." rows
    opening Agenda's boxes, nested as in Agenda 2.0. `Agenda.TUI.FileProperties`.
    - **Global date settings** `:date_settings` (Global date settings): the
      week, quarter, year and times of day (R14e). `Agenda.TUI.FileProperties`.
      - **Display format** `:display_format` (Display format): how the file
        shows dates, with a sample (R41, R41a). `Agenda.TUI.FileProperties`, rows
        from `Agenda.TUI.DateFormatRows`.
      - **Input format** `:input_format` (Input format): the person's number
        order, date separator and clock, saved as preferences (R41b).
        `Agenda.TUI.InputFormatBox`.
    - **Auto-assign settings** `:auto_assign` (Auto-assign settings): text
      matching for the file and Confirm assignments (R16, R16a).
      `Agenda.TUI.AutoAssignBox`.
  - **Calendars** `:calendars` (File ▸ Transfer ▸ Calendars): calendar
    subscriptions; INS subscribes (two prompts), ENTER reads now, F and A
    change how often and how far ahead, DEL unsubscribes (R45).
    `Agenda.TUI.CalendarsBox`.
  - **Customize** `:customize` (File ▸ Customize): the person's theme, date
    language and fallback language, saved as preferences (R40, R14c).
    `Agenda.TUI.CustomizeBox`.
    - **Input format** `:input_format` (Input format).
  - **Column Properties** (View ▸ Column ▸ Properties, on a column entry):
    - **Numeric column** `:column_props`: number format and calculations
      (R29). `Agenda.TUI.ColumnProperties`.
    - **Date column** `:date_column_props`: the column's own date format or
      the global defaults (R41a). `Agenda.TUI.DateColumnBox`.
  - **Execute** `:execute` (Category ▸ Execute): apply conditions and actions
    to existing items, from a root category (R15e). `Agenda.TUI.ExecuteBox`.
    - **Picker** `:picker` for the root.
  - **Questions** `:questions` (Category ▸ Questions): confirm suggested
    assignments, item by item (R16). `Agenda.TUI.QuestionsBox`.
  - **Show Schedule** `:schedule` (Search ▸ Schedule): one date's items in
    the Show View (R49). `Agenda.TUI.ScheduleBox`.
    - **Picker** `:picker` for the date category, section head and filter.
    - **Prompt** `:prompt` for the date; **Calendar** `:calendar` (F3).
  - **Macros** `:macros` (ALT-F3, also from notes and the category
    manager): the macro manager; INS names a new macro, F7 learns its
    keystrokes, ENTER runs it (R50). `Agenda.TUI.Macros`.
    - **Prompt** `:prompt` for a new macro's name.
    - **Choice** `:choice` (F7 on a macro with keystrokes): replace or append.
    - **Note editor** `:note` (F2): the macro edit screen, its keystrokes as text.
    - **Macro Properties** `:macro_props` (F6): name, keystrokes, attached key,
      where it can run (R50). `Agenda.TUI.MacroProps`.
      - **Prompt** `:prompt` for the name or the key.
  - **Alarm list** `:alarm_list` (Search ▸ Alarms):
    current and past alarms (R38). `Agenda.TUI.AlarmList`.

- **Developer tools** `:devtools` (ESC ?, hidden, from anywhere but while
  typing): a full screen of debugging facts and a key tester; see
  `docs/KEYBOARD.md`. `Agenda.TUI.DevTools`.

Commands that act at once and open nothing (F4 done, F7 mark, ALT-O
dependencies after its question, Undo, Save) are not listed.

## By type

| `type`               | Kind          | Module                        | Reached from                                     | SPEC          |
| -------------------- | ------------- | ----------------------------- | ------------------------------------------------ | ------------- |
| `:menu`              | control panel | `Agenda.TUI.Menu`             | F10 or `/`                                       | §5            |
| `:prompt`            | control panel | `Agenda.TUI.Update`           | commands that ask for a line of text             | §5            |
| `:confirm`           | control panel | `Agenda.TUI.Update`           | commands that ask Y/N                            | §5            |
| `:scope`             | box           | `Agenda.TUI.Update`           | a command with items marked                      | R35           |
| `:move_item`         | control panel | `Agenda.TUI.Update`           | ALT-F10, Item ▸ Reposition                       | R26           |
| `:searching`         | control panel | `Agenda.TUI.SearchBox`        | the Search box                                   | R37           |
| `:help`              | full screen   | `Agenda.TUI.Render`           | F1                                               | §5            |
| `:note`              | full screen   | `Agenda.TUI.Update`           | F5, Item Properties, Category Properties         | §5            |
| `:catmgr`            | full screen   | `Agenda.TUI.CategoryScreens`  | F9, Category ▸ Manager                           | R2–R8         |
| `:viewmgr`           | full screen   | `Agenda.TUI.ViewManager`      | F8, View ▸ Manager                               | §5            |
| `:picker`            | box           | `Agenda.TUI.CategoryScreens`  | many (see above)                                 | §5            |
| `:profile`           | box           | `Agenda.TUI.CategoryScreens`  | F3 on an item, Item ▸ Show, Item Properties      | §5            |
| `:group_profile`     | box           | `Agenda.TUI.CategoryScreens`  | F3 with items marked                             | R35           |
| `:props`             | box           | `Agenda.TUI.CategoryScreens`  | F6 on a section head or in the category manager  | §5            |
| `:choice`            | box           | `Agenda.TUI.CategoryScreens`  | Category Properties, moves in the manager        | R6a, R7a, R7b |
| `:item_props`        | box           | `Agenda.TUI.ItemProperties`   | F6 on an item, Item ▸ Properties                 | R34, R43      |
| `:goto`              | box           | `Agenda.TUI.GoTo`             | ALT-F5                                           | R42           |
| `:search_box`        | box           | `Agenda.TUI.SearchBox`        | ALT-F6, Search ▸ View / File                     | R37           |
| `:note_search`       | box           | `Agenda.TUI.NoteSearch`       | ALT-F6 in a note                                 | R39           |
| `:sort`              | box           | `Agenda.TUI.SortBox`          | View ▸ Order, View ▸ Section ▸ Sort              | R36           |
| `:range_filter`      | box           | `Agenda.TUI.RangeFilterBox`   | a filter or condition on a date/numeric category | R28a, R15a    |
| `:action_box`        | box           | `Agenda.TUI.ActionBox`        | Also assign on a date/numeric category           | R15b          |
| `:date_rule`         | box           | `Agenda.TUI.DateRuleBox`      | Advanced settings of a date category             | R6b           |
| `:category_match`    | box           | `Agenda.TUI.CategoryMatchBox` | Advanced settings of a standard category         | R16b          |
| `:file_props`        | box           | `Agenda.TUI.FileProperties`   | File ▸ Properties                                | R41, R14e     |
| `:date_settings`     | box           | `Agenda.TUI.FileProperties`   | File Properties ▸ Global date settings           | R14e          |
| `:display_format`    | box           | `Agenda.TUI.FileProperties`   | Global date settings ▸ Display format            | R41, R41a     |
| `:input_format`      | box           | `Agenda.TUI.InputFormatBox`   | Global date settings or Customize ▸ Input format | R41b          |
| `:customize`         | box           | `Agenda.TUI.CustomizeBox`     | File ▸ Customize                                 | R40, R14c     |
| `:calendars`         | box           | `Agenda.TUI.CalendarsBox`     | File ▸ Transfer ▸ Calendars                      | R45           |
| `:auto_assign`       | box           | `Agenda.TUI.AutoAssignBox`    | File Properties ▸ Auto-assign settings           | R16a          |
| `:column_props`      | box           | `Agenda.TUI.ColumnProperties` | View ▸ Column ▸ Properties, numeric column       | R29           |
| `:date_column_props` | box           | `Agenda.TUI.DateColumnBox`    | View ▸ Column ▸ Properties, date column          | R41a          |
| `:execute`           | box           | `Agenda.TUI.ExecuteBox`       | Category ▸ Execute                               | R15e          |
| `:questions`         | box           | `Agenda.TUI.QuestionsBox`     | Category ▸ Questions                             | R16           |
| `:alarm_list`        | box           | `Agenda.TUI.AlarmList`        | Search ▸ Alarms                                  | R38           |
| `:calendar`          | box           | `Agenda.TUI.CalendarBox`      | F3 in a date column, ALT-C                       | R46           |
| `:datebook_props`    | box           | `Agenda.TUI.DatebookBox`      | View ▸ Properties of a datebook view             | R47           |
| `:browse`            | control panel | `Agenda.TUI.Browse`           | View ▸ Browse, ALT-B                             | R47, R48      |
| `:schedule`          | box           | `Agenda.TUI.ScheduleBox`      | Search ▸ Schedule                                | R49           |
| `:macros`            | box           | `Agenda.TUI.Macros`           | ALT-F3                                           | R50           |
| `:macro_props`       | box           | `Agenda.TUI.MacroProps`       | F6 in the macro manager                          | R50           |
| `:select_file`       | box           | `Agenda.TUI.SelectFile`       | F3 in a file-name prompt                         | R51           |
| `:splash`            | full screen   | `Agenda.TUI.Splash`           | at start; any key or three seconds close it      | R52           |
| `:devtools`          | full screen   | `Agenda.TUI.DevTools`         | ESC ? (hidden)                                   | —             |

`test/agenda/tui/screens_doc_test.exs` fails when a mode type is added without
being listed here.
