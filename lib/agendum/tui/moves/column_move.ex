# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Moves.ColumnMove do
  @moduledoc """
  View ▸ Column ▸ Move, or ALT-F10 on a column head (User's Guide 5-20):
  moving the highlighted column within its section, or, from the item
  text, the item column among the columns (R55).

    * ← / → (or < / >) move it one place left / right
    * ENTER keeps the new place: one undo step
    * ESC puts it back

  Only the current section changes, even for a column linked into other
  sections, as in Agenda; it stays linked. The places are the section's
  slots (`Agendum.Core.ViewColumns.slots/2`): its columns and its item
  column in the order they are shown. While it moves the file is not
  changed: the mode holds the place, and the view is shown with it there
  (`State.view/1` asks `view/2`, as for browsing). The highlight goes with
  it. Pure.
  """

  alias Agendum.Core.{View, ViewColumns}
  alias Agendum.TUI.{Keymap, State}

  @doc """
  Starts moving, in section `sidx`, the column with that index or the item
  column (`:items`).
  """
  def open(state, sidx, what) do
    from = state |> State.view() |> ViewColumns.slots(sidx) |> Enum.find_index(&(&1 == what))

    State.push(state, %Agendum.TUI.Modes.ColumnMove{
      view_id: state.view_id,
      sidx: sidx,
      what: what,
      from: from,
      to: from,
      col: state.col
    })
  end

  @doc "A view as shown while a column moves: with it in its new place."
  def view(%State{modes: modes} = state, view) do
    case Enum.find(modes, &match?(%{type: :column_move, view_id: id} when id == view.id, &1)) do
      nil -> view
      mode -> moved(state, mode).views[view.id]
    end
  end

  # the file as it would be with the column moved; kept only on ENTER
  defp moved(state, mode), do: State.preview(state, move(mode))

  defp move(mode), do: {:move_column, mode.view_id, mode.sidx, mode.from, mode.to}

  @doc "A key while a column moves: the command its keymap binds it to (R65)."
  def handle(state, mode, key) do
    case Keymap.lookup(:column_move, key) do
      nil -> state
      id -> command(state, mode, id)
    end
  end

  @doc "F1's text while moving a column (R65)."
  @spec about() :: String.t()
  def about do
    """
    You are moving a column. ← and → (or < and >) move it along the
    section.

    ENTER keeps it there; ESC puts it back.
    """
  end

  @doc "Runs a command of moving a column (`Agendum.TUI.Commands`)."
  @spec run(State.t(), atom) :: State.t()
  def run(state, id), do: command(state, State.mode(state), id)

  defp command(state, mode, :left), do: step(state, mode, -1)
  defp command(state, mode, :right), do: step(state, mode, 1)
  defp command(state, mode, :keep), do: State.run(State.pop(state), move(mode))
  # the highlight goes back with it
  defp command(state, mode, :close), do: %{State.pop(state) | col: mode.col}
  defp command(state, _mode, :help), do: Agendum.TUI.HelpScreen.open(state)

  # One place along, within the section's slots. The highlight follows:
  # 0 on the item column, the column's index + 1 on a column (as
  # `state.col` counts), read from where it is now shown.
  defp step(state, mode, n) do
    last = length(ViewColumns.slots(state.db.views[mode.view_id], mode.sidx)) - 1
    mode = %{mode | to: (mode.to + n) |> max(0) |> min(last)}
    shown = ViewColumns.slots(moved(state, mode).views[mode.view_id], mode.sidx)

    col =
      case Enum.at(shown, mode.to) do
        :items -> 0
        index -> index + 1
      end

    %{State.put_mode(state, mode) | col: col}
  end

  @doc "The control panel's line while a column moves (the key bar has the keys)."
  def panel(_state, %{what: :items}), do: "Moving the item column  (← → or < >, ENTER here)"

  def panel(state, mode) do
    column = state.db.views[mode.view_id] |> View.columns(mode.sidx) |> Enum.at(mode.what)
    "Moving column #{state.db.categories[column.category_id].name}  (← → or < >, ENTER here)"
  end
end
