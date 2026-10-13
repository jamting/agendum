defmodule Agenda.TUI.Menu do
  @moduledoc """
  The Lotus-style two-line menu (F10 or `/`).

  The first line lists the commands at the current level; the second line
  shows the highlighted command's subcommands or a description. Select a
  command with the arrow keys and ENTER, or by typing its first letter.
  ESC backs up one level.
  """

  alias Agenda.TUI.State
  alias Agenda.TUI.Update.Actions

  @doc "The menu tree: `{label, description, children_or_action}`."
  def tree do
    [
      {"File", "Retrieve, save or create files",
       [
         {"Retrieve", "Open an existing Agendum file (CTRL-O)", :retrieve},
         {"Save", "Save the current file (CTRL-S)", :save},
         {"Write", "Write the file under a new name (Save As)", :save_as},
         {"New", "Create a new, empty file", :new_file},
         {"Dating", "Turn When dates read from text on or off", :toggle_auto_date},
         {"Properties", "How the file displays dates and times", :file_props},
         {"Customize", "Your theme, date languages and input format, for every file", :customize},
         {"Transfer", "Export the whole file as JSON, or import one",
          [
            {"Export", "Write the whole file as a JSON file", :export_json},
            {"Import", "Open a JSON file as a new, untitled file", :import_json},
            {"Calendars", "Subscribe to calendars on the web (iCal); read them now", :calendars}
          ]}
       ]},
      {"Item", "Work with the highlighted item",
       [
         {"Properties", "Text, note and every assignment of the item (F6)", :item_props},
         {"Note", "Edit the item's note (F5)", :note},
         {"When", "Set the item's When date; overrides dates in the text (ALT-F2)", :when},
         {"Show", "Show the item's assignment profile (F3)", :assign},
         {"Alarm", "Set or cancel an alarm before the When time (ALT-A)", :alarm},
         {"Finished", "Mark the item done / not done (F4)", :done},
         {"Mark", "Mark or unmark the item; on a section head, all its items (F7)", :mark},
         {"Unmark", "Unmark all marked items in the file (ALT-F7)", :unmark_all},
         {"Categorize", "Assign the item, or all marked items, to a category (ALT-M)",
          :make_assign},
         {"Reposition", "Move the item to another section or position (ALT-F10)", :move_item},
         {"Discard", "Delete the item from the file (ALT-F4)", :discard}
       ]},
      {"Category", "Work with categories",
       [
         {"Manager", "Open the category manager (F9)", :category_manager},
         {"Add", "Add a category under MAIN", :add_category},
         {"Recalc", "Re-run automatic assignment for every item", :recalc},
         {"Execute", "Apply conditions and actions to existing items (ALT-X all, ALT-E one)",
          :execute},
         {"Questions", "Confirm suggested assignments (Utilities Questions)", :questions}
       ]},
      {"View", "Change the current view or create new ones",
       [
         {"Manager", "Switch, add, rename or discard views (F8)", :view_manager},
         {"Add", "Create a new view", :add_view},
         {"Rename", "Rename the current view", :rename_view},
         {"Discard", "Delete the current view (items are kept)", :discard_view},
         {"Properties", "A datebook view's settings: period, base date, categories", :view_props},
         {"Browse", "Move a datebook view or a date filter to other dates (ALT-B)", :browse},
         {"Section", "Add, remove or collapse sections",
          [
            {"Below", "Add a section below the current one (ALT-D)", :section_below},
            {"Above", "Add a section above the current one (ALT-U)", :section_above},
            {"Remove", "Remove the current section from the view (DEL on head)", :remove_section},
            {"Collapse", "Collapse or expand the current section", :collapse_section},
            {"Filter", "Show only items in (or not in) chosen categories, in this section",
             :filter_section},
            {"Sort", "How this section's items are ordered", :sort_section}
          ]},
         {"Column", "Add, remove or resize columns",
          [
            {"After", "Add a column after (right of) the current one (ALT-R)", :column_right},
            {"Before", "Add a column before (left of) the current one (ALT-L)", :column_left},
            {"Remove", "Remove the highlighted column", :remove_column},
            {"Wider", "Make the highlighted column wider", :wider},
            {"Narrower", "Make the highlighted column narrower", :narrower},
            {"Fit", "Fit the highlighted column to its head and entries, once", :fit_column},
            {"Properties",
             "The column's width, link with other sections, and how it shows values",
             :column_props}
          ]},
         {"Filter", "Show only items in (or not in) chosen categories", :filter_view},
         {"Order", "Sort the items in every section (the view's sort settings)", :sort_view},
         {"Last", "Return to the view shown before this one (ALT-F8)", :last_view},
         {"Hide", "Choose which items the view hides",
          [
            {"Done", "Hide or show done items", {:toggle_view, :hide_done}},
            {"Empty", "Hide or show empty sections", {:toggle_view, :hide_empty}},
            {"Inherited", "Hide or show items only in subcategories",
             {:toggle_view, :hide_inherited}},
            {"Pending", "Hide or show items waiting for others to be done (ALT-O)",
             {:toggle_view, :hide_dependent}}
          ]}
       ]},
      {"Search", "Find items by their text",
       [
         {"View", "Search this view: ALT-N next, ALT-P previous, F7 mark (ALT-F6)", :search_view},
         {"File", "Show every matching item in the file in the Show View", :search_file},
         {"Alarms", "Current alarms and today's past alarms", :alarm_list},
         {"Schedule", "One date's items in the Show View (Utilities Show Sched)", :show_schedule},
         {"Depends", "Show the items that depend on this one (Utilities Show Depends)",
          [
            {"One level", "Items directly depending on this one",
             {:show_related, :dependents, :one}},
            {"All levels", "The whole chain of items depending on this one",
             {:show_related, :dependents, :all}},
            {"Every item", "Every item in the file that others depend on",
             {:show_related, :dependents, :every}}
          ]},
         {"Prereqs", "Show the items this one depends on (Utilities Show Prereqs)",
          [
            {"One level", "Items directly this one depends on",
             {:show_related, :prerequisites, :one}},
            {"All levels", "The whole chain of items this one depends on",
             {:show_related, :prerequisites, :all}},
            {"Every item", "Every item in the file that depends on others",
             {:show_related, :prerequisites, :every}}
          ]}
       ]},
      {"Undo", "Undo the last change (CTRL-Z)", :undo},
      {"Redo", "Redo the last undone change (CTRL-Y)", :redo},
      {"Print", "Print the current view to a text file (CTRL-P)", :export},
      {"Quit", "Leave Agendum (CTRL-Q)", :quit}
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
        state |> State.pop() |> Actions.perform(action)
    end
  end
end
