defmodule Agenda.TUI.Menu do
  @moduledoc """
  The Lotus-style two-line menu (F10 or `/`).

  The first line lists the commands at the current level; the second line
  shows the highlighted command's subcommands or a description. Select a
  command with the arrow keys and ENTER, or by typing its first letter.
  ESC backs up one level.
  """

  alias Agenda.TUI.{State, Update}

  @doc "The menu tree: `{label, description, children_or_action}`."
  def tree do
    [
      {"File", "Retrieve, save or create files",
       [
         {"Retrieve", "Open an existing Agenda file", :retrieve},
         {"Save", "Save the current file", :save},
         {"SaveAs", "Save the current file under a new name", :save_as},
         {"New", "Create a new, empty file", :new_file}
       ]},
      {"Item", "Work with the highlighted item",
       [
         {"Note", "Edit the item's note (F5)", :note},
         {"Assign", "Show the item's assignment profile (F6)", :assign},
         {"Done", "Mark the item done / not done (F4)", :done},
         {"Mark", "Mark or unmark the item (F7)", :mark},
         {"Move", "Move the item to another section (ALT-F10)", :move_item},
         {"Discard", "Delete the item from the file (ALT-F4)", :discard}
       ]},
      {"Category", "Work with categories",
       [
         {"Manager", "Open the category manager (F9)", :category_manager},
         {"Add", "Add a category under MAIN", :add_category},
         {"Recalc", "Re-run automatic assignment for every item", :recalc}
       ]},
      {"View", "Change the current view or create new ones",
       [
         {"Manager", "Switch, add, rename or discard views (F8)", :view_manager},
         {"Add", "Create a new view", :add_view},
         {"Rename", "Rename the current view", :rename_view},
         {"Discard", "Delete the current view (items are kept)", :discard_view},
         {"Section", "Add, remove or collapse sections",
          [
            {"Below", "Add a section below the current one (ALT-D)", :section_below},
            {"Above", "Add a section above the current one (ALT-U)", :section_above},
            {"Remove", "Remove the current section from the view (DEL on head)", :remove_section},
            {"Collapse", "Collapse or expand the current section", :collapse_section}
          ]},
         {"Column", "Add, remove or resize columns",
          [
            {"Right", "Add a column right of the current one (ALT-R)", :column_right},
            {"Left", "Add a column left of the current one (ALT-L)", :column_left},
            {"Remove", "Remove the highlighted column", :remove_column},
            {"Wider", "Make the highlighted column wider", :wider},
            {"Narrower", "Make the highlighted column narrower", :narrower}
          ]},
         {"Hide", "Choose which items the view hides",
          [
            {"Done", "Hide or show done items", {:toggle_view, :hide_done}},
            {"Empty", "Hide or show empty sections", {:toggle_view, :hide_empty}},
            {"Inherited", "Hide or show items only in subcategories",
             {:toggle_view, :hide_inherited}}
          ]}
       ]},
      {"Print", "Print the current view to a text file", :export},
      {"Quit", "Leave Agenda", :quit}
    ]
  end

  def open(state), do: State.push(state, %{type: :menu, path: [], selected: 0})

  @doc "The entries at the menu's current level."
  def entries(%{path: path}) do
    Enum.reduce(path, tree(), fn index, level ->
      {_, _, children} = Enum.at(level, index)
      children
    end)
  end

  def handle(state, mode, key) do
    entries = entries(mode)
    count = length(entries)

    case key do
      k when k in [:right, :tab] ->
        State.put_mode(state, %{mode | selected: rem(mode.selected + 1, count)})

      k when k in [:left, :shift_tab] ->
        State.put_mode(state, %{mode | selected: rem(mode.selected - 1 + count, count)})

      :home ->
        State.put_mode(state, %{mode | selected: 0})

      :end ->
        State.put_mode(state, %{mode | selected: count - 1})

      :enter ->
        choose(state, mode, mode.selected)

      k when k in [:esc, :backspace] ->
        back(state, mode)

      {:f, 10} ->
        State.pop(state)

      {:char, c} ->
        case Enum.find_index(entries, fn {label, _, _} ->
               String.upcase(String.first(label)) == String.upcase(c)
             end) do
          nil -> state
          index -> choose(state, mode, index)
        end

      _ ->
        state
    end
  end

  defp back(state, %{path: []}), do: State.pop(state)

  defp back(state, %{path: path} = mode) do
    State.put_mode(state, %{mode | path: Enum.drop(path, -1), selected: List.last(path)})
  end

  defp choose(state, mode, index) do
    case Enum.at(entries(mode), index) do
      {_, _, children} when is_list(children) ->
        State.put_mode(state, %{mode | path: mode.path ++ [index], selected: 0})

      {_, _, action} ->
        state |> State.pop() |> Update.perform(action)
    end
  end
end
