defmodule Agenda.TUI.ColumnMove do
  @moduledoc """
  View ▸ Column ▸ Move, or ALT-F10 on a column head (User's Guide 5-20):
  moving the highlighted column within its section.

    * ← / → (or < / >) move it one place left / right
    * ENTER keeps the new place: one undo step
    * ESC puts it back

  Only the current section changes, even for a column linked into other
  sections, as in Agenda; it stays linked. While it moves the file is not
  changed: the mode holds the place, and the view is shown with the column
  there (`State.view/1` asks `view/2`, as for browsing). The highlight
  goes with the column. Pure.
  """

  alias Agenda.Core
  alias Agenda.Core.View
  alias Agenda.TUI.State

  @doc "Starts moving the column at `at` (`{section, column}`)."
  def open(state, {_sidx, index} = at),
    do: State.push(state, %{type: :column_move, view_id: state.view_id, at: at, to: index})

  @doc "A view as shown while one of its columns moves: with it in its new place."
  def view(%State{modes: modes} = state, view) do
    case Enum.find(modes, &match?(%{type: :column_move, view_id: id} when id == view.id, &1)) do
      nil -> view
      mode -> moved(state, mode).views[view.id]
    end
  end

  # the file as it would be with the column moved; kept only on ENTER
  defp moved(state, mode), do: Core.move_column(state.db, mode.view_id, mode.at, mode.to)

  def handle(state, mode, key) do
    {_sidx, index} = mode.at

    case key do
      k when k in [:left, {:char, "<"}] -> step(state, mode, -1)
      k when k in [:right, {:char, ">"}] -> step(state, mode, 1)
      :enter -> State.change_db(State.pop(state), moved(state, mode))
      # the highlight goes back with the column (the cursor counts from 1)
      :esc -> %{State.pop(state) | col: index + 1}
      _ -> state
    end
  end

  # one place along, within the section's columns
  defp step(state, mode, n) do
    {sidx, _index} = mode.at
    last = length(View.columns(state.db.views[mode.view_id], sidx)) - 1
    to = (mode.to + n) |> max(0) |> min(last)
    %{State.put_mode(state, %{mode | to: to}) | col: to + 1}
  end

  @doc "The control panel's line while a column moves (the key bar has the keys)."
  def panel(state, mode) do
    {sidx, index} = mode.at
    column = state.db.views[mode.view_id] |> View.columns(sidx) |> Enum.at(index)
    "Moving column #{state.db.categories[column.category_id].name}  (← → or < >, ENTER here)"
  end
end
