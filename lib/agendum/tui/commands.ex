defmodule Agendum.TUI.Commands do
  @moduledoc """
  The commands keys can run, by place (ADR 0033): `Agendum.TUI.Keymap`
  binds keys to their ids, `Agendum.TUI.Update.ViewKeys.run` runs the
  view's. The order is the one the command list will show.

  So far the view's (`:view`), the category manager's (`:catmgr`), the view
  manager's (`:viewmgr`) and the global ones (`:global`); other places move over a few at a time.
  Pure.
  """

  alias Agendum.TUI.Command

  # {id, name, summary, count}: what a count does is chosen with care
  # (ADR 0033): moves take one; commands that change the file do not
  @view [
    {:up, "Up", "Highlight the row above", :own},
    {:down, "Down", "Highlight the row below", :own},
    {:page_up, "Page up", "Highlight the row a screen up", :own},
    {:page_down, "Page down", "Highlight the row a screen down", :own},
    {:top, "Top", "Highlight the first row of the view", :none},
    {:bottom, "Bottom", "Highlight the last row of the view", :none},
    {:previous_section, "Previous section", "Highlight the section head above", :own},
    {:next_section, "Next section", "Highlight the section head below", :own},
    {:next_column, "Next column", "Highlight the column to the right", :own},
    {:previous_column, "Previous column", "Highlight the column to the left", :own},
    {:insert, "Insert", "Add an item below, or a column entry", :none},
    {:edit, "Edit", "Edit the item, head or column entry", :none},
    {:choices, "Choices", "Column choices, calendar or profile", :none},
    {:done, "Done", "Mark the item(s) done", :none},
    {:note, "Note", "The note of the item or category", :none},
    {:properties, "Properties", "Item, section or column properties", :none},
    {:mark, "Mark", "Mark the item, or all in the section", :none},
    {:unmark_all, "Unmark all", "Unmark every marked item", :none},
    {:next_marked, "Next marked", "Highlight the next marked item", :repeat},
    {:remove, "Remove", "Remove from the section or column", :none},
    {:discard, "Discard", "Discard the item(s) from the file", :none},
    {:make_assign, "MakeAssign", "Assign the item(s) to a category", :none},
    {:when, "When", "Set the item's When date", :none},
    {:move, "Move", "Move the item(s), section or column", :none},
    {:copy, "Copy", "Copy the item to another section", :none},
    {:yank, "Yank", "Put back the item DEL removed last", :none},
    {:hop, "Hop", "Highlight the item's next occurrence", :repeat},
    {:dependency, "Depend", "Make it depend on the marked items", :none},
    {:section_below, "Add section below", "Add a section below this one", :none},
    {:section_above, "Add section above", "Add a section above this one", :none},
    {:column_right, "Add column right", "Add a column to the right", :none},
    {:column_left, "Add column left", "Add a column to the left", :none},
    {:collapse, "Collapse", "Collapse the section (twice: all)", :none},
    {:expand, "Expand", "Expand the section (twice: all)", :none},
    {:toggle_empty, "Empty sections", "Show or hide empty sections", :none},
    {:go_to, "Go to", "Highlight a section chosen from a list", :none},
    {:search, "Search", "Search the view", :none},
    {:browse, "Browse", "Browse the view's dates", :none},
    {:calendar, "Calendar", "Show the calendar", :none},
    {:alarm, "Alarm", "Set an alarm on the item", :none},
    {:execute_all, "Execute all", "Run all conditions and actions", :none},
    {:execute_category, "Execute", "Run the section's conditions, actions", :none},
    {:next_view, "Next view", "Show the next view", :repeat},
    {:previous_view, "Previous view", "Show the previous view", :repeat},
    {:last_view, "Last view", "Show the view shown before this one", :none},
    {:view_manager, "View manager", "List the file's views", :none},
    {:category_manager, "Category manager", "Show the category hierarchy", :none},
    {:menu, "Menu", "Open the menu", :none},
    {:help, "Help", "Show the keys", :none},
    {:save, "Save", "Save the file", :none},
    {:retrieve, "Retrieve", "Open another file", :none}
  ]

  # the category manager (F9); no counts here yet (ADR 0033: views first)
  @catmgr [
    {:up, "Up", "Highlight the category above", :none},
    {:down, "Down", "Highlight the category below", :none},
    {:page_up, "Page up", "A screen up", :none},
    {:page_down, "Page down", "A screen down", :none},
    {:first, "First", "Highlight MAIN, the first category", :none},
    {:last, "Last", "Highlight the last category", :none},
    {:parent, "Parent", "Highlight the parent", :none},
    {:last_sibling, "Last sibling", "Highlight the last of the siblings", :none},
    {:previous_sibling, "Previous sibling", "Highlight the sibling above", :none},
    {:next_sibling, "Next sibling", "Highlight the sibling below", :none},
    {:add_below, "Add below", "Add a category below this one", :none},
    {:add_above, "Add above", "Add a category above this one", :none},
    {:add_child, "Add child", "Add a child of this category", :none},
    {:add_family, "Add family", "Add a category after the parent", :none},
    {:rename, "Rename", "Rename the category", :none},
    {:note, "Note", "The category's note", :none},
    {:properties, "Properties", "The category's properties", :none},
    {:promote, "Promote", "Move the category up a level", :none},
    {:demote, "Demote", "Make it a child of the one above", :none},
    {:move_up, "Move up", "Move it above its previous sibling", :none},
    {:move_down, "Move down", "Move it below its next sibling", :none},
    {:move, "Move", "Move it under another parent", :none},
    {:sort, "Sort", "Sort its children by name", :none},
    {:discard, "Discard", "Discard it and its children", :none},
    {:execute, "Execute", "Run its conditions and actions", :none},
    {:collapse, "Collapse", "Collapse the family (twice: all)", :none},
    {:expand, "Expand", "Expand the family (twice: all)", :none},
    {:help, "Help", "Show the keys", :none},
    {:close, "Return", "Back to the view", :none}
  ]

  # the view manager (F8)
  @viewmgr [
    {:up, "Up", "Highlight the view above", :none},
    {:down, "Down", "Highlight the view below", :none},
    {:first, "First", "Highlight the first view", :none},
    {:last, "Last", "Highlight the last view", :none},
    {:show, "Show", "Show the highlighted view", :none},
    {:add, "Add", "Add a view", :none},
    {:rename, "Rename", "Rename the view", :none},
    {:move_up, "Move up", "Move the view up the list", :none},
    {:move_down, "Move down", "Move the view down the list", :none},
    {:sort, "Sort", "Sort the views by name", :none},
    {:discard, "Discard", "Discard the view (items are kept)", :none},
    {:help, "Help", "Show the keys", :none},
    {:close, "Return", "Back to the view shown", :none}
  ]

  # the keys that work on every screen but while typing (`Update`'s
  # global keys); Save and Retrieve are also the view's ALT-W and ALT-G
  @global [
    {:undo, "Undo", "Undo the last change", :none},
    {:redo, "Redo", "Redo what was undone", :none},
    {:save, "Save", "Save the file", :none},
    {:retrieve, "Retrieve", "Open another file", :none},
    {:export, "Print", "Print the view to a file (in a view)", :none},
    {:key_map, "Key map", "Show or hide the function key map", :none},
    {:quit, "Quit", "Quit Agendum", :none}
  ]

  @commands %{
    view:
      for {id, name, summary, count} <- @view do
        %Command{id: id, name: name, summary: summary, count: count}
      end,
    catmgr:
      for {id, name, summary, count} <- @catmgr do
        %Command{id: id, name: name, summary: summary, count: count}
      end,
    viewmgr:
      for {id, name, summary, count} <- @viewmgr do
        %Command{id: id, name: name, summary: summary, count: count}
      end,
    global:
      for {id, name, summary, count} <- @global do
        %Command{id: id, name: name, summary: summary, count: count}
      end
  }

  @doc "The commands of a place, in the command list's order."
  @spec all(atom) :: [Command.t()]
  def all(place), do: Map.get(@commands, place, [])

  @doc "A place's command by id, or nil."
  @spec get(atom, atom) :: Command.t() | nil
  def get(place, id), do: Enum.find(all(place), &(&1.id == id))
end
