# Data model

How an Agenda file is represented in memory and on disk. For how the data
is read and changed, see [`DATA_ACCESS.md`](DATA_ACCESS.md).

An Agenda file is **one immutable value**, `%Agenda.Core.Database{}`. Every
change produces a new value; nothing is updated in place. This is what
makes undo a matter of keeping old values (`Agenda.TUI.History`).

## Overview

```mermaid
erDiagram
    DATABASE ||--o{ ITEM : "items (by id)"
    DATABASE ||--|{ CATEGORY : "categories (by id)"
    DATABASE ||--|{ VIEW : "views (by id)"
    DATABASE ||--|| LINKS : "links"
    DATABASE ||--o{ CALENDAR : "calendars (by id)"
    DATABASE ||--o{ MACRO : "macros (by id, in macro_order)"
    CALENDAR }o--|| CATEGORY : "files items in"
    CATEGORY ||--o{ CATEGORY : "children (ordered)"
    ITEM }o--o{ CATEGORY : "explicit assignment (LINKS)"
    CATEGORY }o--o{ CATEGORY : "also_assign"
    CATEGORY }o--o{ CATEGORY : "excludes (both ways)"
    VIEW ||--o{ SECTION : "sections (ordered)"
    SECTION ||--o{ COLUMN : "columns (ordered, R55)"
    VIEW ||--o{ COLUMN : "a datebook's columns"
    SECTION }o--|| CATEGORY : "headed by"
    COLUMN }o--|| CATEGORY : "headed by"

    DATABASE {
        map items "id => Item"
        list item_order "item ids, display order"
        map categories "id => Category"
        map views "id => View"
        list view_order "view ids, view manager order"
        Links links "item <-> category"
        int next_id "shared id counter"
        int main_id "the MAIN category"
        map special "entry/when/done => category id"
        set conditional "item-category links made by conditions"
        DateFormat date_format "how dates and times display (R41)"
        DateSettings date_settings "how typed dates are read (R14e)"
        map numbers "item and numeric category => number (R29)"
        map dates "item and user date category => date, time, set by hand (R6a)"
        Links dependencies "dependent item <-> prerequisite item (R43)"
        atom confirm_assignments "never, always or sometimes (R16)"
        TextMatch match_settings "how item text matches categories (R16a)"
        map suggestions "item => suggested categories (R16)"
        map calendars "id => Calendar subscription (R45)"
        map macros "id => Macro (R50)"
        list macro_order "macro ids in the macro manager's order"
        atom insert_columns "all or section: where new columns go (R55)"
    }
    ITEM {
        int id PK
        string text
        string note
        date entry "set on creation"
        date when "nil or a date"
        date done "nil or completion date"
        bool when_explicit "When set by the user, not the text"
        time when_time "time of day on the When date, or nil"
        int alarm_minutes "0-60 before When, or nil"
        datetime alarm_rung_at "when the alarm went off"
        bool marked
        map recurrence "rule of a recurring When date, or nil (R14a)"
    }
    CATEGORY {
        int id PK
        string name
        string short_name "optional alias for matching"
        int parent_id FK "nil only for MAIN"
        list children "ordered child ids"
        atom kind "standard, date or numeric"
        bool exclusive "children mutually exclusive"
        bool match_name "auto-assign by name"
        list also_assign "category ids"
        list excludes "category ids, negative links (R9)"
        DateRule date_rule "how a date category gets dates (R6b)"
        map match_overrides "text matching settings of its own (R16b)"
        string also_match "text conditions (R15d)"
        list actions "remove, date and number actions (R15b)"
        atom special "done, discard or nil (R15b)"
        list conditions "category ids: assigned, not, or a date/number range"
        string note
    }
    VIEW {
        int id PK
        string name
        bool hide_done
        bool hide_empty
        bool hide_inherited
        list filter "category ids: assigned, not, or a date/number range"
        list sort "SortKey list, at most two"
        map match "Show View: a Search, a list of items, or nil"
        bool hide_dependent "hide items waiting for prerequisites"
        atom section_sort "none, category, alpha or numeric"
        atom section_order "asc or desc"
        map datebook "Datebook settings, or nil for a standard view"
    }
    SECTION {
        int category_id FK
        bool collapsed
        list filter "on top of the view filter"
        list sort "nil = as the view"
        list columns "Column list (R55)"
    }
    COLUMN {
        int category_id FK
        int width
        NumberFormat number "numeric columns (R29)"
        DateFormat date "date columns; nil = the file's (R41a)"
        bool linked "one column with the linked ones of its head (R55)"
    }
    LINKS {
        map by_left "item id => set of category ids"
        map by_right "category id => set of item ids"
    }
    CALENDAR {
        int id PK
        string name
        string url "https (webcal read as https)"
        int category_id FK
        int ahead_days "import up to this far ahead"
        int refresh_minutes "nil = only on request"
        map events "uid => item id and what it last looked like"
        datetime refreshed_at
        string error
    }
    MACRO {
        int id PK
        string name "up to 35 characters, unique"
        string keys "keystrokes in Agenda's notation"
        string key "attached key, or nil"
        map run_from "view, note, catmgr, elsewhere => boolean"
    }
```

## The structs

```mermaid
classDiagram
    direction LR
    class Database {
        +items : Map~id, Item~
        +item_order : [id]
        +categories : Map~id, Category~
        +views : Map~id, View~
        +view_order : [id]
        +links : Links
        +next_id : pos_integer
        +main_id : id
        +special : Map~entry/when/done, id~
        +conditional : MapSet
        +date_format : DateFormat
        +date_settings : DateSettings
        +numbers : Map~item_id and cat_id, float~
        +dates : Map~item_id and cat_id, date time explicit~
        +dependencies : Links
        +confirm_assignments : never, always or sometimes
        +match_settings : TextMatch
        +suggestions : Map~item_id, [cat_id]~
        +calendars : Map~id, Calendar~
        +macros : Map~id, Macro~
        +macro_order : [id]
        +insert_columns : all or section
    }
    class DateFormat {
        +order : yyyymmdd, mmddyy, ddmmmyy, week, relative…
        +separator : String
        +clock : 12 or 24
        +day_of_week : boolean
        +show : date_time, date, time_date or time
        +am_pm : boolean
        +time_separator : colon or hm
    }
    class DateSettings {
        +week_start, week_end : 1..7
        +quarter_start, year_start : 1..12
        +month_alone : first, last or 2..31
        +morning, afternoon, evening : Time
    }
    class Item {
        +id : id
        +text : String
        +note : String
        +entry : Date
        +when : Date | nil
        +done : Date | nil
        +when_explicit : boolean
        +when_time : Time or nil
        +alarm_minutes : 0..60 or nil
        +alarm_rung_at : NaiveDateTime or nil
        +marked : boolean
        +recurrence : Recurrence or nil
    }
    class Recurrence {
        +every : pos_integer
        +unit : day, week, month or year
        +weekday : 1..7 or nil
        +day : 1..31 or nil
    }
    class Category {
        +id : id
        +name : String
        +short_name : String | nil
        +parent_id : id | nil
        +children : [id]
        +kind : :standard | :date | :numeric
        +exclusive : boolean
        +match_name : boolean
        +also_assign : [id]
        +excludes : [id]
        +date_rule : DateRule or nil
        +match_overrides : Map~setting, value~
        +also_match : String
        +actions : [id and action]
        +special : done, discard or nil
        +conditions : [id and kind]
        +note : String
    }
    class View {
        +id : id
        +name : String
        +sections : [Section]
        +columns : [Column], a datebook's
        +hide_done : boolean
        +hide_empty : boolean
        +hide_inherited : boolean
        +filter : [id and kind]
        +sort : [SortKey]
        +match : Search, item list or nil
        +hide_dependent : boolean
        +section_sort : none, category, alpha, numeric
        +section_order : asc or desc
        +datebook : Datebook or nil
    }
    class Datebook {
        +date_category : id
        +end_category : id or nil
        +section_category : id
        +period : day, week, month, quarter
        +interval : 15, 30, 60, day, week, month or nil
        +start_time, end_time : Time or nil
        +start_day, end_day : 1..7 or nil
        +base : String
    }
    class Section {
        +category_id : id
        +collapsed : boolean
        +filter : [id and kind]
        +sort : [SortKey] or nil
        +columns : [Column]
    }
    class Column {
        +category_id : id
        +width : pos_integer
        +number : NumberFormat
        +date : DateFormat or nil
        +linked : boolean
    }
    class NumberFormat {
        +symbol : nil, $, %, ¢, £, ¥
        +decimals : integer
        +thousands : boolean
        +negative : minus or parens
        +calcs : [count, total, average, minimum, maximum]
    }
    class Calendar {
        +id : id
        +name : String
        +url : String
        +category_id : id
        +ahead_days : 30, 90, 180 or 365
        +refresh_minutes : nil, 60, 360 or 1440
        +events : Map~uid, snapshot~
        +refreshed_at : NaiveDateTime or nil
        +error : String or nil
    }
    class Macro {
        +id : id
        +name : String
        +keys : String
        +key : String or nil
        +run_from : Map~place, boolean~
    }
    class Links {
        +by_left : Map~item_id, MapSet~
        +by_right : Map~category_id, MapSet~
    }
    Database *-- Item
    Item *-- Recurrence
    Database *-- Category
    Database *-- View
    Database *-- Links
    Database *-- DateFormat
    Database *-- DateSettings
    Database *-- Calendar
    Database *-- Macro
    View *-- Section
    Section *-- Column
    View *-- Column
    View *-- Datebook
    Column *-- NumberFormat
    Column *-- DateFormat
```

| Struct                                | Module                             | Notes                                                                                                |
| ------------------------------------- | ---------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `Database`                            | `lib/agenda/core/database.ex`      | The whole file. Maps are keyed by id; order lives in separate lists.                                 |
| `Item`                                | `lib/agenda/core/item.ex`          | Free text and dates. **Does not know its categories.**                                               |
| `Category`                            | `lib/agenda/core/category.ex`      | Tree node with flags for the assignment rules. **Does not know its items.**                          |
| `View`, `View.Section`, `View.Column` | `lib/agenda/core/view.ex`          | Pure presentation config; references categories by id.                                               |
| `Links`                               | `lib/agenda/core/links.ex`         | Generic bidirectional many-to-many relation.                                                         |
| `DateFormat`                          | `lib/agenda/core/date_format.ex`   | How the file and date columns display dates and times (R41, R41a).                                   |
| `DateSettings`                        | `lib/agenda/core/date_settings.ex` | How the file reads typed dates: week, quarter and year boundaries, month alone, times of day (R14e). |
| `NumberFormat`                        | `lib/agenda/core/number_format.ex` | How a numeric column shows numbers and which calculations it shows; also reads typed numbers (R29).  |
| `Calendar`                            | `lib/agenda/core/calendar.ex`      | A calendar subscription: its address, its category, and the events it last read (R45).               |

### Ids

Items, categories and views draw ids from **one counter**, `next_id`, just as
the patent keeps all objects in one object file (`.AGA`). An id therefore
says nothing about its type; look it up in the right map. Ids are never
reused. Lower ids were created earlier, and the automatic-assignment
tie-break relies on that ("prefer the category created first").

### Ordering

Maps are unordered, so order is stored separately:

| Order              | Stored in                       | Meaning                                                                                                               |
| ------------------ | ------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Items              | `db.item_order`                 | Global order of items. Sections show their items in this order, and a new item is inserted after the highlighted one. |
| Sibling categories | `category.children`             | Order in the hierarchy (category manager, column choices).                                                            |
| Views              | `db.view_order`                 | Order in the view manager. The first view opens on start.                                                             |
| Sections, columns  | `view.sections`, `section.columns` | Top-to-bottom, left-to-right; a datebook view's columns are `view.columns` (R55).                                  |

## Items, categories and links

This is the core idea from US patent 5,115,504. Items and categories are
independent objects, joined by independent **link structures**. In the
patent each link is a record with four pointers that chains it into the
item's list and the category's list (FIG. 2, 3B). Here the same relation
is two indexes kept in lockstep:

```mermaid
flowchart LR
    subgraph by_left ["links.by_left  (item → categories)"]
        L17["17 ⟶ {5, 8, 12}"]
        L18["18 ⟶ {5, 10, 13}"]
    end
    subgraph by_right ["links.by_right  (category → items)"]
        R5["5 ⟶ {16, 17, 18, 19, 20}"]
        R8["8 ⟶ {17}"]
        R12["12 ⟶ {17}"]
    end
    L17 -. same link .- R8
    L17 -. same link .- R12
```

`Links.link/3` and `Links.unlink/3` always update both maps, and empty
sets are removed. A property test (`test/agenda/core/links_test.exs`)
checks that the two indexes always describe the same relation.

Only **explicit** assignments are stored. Membership through the hierarchy
(subsumption) is computed when asked; see `Database.member?/3` in
[`DATA_ACCESS.md`](DATA_ACCESS.md#membership-subsumption).

### Special categories

`Database.new/1` creates four categories that cannot be renamed, moved
or deleted (`Database.protected?/2`):

| Category                   | Kind     | Membership                                                                             |
| -------------------------- | -------- | -------------------------------------------------------------------------------------- |
| MAIN (`db.main_id`)        | standard | Root of the tree. **Every item** is a member; never linked.                            |
| Entry (`db.special.entry`) | date     | Item's `entry` date (set when created).                                                |
| When (`db.special.when`)   | date     | Item's `when` date: read from its text, or set explicitly (`when_explicit`), SPEC R14. |
| Done (`db.special.done`)   | date     | Item's `done` date (F4).                                                               |

Date categories are never linked. Their membership _is_ the item's date
field (`Database.date_field/2` maps a category id to `:entry`, `:when` or
`:done`).

## Worked example

The demo file (`Agenda.Sample.build/1`), based on the patent's example
view. Its category hierarchy, with ids:

```mermaid
flowchart TB
    C1["1 MAIN"] --> C2["2 Entry<br/><i>date</i>"]
    C1 --> C3["3 When<br/><i>date</i>"]
    C1 --> C4["4 Done<br/><i>date</i>"]
    C1 --> C5["5 Calls"]
    C1 --> C7["7 Priority<br/><i>exclusive</i>"]
    C1 --> C11["11 Contact"]
    C1 --> C15["15 Meetings"]
    C7 --> C8["8 High"]
    C7 --> C9["9 Medium"]
    C7 --> C10["10 Low"]
    C11 --> C12["12 Anna Lasky<br/><i>aka Anna</i>"]
    C11 --> C13["13 Abigail Scheer<br/><i>aka Abigail</i>"]
    C11 --> C14["14 Daniel Fiske<br/><i>aka Daniel</i>"]
```

There is one view, `6 "Activities"`, with a section on Calls (5) and
columns When (3), Priority (7) and Contact (11). Note the shared id space:
the view was created between categories `5` and `7`.

Item 17, _"Don't forget to call Anna Lasky with the information she
requested."_, shows the difference between stored links and computed
membership:

```mermaid
flowchart LR
    I17(["Item 17"])
    I17 == stored link ==> C5["5 Calls"]
    I17 == stored link ==> C8["8 High"]
    I17 == stored link ==> C12["12 Anna Lasky"]
    C8 -. member by subsumption .-> C7["7 Priority"]
    C12 -. member by subsumption .-> C11["11 Contact"]
    C5 -.-> C1["1 MAIN"]
    C7 -.-> C1
    C11 -.-> C1
```

Only the three thick edges are stored (`links.by_left[17] == {5, 8, 12}`).
Membership of Priority, Contact and MAIN is derived by walking up the tree.
In the view, item 17 appears in the Calls section. The Priority column
shows "High" (the linked descendant of Priority), and the Contact column
shows "Anna Lasky".

The same database as an Elixir term, abbreviated:

```elixir
%Agenda.Core.Database{
  main_id: 1,
  special: %{entry: 2, when: 3, done: 4},
  next_id: 21,
  item_order: [16, 17, 18, 19, 20],
  items: %{
    17 => %Item{id: 17, text: "Don't forget to call Anna Lasky…", entry: ~D[2026-10-08], when: nil, done: nil},
    ...
  },
  categories: %{
    1 => %Category{id: 1, name: "MAIN", parent_id: nil, children: [2, 3, 4, 5, 7, 11, 15]},
    7 => %Category{id: 7, name: "Priority", parent_id: 1, children: [8, 9, 10], exclusive: true, match_name: false},
    12 => %Category{id: 12, name: "Anna Lasky", short_name: "Anna", parent_id: 11},
    ...
  },
  views: %{6 => %View{id: 6, name: "Activities", sections: [%Section{category_id: 5, columns: [...]}]}},
  view_order: [6],
  links: %Links{
    by_left: %{16 => MapSet.new([5, 9]), 17 => MapSet.new([5, 8, 12]), ...},
    by_right: %{5 => MapSet.new([16, 17, 18, 19, 20]), 8 => MapSet.new([17]), ...}
  }
}
```

### Datebook views

A view with `datebook` set (R47, `Agenda.Core.Datebook`) shows time slots instead
of its stored sections, which it ignores: the hours of a day, the days of a
week, or the days, weeks or months of a month or quarter, worked out from
the settings and the clock every time the view is built
(`Datebook.slots/3`), since `base` is typed text such as "today" or "next
week". A slot shows the items of the Section category whose date in the
date category (and, with an End category, their span up to its date) falls
in it; nothing about slots is stored. Deleting a category a datebook uses
falls back to When (and the end category to none).

## Invariants

The core maintains these, and the tests check them (including the property
tests in `database_test.exs` and `links_test.exs`):

1. **Tree.** Every category except MAIN has a `parent_id` present in
   `categories`, and appears exactly once in that parent's `children`.
   Every category is reachable from MAIN; there are no cycles
   (`move_category/4` refuses them).
2. **Links are symmetric.** `item ∈ by_right[c] ⇔ c ∈ by_left[item]`, and no
   empty sets are stored.
3. **Links reference live objects.** Deleting an item drops its links
   (`delete_item/2`). Deleting a category drops the links of its whole
   subtree (`delete_category/2`).
4. **No links to MAIN or date categories.** `Assign.assign/3` ignores them.
5. **Exclusive families hold at most one branch.** `Assign` clears the
   siblings before linking, and `Core.make_exclusive/3` resolves items
   already in several children before setting the flag (SPEC R7a).
   `Core.move_category/5`, `promote/3` and `demote/3` resolve items a move
   would put in two branches (SPEC R7b). Only the `Database` primitives
   skip these checks; the TUI never calls them directly.
6. **Views reference live categories.** `delete_category/2` removes
   sections and columns headed by deleted categories, and also removes the
   deleted ids from every `also_assign` and `excludes` list.
   Filters and sort keys that name a deleted category are dropped with it.
7. **Order lists match the maps.** `item_order` holds exactly the keys of
   `items`, and `view_order` exactly the keys of `views`. At least one view
   always exists (`delete_view/2` refuses to delete the last one).
8. **Protected categories** (MAIN, Entry, When, Done) always exist, keep
   their names, and stay where they are.
9. **No direct link to both a category and its ancestor** (SPEC R7c). An
   item linked to a category is never also linked to one of its ancestors.
   `Assign.assign/3` clears the item's links to the category's ancestors and
   descendants before linking, and category moves resolve the conflicts
   they would create. Files saved before R7c may still contain such pairs;
   assigning those items again tidies them up.
10. **Conditional marks are links.** Every `{item, category}` in
    `db.conditional` is also a link; `Database.unlink/3` and the delete
    operations remove marks with their links. A user assignment clears the
    mark, so only condition-made links are ever retracted (SPEC R15).

## Mapping to the patent

| Patent (US 5,115,504)                                        | This implementation                                                       |
| ------------------------------------------------------------ | ------------------------------------------------------------------------- |
| Object file `.AGA` (category, item, view, genealogy objects) | `db.categories`, `db.items`, `db.views` with one `next_id`                |
| Link-structure file `.AGB`                                   | `db.links` (`Links`)                                                      |
| Link structure joining item and category (FIG. 2)            | an entry in both `by_left` and `by_right`                                 |
| Category chains: first/last child, sibling pointers (FIG. 1) | `parent_id` + ordered `children` list                                     |
| Genealogy object (cached ancestors)                          | `Database.ancestors/2`, computed on demand                                |
| Subsumption / inheritance (FIG. 4)                           | `Database.member?/3`, computed on demand                                  |
| View linked to categories (FIG. 5)                           | `View.sections` / `Section.columns` holding category ids                     |
| Category-to-category links (FIG. 6)                          | `Category.also_assign`                                                    |
| Negative links (FIG. 6, crossed squares)                     | `Category.exclusive` (for siblings) and `Category.excludes` (any two, R9) |
| Free object / free link lists                                | not needed: immutable maps, ids never reused                              |

## On disk

`Agenda.Store` writes the whole `Database` value as one Erlang term:

```mermaid
flowchart LR
    DB["%Database{}"] --> T["{:agenda, 2, db}<br/>versioned envelope"]
    T --> B[":erlang.term_to_binary(…, [:compressed])"]
    B --> TMP["file.agendum.tmp"]
    TMP -- "File.rename (atomic)" --> F["file.agendum"]
```

- **Loading** uses `binary_to_term(…, [:safe])`, which refuses unknown
  atoms. `Store.load/1` therefore loads the app's modules first, so that
  struct field names exist as atoms.
- **Versioning.** The number in the envelope is the format version:
  1 is the first; 2 added `Item.when_explicit` and `Database.auto_date`; 3 added `Category.conditions` and `Database.conditional` (R15); 4 added view and section `filter` and `sort` (R28, R36); 5 added the view `match` used by the Show View (R37); 6 added `Item.when_time`, `alarm_minutes` and `alarm_rung_at` (R14b, R38); 7 added `Database.date_format` (R41); 8 added `Database.numbers` and `View.Column.number` (R29); 9 added `Item.recurrence` (R14a); 10 added `Database.dependencies` and `View.hide_dependent` (R43); 11 added `Category.also_match` (R15d); 12 added `Category.actions` and `Category.special` (R15b); 13 added `Database.confirm_assignments` and `Database.suggestions` (R16); 14 added `Database.date_settings` (R14e); 15 replaced `Database.auto_date` with `Database.when_from` (R14f); 16 added `Category.excludes` (R9); 17 added `Database.dates` (R6a); 18 added `Category.date_rule` (R6b), replacing `Database.when_from` with When's rule; 19 added `Database.match_settings` (R16a); 20 added `Category.match_overrides` (R16b); 21 added `View.Column.date` and the `DateFormat` fields `show`, `am_pm` and `time_separator` (R41a); 22 added `Database.calendars` (R45); 23 added `View.datebook` (R47); 24 added `Database.macros` and `macro_order` (R50); 25 moved a standard view's columns into its sections and added `View.Column.linked` (R55); 26 added `Database.insert_columns` (R55)
  (R14). Old terms decode to structs _without_ the new keys, so
  `Store.load/1` accepts every version up to the current one and runs
  `Store.upgrade/1`, which rebuilds each struct so new fields get their
  defaults. Adding a field means bumping the version; a change that defaults
  cannot express (a renamed or reshaped field) also needs a migration step
  in `upgrade/1`. Files from a newer version are refused.
- The format is not human-readable; a text export is on the roadmap.
  See [ADR 0003](adr/0003-file-format.md).

## UI state around the database

The TUI keeps a few database-related values in `Agenda.TUI.State`. They
are not part of the file:

| Field          | Purpose                                                                                |
| -------------- | -------------------------------------------------------------------------------------- |
| `db`           | The current `Database`.                                                                |
| `saved_db`     | The database as last saved or loaded; `dirty` is `db != saved_db`.                     |
| `undo`, `redo` | Snapshots `%{db, view_id, cursor_key}` (max 100), see `Agenda.TUI.History`.            |
| `view_id`      | The view on screen.                                                                    |
| `cursor_key`   | `{:section, index}` or `{:item, section_index, item_id}`; re-found after every change. |
