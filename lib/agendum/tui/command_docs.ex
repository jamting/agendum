defmodule Agendum.TUI.CommandDocs do
  @moduledoc """
  The longer texts of the commands (R65b): by place and command id, the
  menu's entries by their labels, and the boxes' commands by box. What
  F1 `c` shows under the highlighted command and F1 `d` under a key's
  summary. A text says what the summary has no room for, above all why
  one would use the command, where that is not obvious; a command whose
  summary says it all has none. Texts name few keys, since the list and
  describe key show them beside the text.

  `Agendum.TUI.Commands` reads these when it is compiled; a test checks
  that every text belongs to a command. Pure.
  """

  @view %{
    previous_section:
      "Jumps over the items to the section head above: quicker than ↑ in a long view.",
    next_section: "Jumps over the items to the next section head: quicker than ↓ in a long view.",
    next_column:
      "Columns show more about each item, such as its When date, a person or a priority. " <>
        "With the highlight in a column, typing fills in the item's entry and F3 lists " <>
        "what can go there.",
    insert:
      "Adds an empty item below the highlighted one. Typing does the same; INS is for " <>
        "starting from an empty line. In a column it adds one more entry beside those " <>
        "there, since an item can be in several of a column's categories.",
    edit:
      "Edits the item's text where it stands. On a section head it renames the section's " <>
        "category, in every view. In a column of categories it renames the one shown there, " <>
        "for every item in it; to give this item another, type over the entry or use F3.",
    choices:
      "Lists what can go where the highlight is, to pick rather than type: on an item, " <>
        "every category, those it is in marked; in a column, the categories under its head " <>
        "(a calendar for a date); on a section head, the categories it could show instead.",
    done:
      "Gives the item today's Done date, so views that hide done items stop showing it; " <>
        "again takes it back. A recurring item gets its next occurrence instead.",
    note:
      "Opens the note: text of any length that belongs to the item, or to the section's " <>
        "category, while the item itself stays one line. ♪ shows what has a note.",
    properties:
      "Everything about the item in one box: its text, dates, note and the categories it " <>
        "is in. On a section head, the section's settings; on a column head, the column's.",
    mark:
      "Marked items are what the commands for many items work on: Done, Discard, " <>
        "MakeAssign, When, Move and Copy then ask whether to act on the marked ones or the " <>
        "highlighted one. On a section head it marks every item in the section.",
    unmark_all:
      "Clears every mark in the file, not only in this view, so that a forgotten mark is " <>
        "not swept into the next command for many items.",
    next_marked:
      "Finds the marked items again, round to the top of the view: marks can be far apart.",
    remove:
      "Takes the item out of this section's category only. It stays in the file and in " <>
        "its other categories, so other views still show it: the everyday way to file " <>
        "something on. Yank puts it back elsewhere. On a section head it takes the section " <>
        "out of the view (the category stays); in a column it clears the entry.",
    discard:
      "Deletes the item from the whole file, every view and category; to take it out of " <>
        "this section only, use Remove. On a section head it discards the category and its " <>
        "children, and the items stay in the file. It asks first, and Undo brings it back.",
    make_assign:
      "Assigns the item, or the marked items, to categories picked from a list, without " <>
        "leaving the view: to file several at once, or into a category this view does not show.",
    when:
      "Sets the item's When date by typing it (\"next friday\", \"2026-11-01 14:00\"). It " <>
        "takes the place of a date in the item's text; views sort and filter by it, and an " <>
        "alarm rings by it.",
    move:
      "Move the highlight to another section and press ENTER: the item leaves this " <>
        "section's category for that one and keeps its other categories. On a section head " <>
        "it moves the section within the view; on a column head, the column.",
    copy:
      "Puts the item in another section's category too, and leaves it here: one item, " <>
        "filed in two places. It is not a second item: editing it in one place changes it " <>
        "in both.",
    yank:
      "Puts back the item Remove took out last, into the highlighted section, below the " <>
        "highlighted item: for filing it somewhere else than where it came from. Undo puts " <>
        "it back where it was.",
    hop:
      "An item can show in several sections and views. Hop goes to the next place it " <>
        "shows: further down this view first, then in the views after this one.",
    attach_zettel:
      "A Zettel id is eight letters you can say, such as bonalaku: a name for the item " <>
        "that never changes, to link to it from other items ([[bonalaku]]) and to find it " <>
        "by. An item that has one keeps it.",
    follow_link:
      "Shows the items this one links to, from its text and note, in the Show View: " <>
        "ALT-F8 comes back.",
    linked_from:
      "Shows the items whose text or note links to this one, in the Show View: what " <>
        "refers to it.",
    dependency:
      "Makes the highlighted item wait for the marked ones: it is shown with & until they " <>
        "are done, and View Properties can hide it until then. With nothing marked it offers to " <>
        "clear its dependencies.",
    section_below:
      "A view is a list of sections, each one showing a category's items: this is how a " <>
        "view grows. Pick the category from the list, or type a new one.",
    section_above:
      "A view is a list of sections, each one showing a category's items: this is how a " <>
        "view grows. Pick the category from the list, or type a new one.",
    column_right:
      "A column shows a category's children (or a date) for every item, such as the " <>
        "person or the priority, so they can be seen and set without opening the item.",
    column_left:
      "A column shows a category's children (or a date) for every item, such as the " <>
        "person or the priority, so they can be seen and set without opening the item.",
    collapse:
      "Shows only the section's head and how many items it has, to see a long view's " <>
        "outline. Pressed twice, every section.",
    expand: "Shows a collapsed section's items again. Pressed twice, every section's.",
    toggle_empty:
      "Hides the sections with no items, so that a view with many possible sections shows " <>
        "those in use. Again to show them all.",
    go_to: "Lists the view's sections to jump straight to one: quicker than paging.",
    search:
      "Highlights the items of this view that hold the text, one after another. F7 marks " <>
        "the one highlighted, so that a command for many items can then act on all found.",
    browse:
      "Moves the view's dates for a look ahead or back, without changing the view for " <>
        "good: a datebook a period at a time, a date filter a day (or a week, a month) at a " <>
        "time. ENTER keeps the dates shown, ESC goes back.",
    alarm:
      "Rings at the item's When time, or minutes before it, while Agendum is running. " <>
        "Again cancels it. The item needs a When date and time.",
    execute_all:
      "Applies every category's conditions and actions to every item now. They otherwise " <>
        "reach only the items added or changed after they were set up: run this after " <>
        "changing the rules, to file the items already there.",
    execute_category:
      "Applies the conditions and actions of the section's category and its children to " <>
        "every item now: quicker than all of them, and it touches only that part of the file.",
    next_view: "Steps through the views in the view manager's order, round in a circle.",
    previous_view: "Steps back through the views in the view manager's order, round in a circle.",
    last_view:
      "Back to the view shown before this one, as a browser's back button: after Hop, or " <>
        "a search that showed its results in a view of their own.",
    view_manager:
      "Every view of the file: show one, add, rename, order or discard them. A view is a " <>
        "way of looking at the same items, so a new one copies nothing.",
    category_manager:
      "The whole category hierarchy: add, rename and move the categories items are filed " <>
        "in, and set up the conditions that file items on their own.",
    menu:
      "Every command by area (File, View, Item, Category …): for what has no key, or when " <>
        "the key is forgotten.",
    retrieve: "Opens another file. It asks first when this one has unsaved changes."
  }

  @global %{
    undo:
      "Takes back the last change to the file, one action at a time, as far back as " <>
        "the file was opened.",
    redo: "Brings back what Undo took back, until something else is changed.",
    save:
      "Writes the file. File ▸ Customize can have Agendum save it on its own, after a " <>
        "few minutes without a key pressed.",
    export:
      "Writes the view as text to a file, to print it, send it or keep a copy: Agendum " <>
        "does not drive a printer itself.",
    key_map:
      "The key bar at the foot of the screen names what the function keys do there. " <>
        "Press it again and again to see what they do with ALT, CTRL and SHIFT (macros " <>
        "by their names), then to hide the bar, which " <>
        "leaves two more rows for items.",
    run_by_name:
      "Finds a command by part of its name or its initials (\"azi\" is Attach Zettel id) " <>
        "and runs it, so a command without a key can be run too, and its key learnt.",
    quit: "Leaves Agendum. It asks first when the file has unsaved changes."
  }

  @catmgr %{
    add_below:
      "Adds a category at the same level: siblings are the choices of their parent, " <>
        "as Anna and Johan under People.",
    add_child:
      "Adds a child: it narrows its parent, and an item in the child is in the parent " <>
        "too (an item for Anna shows under People).",
    add_family:
      "Adds a category after the parent, at the parent's level: to start a new branch " <>
        "without going up first.",
    rename: "Renames it everywhere: in every view, column and list. Its items stay in it.",
    note: "A note on the category: what it is for, or text to keep with it.",
    properties:
      "How items come into it on their own: its conditions (words in the text, dates, " <>
        "other categories), whether its children exclude each other, and its actions.",
    promote:
      "Moves it up a level, beside its parent. Its items stay in it, but are no longer " <>
        "in the old parent through it.",
    demote:
      "Makes it a child of the category above: to group several siblings under one of them.",
    move_up: "Lists, columns and new sections show the children in this order.",
    move_down: "Lists, columns and new sections show the children in this order.",
    move: "Moves it, with its children and their items, under a parent picked from a list.",
    sort: "Puts its children in alphabetical order: for a long list such as People.",
    discard:
      "Deletes the category and its children everywhere. The items stay in the file; only " <>
        "these assignments go. It asks first, and Undo brings it back.",
    execute:
      "Applies its conditions and actions, and its children's, to every item now; they " <>
        "otherwise reach only items added or changed after they were set up.",
    collapse: "Hides the children, to see the hierarchy's outline. Pressed twice, every family."
  }

  @viewmgr %{
    add:
      "A view is a way of looking at the same items: a new one copies nothing, it only " <>
        "shows them differently.",
    move_up: "Next view and Previous view step through the views in this order.",
    move_down: "Next view and Previous view step through the views in this order.",
    order:
      "Finds a view used a moment ago in a long list. Only the list changes: Next view " <>
        "and Previous view keep your order, and the list stays as you set it.",
    discard:
      "Deletes the view only: its items and categories stay, and other views still show them."
  }

  @note %{
    insert_link:
      "Types [[bonalaku]], a link to each marked item, at the cursor: mark them in the " <>
        "view with F7 first, and give them Zettel ids.",
    mark:
      "Marks where a piece of text starts; move to where it ends, then copy, cut or delete " <>
        "it, or make it an item or a category.",
    copy:
      "Without marked text it asks: the word, the line or all the text. What is copied is " <>
        "kept for Paste, also in another note.",
    cut:
      "Without marked text it asks: the word, the line or all the text. What is cut is " <>
        "kept for Paste, also in another note.",
    delete:
      "Deletes without keeping the text for Paste, so what was copied before is still there.",
    next_note:
      "Saves this note and opens the next item's: to go through the notes one after " <>
        "another without going back to the view.",
    previous_note:
      "Saves this note and opens the previous item's: to go through the notes one after " <>
        "another without going back to the view.",
    make_item:
      "Makes a new item in the view's section from the marked text (or a word, a line, " <>
        "all of it): for notes from a meeting that hold things to do.",
    make_category:
      "Makes a new category from the marked text, or the word at the cursor: for names " <>
        "that turn up in notes."
  }

  # what every box shares (`Agendum.TUI.Commands`' `:box`)
  @box %{
    choices:
      "Lists the setting's choices to pick one, rather than stepping through them with SPACE.",
    cancel: "Closes the box and puts back everything changed in it, so trying things out is safe."
  }

  # what every box of settings shares (`Agendum.TUI.Boxes.Box.settings_commands/1`)
  @settings %{
    change: "Steps to the setting's next choice; F3 lists them all, to pick one.",
    done: "Closes the box and keeps what was changed in it; ESC would put it back."
  }

  @column_head "The head is the category the column shows for each item: its children (such " <>
                 "as People for a Person column), its date, or its number."

  # each box's own commands, by the box's module
  @boxes %{
    Agendum.TUI.Macros => %{
      learn:
        "Records what is typed from now until it is stopped, as the macro's keystrokes: " <>
          "the easiest way to make one.",
      properties: "Attaches it to a key, so that the key runs it, and says where it may run."
    },
    Agendum.TUI.CategoryScreens.Profile => %{
      toggle:
        "Puts the item in the category, or takes it out. In a family whose children " <>
          "exclude each other, it also leaves the sibling it was in."
    },
    Agendum.TUI.CategoryScreens.Picker => %{
      new: "Makes a category of what was typed, when none of those listed fits."
    },
    Agendum.TUI.Update.Marked => %{
      marked: "Does it to every marked item, wherever it is in the file.",
      current: "Does it to the highlighted item only; the marks stay, for later."
    },
    Agendum.TUI.Boxes.QuestionsBox => %{
      done: "Assigns the item to the picked categories; the others are not suggested again.",
      close:
        "Leaves the questions for later: the suggestions wait, and ? stays in the title " <>
          "until they are answered."
    },
    Agendum.TUI.Boxes.CalendarBox => %{
      time: "Gives the date a time as well: for an appointment, or an alarm to ring by."
    },
    Agendum.TUI.Boxes.SectionBox => %{
      properties:
        "The head category's own properties: its conditions and actions, which reach every " <>
          "item the section gets.",
      add: "Adds a column to this section only; the view's other sections keep theirs."
    },
    Agendum.TUI.Boxes.CopyBox => %{
      copy:
        "Puts the item in that section's category too, and leaves it here: one item, filed " <>
          "in two places."
    },
    Agendum.TUI.Boxes.ColumnAddBox => %{pick_head: @column_head},
    Agendum.TUI.Boxes.ItemColumnBox => %{pick_head: @column_head},
    Agendum.TUI.Boxes.ColumnBox => %{pick_head: @column_head},
    Agendum.TUI.Boxes.AlarmList => %{
      cancel_alarm: "The alarm will not ring; the item and its When date stay.",
      remove: "Takes an alarm that has rung off the list; the item stays."
    },
    Agendum.TUI.Boxes.ItemProperties => %{
      profile: "Every category, those the item is in marked: to see why it shows where it does.",
      set_value:
        "In a date or a numeric category the item holds a value too, its date or its " <>
          "number: this changes it.",
      remove: "Takes the item out of that category, or drops that dependency; the item stays."
    },
    Agendum.TUI.Boxes.SelectFile => %{
      dates: "Shows when each file was last changed: to find the one worked on lately."
    },
    Agendum.TUI.Boxes.MacroProps => %{
      detach:
        "Takes the macro off its key, which then does what it did before; the macro stays, " <>
          "to run from the macro list."
    },
    Agendum.TUI.Boxes.ExecuteBox => %{
      done:
        "Applies the conditions and actions now. They otherwise reach only the items added " <>
          "or changed after they were set up."
    },
    Agendum.TUI.Extras.CalendarsBox => %{
      subscribe:
        "Give the calendar's iCal address (Google, Fastmail and Outlook all have one): its " <>
          "events come in as items with When dates, beside the rest of the file.",
      how_often:
        "Read again this often while Agendum is running, so that changes made elsewhere " <>
          "show up.",
      ahead: "How far ahead its events are brought in: a short reach keeps the file small.",
      unsubscribe: "Stops reading it, and asks whether to discard the items it brought in."
    }
  }

  # the menu's entries, by their labels from the top (an entry that runs
  # a view's or a global command without one here has that command's text)
  @menu %{
    ~w(Item Zettel) =>
      "Zettel ids name items for good, so that items can link to each other: [[bonalaku]] " <>
        "in a text or note, or the id on its own, is a link.",
    ~w(File Write) =>
      "Saves the file under a new name and goes on in it: for a version to keep, or a " <>
        "file to start another from.",
    ~w(File New) => "Starts an empty file. It asks first when this one has unsaved changes.",
    ~w(File Dating) =>
      "Agendum reads dates in an item's text (\"call Bob friday\") as its When date. Turn " <>
        "this off in a file whose text names dates that are not when things happen, such " <>
        "as a reading list.",
    ~w(File Properties) =>
      "How this file shows dates and times, and its other settings. They are kept in the " <>
        "file, so it looks the same to everyone who opens it.",
    ~w(File Customize) =>
      "Settings that are yours, not the file's: the theme, date languages, how numbers and " <>
        "dates are typed. They hold for every file you open.",
    ~w(File Transfer) =>
      "JSON is a readable copy of the whole file: for a backup that can be read, for " <>
        "scripts, or for moving to another program.",
    ~w(File Transfer Import) =>
      "Opens a JSON file as a new, untitled file, so nothing open is overwritten.",
    ~w(File Transfer Calendars) =>
      "Subscribed calendars (iCal addresses) come in as items with When dates and are " <>
        "read again by themselves: appointments beside the things to do.",
    ~w(Item Show) =>
      "Every category, those the item is in marked: to see why it shows where it does, and " <>
        "change it.",
    ~w(Category Add) =>
      "Adds a category at the top, under MAIN. To put one elsewhere in the hierarchy, use " <>
        "the category manager.",
    ~w(Category Recalc) =>
      "Assigns and dates every item again from its text, as when it was typed: after " <>
        "categories were renamed or matching changed, so that older items are filed as new " <>
        "ones would be.",
    ~w(Category Execute) =>
      "Chooses whose conditions and actions to apply now, and to which items. They " <>
        "otherwise reach only the items added or changed after they were set up.",
    ~w(Category Questions) =>
      "When File Properties says to confirm assignments, a text that matches a category is " <>
        "a suggestion rather than an assignment: here the suggestions are answered.",
    ~w(View Properties) =>
      "A datebook view's sections are dates (a day, a week …): how long a period is, the " <>
        "date it starts from, and which date it goes by.",
    ~w(Search File) =>
      "Finds the text in every item of the file, not only those this view shows, and lists " <>
        "them in the Show View. ALT-F8 goes back.",
    ~w(Search Alarms) =>
      "The alarms set, and today's that have rung: to cancel one, or see what was missed.",
    ~w(Search Schedule) =>
      "One date's items, from every category, in the Show View: what a day holds.",
    ~w(Search Depends) => "The items that wait for this one: what it holds up.",
    ~w(Search Prereqs) => "The items this one waits for: what must be done first."
  }

  # the modes that move something, browsing and searching (R65b)
  @move_item %{
    drop:
      "Puts the item(s) in the highlighted section, below the highlighted item: each " <>
        "leaves the section it came from and joins this one. Marked items keep their order."
  }

  @searching %{
    next_match:
      "Goes on to the next item that holds what you searched for, in the view's order; " <>
        "a message says when there are no more.",
    mark:
      "Marks the match with ♦, so that one command can then act on every item found, " <>
        "such as Done, Discard or Move."
  }

  @browse %{
    earlier:
      "In a datebook view, the period before: a day, a week, a month or a quarter, as the " <>
        "view is set. In a view with a date filter, its dates a day earlier.",
    later:
      "In a datebook view, the next period: a day, a week, a month or a quarter, as the " <>
        "view is set. In a view with a date filter, its dates a day later.",
    go_to:
      "Shows the period of a date you type; a date filter moves so that its range starts " <>
        "on that date.",
    keep:
      "Makes the dates shown the view's own: a datebook's date, or the filter's dates, " <>
        "written as dates. One undo takes it back.",
    close: "Leaves the view as it was before browsing: nothing was changed while browsing."
  }

  @column_width %{
    fit:
      "Makes the column just wide enough for the longest entry the view shows, so " <>
        "nothing is cut off and no room is lost."
  }

  @column_move %{
    left:
      "Moves the column one place left in this section. The item text counts as a place, " <>
        "so a column can stand before it.",
    right:
      "Moves the column one place right in this section. The item text counts as a place, " <>
        "so a column can stand after it."
  }

  @section_move %{
    up:
      "Moves the section above the one before it, in this view only; the categories stay " <>
        "where they are in the hierarchy.",
    down:
      "Moves the section below the one after it, in this view only; the categories stay " <>
        "where they are in the hierarchy."
  }

  # typing: one line, and a note's text (R65b)
  @line %{
    delete_word:
      "Deletes back to the start of the word before the cursor: quicker than BACKSPACE " <>
        "for a word typed wrong.",
    clear: "Empties the line, to type it again from the start; ESC leaves without a change."
  }

  @text %{
    up:
      "The row above as the note is shown, wrapped to the screen, not the line above in " <>
        "the text.",
    down:
      "The row below as the note is shown, wrapped to the screen, not the line below in " <>
        "the text.",
    line_start:
      "The first press goes to the start of the row shown; a second to the start of the " <>
        "whole line, which may wrap over several rows.",
    line_end:
      "The first press goes to the end of the row shown; a second to the end of the " <>
        "whole line, which may wrap over several rows.",
    new_line:
      "Breaks the line here. A note keeps its line breaks; a long line wraps on screen " <>
        "by itself, so it needs none."
  }

  @doc """
  A menu entry's text, by its labels from the top (`["Category",
  "Recalc"]`), or the text of the command it runs (`action`), or nil.
  """
  @spec menu([String.t()], term) :: String.t() | nil
  def menu(labels, action) do
    @menu[labels] || (is_atom(action) && (@view[action] || @global[action])) || nil
  end

  @doc "The menu's own texts, by labels (a test checks each names an entry)."
  @spec menu_labels() :: [[String.t()]]
  def menu_labels, do: Map.keys(@menu)

  @doc """
  A box's command's text: the box's own (`box` is its module), else, in
  a box of settings (`settings?`), that of what every one shares; nil
  when it has none. Only settings boxes share them: Done is Search in the
  search box, and the shared text would be wrong there.
  """
  @spec box(module, atom, boolean) :: String.t() | nil
  def box(box, id, settings?),
    do: get_in(@boxes, [box, id]) || (settings? && @settings[id]) || nil

  @doc "The boxes' own texts, by module (a test checks each names a command)."
  @spec boxes() :: %{module => %{atom => String.t()}}
  def boxes, do: @boxes

  @doc "Every place's texts, by command id."
  @spec all() :: %{atom => %{atom => String.t()}}
  def all,
    do: %{
      view: @view,
      global: @global,
      catmgr: @catmgr,
      viewmgr: @viewmgr,
      note: @note,
      box: @box,
      move_item: @move_item,
      searching: @searching,
      browse: @browse,
      column_width: @column_width,
      column_move: @column_move,
      section_move: @section_move,
      line: @line,
      text: @text
    }
end
