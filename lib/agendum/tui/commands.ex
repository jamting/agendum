defmodule Agendum.TUI.Commands do
  @moduledoc """
  The commands keys can run, by place (ADR 0033): `Agendum.TUI.Keymap`
  binds keys to their ids, `Agendum.TUI.Update.ViewKeys.run` runs the
  view's. The order is the one the command list will show.

  Only the view's commands so far; other places move over a few at a time.
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
    {:insert, "Insert", "Add an item below, or an entry in the highlighted column", :none},
    {:edit, "Edit", "Edit the item, section head, column head or entry", :none},
    {:choices, "Choices", "The column's choices or calendar, or the item's profile", :none},
    {:done, "Done", "Mark the item done (or the marked items)", :none},
    {:note, "Note", "The note of the item, or of the category highlighted", :none},
    {:properties, "Properties", "Properties of the item, section or column", :none},
    {:mark, "Mark", "Mark the item, or every item in the section", :none},
    {:unmark_all, "Unmark all", "Unmark every marked item", :none},
    {:next_marked, "Next marked", "Highlight the next marked item", :repeat},
    {:remove, "Remove", "Remove from the section or column (the item stays in the file)", :none},
    {:discard, "Discard", "Discard the item (or the marked items) from the file", :none},
    {:make_assign, "MakeAssign", "Assign the item (or the marked items) to a category", :none},
    {:when, "When", "Set the item's When date", :none},
    {:move, "Move", "Move the item to another section, or the section or column", :none},
    {:copy, "Copy", "Copy the item to another section", :none},
    {:yank, "Yank", "Put back the item DEL removed last", :none},
    {:hop, "Hop", "Highlight the item's next occurrence", :repeat},
    {:dependency, "Depend", "Make the item depend on the marked items", :none},
    {:section_below, "Add section below", "Add a section below this one", :none},
    {:section_above, "Add section above", "Add a section above this one", :none},
    {:column_right, "Add column right", "Add a column right of the highlighted one", :none},
    {:column_left, "Add column left", "Add a column left of the highlighted one", :none},
    {:collapse, "Collapse", "Collapse the section (twice: all sections)", :none},
    {:expand, "Expand", "Expand the section (twice: all sections)", :none},
    {:toggle_empty, "Empty sections", "Show or hide empty sections", :none},
    {:go_to, "Go to", "Highlight a section chosen from a list", :none},
    {:search, "Search", "Search the view", :none},
    {:browse, "Browse", "Browse the view's dates", :none},
    {:calendar, "Calendar", "Show the calendar", :none},
    {:alarm, "Alarm", "Set an alarm on the item", :none},
    {:execute_all, "Execute all", "Run every condition and action on all items", :none},
    {:execute_category, "Execute", "Run the section category's conditions and actions", :none},
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

  @commands %{
    view:
      for {id, name, summary, count} <- @view do
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
