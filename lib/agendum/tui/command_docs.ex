defmodule Agendum.TUI.CommandDocs do
  @moduledoc """
  The longer texts of the commands (R65b), by place and command id: what
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
    dependency:
      "Makes the highlighted item wait for the marked ones: it is shown with & until they " <>
        "are done, and View ▸ Hide can hide it until then. With nothing marked it offers to " <>
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
      "The key bar at the foot of the screen names what the function keys do there; " <>
        "hidden, it leaves one more row for items.",
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
    discard:
      "Deletes the view only: its items and categories stay, and other views still show them."
  }

  @note %{
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

  @doc "Every place's texts, by command id."
  @spec all() :: %{atom => %{atom => String.t()}}
  def all, do: %{view: @view, global: @global, catmgr: @catmgr, viewmgr: @viewmgr, note: @note}
end
