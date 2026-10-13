defmodule Agenda.TUI.CopyBox do
  @moduledoc """
  ALT-F9 COPY (R42; User's Guide 13-8 to 13-9): the Copy box lists the
  view's sections, the current one highlighted; ↑ ↓ choose one and ENTER
  puts the item, or the marked items, in it as well: they are assigned to
  its head category and keep their other sections (one undo step). It is
  the same item, not a duplicate, so an edit shows everywhere. A section
  whose head is mutually exclusive with the one the item is in takes it
  away from there, as any assignment does (R15). ESC copies nothing.

  Our choice: Agenda put the copy at the bottom of the section; the items
  of a file have one order (an item's place is the same in every
  section), so it shows in its usual place. Not in a datebook view, whose
  sections are its dates (R47). Pure.
  """

  alias Agenda.Core
  alias Agenda.TUI.{Draw, Layout, State}

  @doc "Opens the box for the items `ids`."
  def open(state, ids) do
    if State.view(state).datebook do
      State.error(state, "In a datebook view, give the item another date instead")
    else
      current = (Layout.current_row(state) || %{sidx: 0}).sidx
      State.push(state, %{type: :copy_items, ids: ids, cursor: current})
    end
  end

  def handle(state, mode, key) do
    last = length(State.view(state).sections) - 1

    case key do
      :esc -> State.pop(state)
      :up -> State.put_mode(state, %{mode | cursor: max(mode.cursor - 1, 0)})
      :down -> State.put_mode(state, %{mode | cursor: min(mode.cursor + 1, last)})
      :enter -> state |> State.pop() |> copy(mode)
      _ -> state
    end
  end

  defp copy(state, mode) do
    cat_id = Enum.at(State.view(state).sections, mode.cursor).category_id
    db = Enum.reduce(mode.ids, state.db, &Core.assign(&2, &1, cat_id, State.context(state)))
    name = state.db.categories[cat_id].name

    what =
      if length(mode.ids) == 1, do: "", else: Draw.count(length(mode.ids), "marked item") <> " "

    state |> State.change_db(db) |> State.info("Copied #{what}to #{name}")
  end

  @doc "The box's lines: the question, then the sections, the chosen one selected."
  def lines(state, mode) do
    sections =
      state
      |> State.view()
      |> Map.fetch!(:sections)
      |> Enum.with_index()
      |> Enum.map(fn {section, i} ->
        style = if i == mode.cursor, do: :box_selected, else: :box
        [{:box, "   "}, {style, state.db.categories[section.category_id].name}]
      end)

    [[{:box, " Copy to which section?"}], []] ++ sections
  end
end
