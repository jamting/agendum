# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Moves.ColumnWidth do
  @moduledoc """
  View ▸ Column ▸ Width (User's Guide 5-21 to 5-22): choosing the
  highlighted column's width, or, on the item text, the width of the
  section's item column (R55). The control panel shows it, and

    * ← / → make it one narrower / wider
    * typing a number replaces it (BACKSPACE takes a digit back)
    * SHIFT-? fits it: a column to its head and entries (R22a), the item
      column to its longest item text, within what the columns leave
    * ENTER keeps the width: one undo step
    * ESC goes back to the old width

  A width chosen for the item column sets it by hand (Set width:
  Manually), as Agenda's Width did. While the width is chosen the file is
  not changed: the mode holds the width, and the view is shown with it
  (`State.view/1` asks `view/2`, as for browsing), so the column changes
  on the screen at once. A linked column, or a linked item column, changes
  in every section it is in. Pure.
  """

  alias Agendum.Core
  alias Agendum.Core.View
  alias Agendum.Core.View.ItemColumn
  alias Agendum.TUI.{Keymap, State}

  @doc """
  Starts choosing a width: of the column at `{section, column}`
  (`{:column, at}`), or of section `sidx`'s item column (`{:items, sidx}`).
  """
  def open(state, target) do
    State.push(state, %Agendum.TUI.Modes.ColumnWidth{
      view_id: state.view_id,
      target: target,
      width: width_now(state, target),
      typed: ""
    })
  end

  # A column's width; the item column's is the width its text has now,
  # by hand or as the columns leave it.
  defp width_now(state, {:column, {sidx, index}}),
    do: state |> State.view() |> View.columns(sidx) |> Enum.at(index) |> Map.fetch!(:width)

  defp width_now(state, {:items, sidx}) do
    section = Enum.at(State.view(state).sections, sidx)
    ItemColumn.text_width(section.item_column, section.columns, state.width)
  end

  @doc "A view as shown while a width is chosen: with that width."
  def view(%State{modes: modes} = state, view) do
    case Enum.find(modes, &match?(%{type: :column_width, view_id: id} when id == view.id, &1)) do
      nil -> view
      mode -> chosen(state, mode).views[view.id]
    end
  end

  # the file as it would be with the width chosen; only shown, never kept
  # until ENTER
  defp chosen(state, mode), do: State.preview(state, width_command(mode))

  defp width_command(%{target: {:column, at}} = mode),
    do: {:set_column_width, mode.view_id, at, mode.width}

  defp width_command(%{target: {:items, sidx}} = mode),
    do: {:set_item_column, mode.view_id, sidx, set: :manual, width: mode.width}

  @doc """
  A key while a column's width changes: the command its keymap binds it to
  (R65); digits type a width, BACKSPACE takes one back.
  """
  def handle(state, mode, {:char, d}) when d in ~w(0 1 2 3 4 5 6 7 8 9),
    do: type(state, mode, mode.typed <> d)

  def handle(state, mode, :backspace), do: type(state, mode, String.slice(mode.typed, 0..-2//1))

  def handle(state, mode, key) do
    case Keymap.lookup(:column_width, key) do
      nil -> state
      id -> command(state, mode, id)
    end
  end

  @doc "F1's text while changing a column's width (R65)."
  @spec about() :: String.t()
  def about do
    """
    You are changing a column's width. ← makes it narrower, → wider; type a
    width, or ? to fit it to what it shows.

    ENTER keeps the width; ESC keeps the one it had.
    """
  end

  @doc "Runs a command of changing a column's width (`Agendum.TUI.Commands`)."
  @spec run(State.t(), atom) :: State.t()
  def run(state, id), do: command(state, State.mode(state), id)

  defp command(state, mode, :narrower), do: put_width(state, mode, mode.width - 1)
  defp command(state, mode, :wider), do: put_width(state, mode, mode.width + 1)
  defp command(state, mode, :fit), do: put_width(state, mode, fitted(state, mode))
  defp command(state, mode, :keep), do: State.run(State.pop(state), width_command(mode))
  defp command(state, _mode, :close), do: State.pop(state)
  defp command(state, _mode, :help), do: Agendum.TUI.HelpScreen.open(state)

  # the width as the core would keep it (a column 1 to 80, the item column
  # 5 to 200), so what the control panel says is what ENTER keeps
  defp put_width(state, mode, width) do
    view = chosen(state, %{mode | width: width}).views[mode.view_id]
    State.put_mode(state, %{mode | width: kept(view, mode.target), typed: ""})
  end

  defp kept(view, {:column, {sidx, index}}),
    do: view |> View.columns(sidx) |> Enum.at(index) |> Map.fetch!(:width)

  defp kept(view, {:items, sidx}), do: Enum.at(view.sections, sidx).item_column.width

  # typing builds a number; the column follows each digit
  defp type(state, mode, ""), do: State.put_mode(state, %{mode | typed: ""})

  defp type(state, mode, typed),
    do: state |> put_width(mode, String.to_integer(typed)) |> keep_typed(typed)

  defp keep_typed(state, typed), do: State.put_mode(state, %{State.mode(state) | typed: typed})

  # R22a's width: the core fits the column, and the width is read back
  defp fitted(state, %{target: {:column, at}} = mode) do
    db = State.preview(state, {:fit_column, mode.view_id, at})
    kept(db.views[mode.view_id], mode.target)
  end

  defp fitted(state, %{target: {:items, sidx}} = mode),
    do: Core.item_column_fit(state.db, mode.view_id, sidx, State.context(state), state.width)

  @doc "The control panel's line while the width is chosen (the key bar has the keys)."
  def panel(%{target: {:items, _}} = mode),
    do: "Item column width: #{mode.width}  (← →, type a number, or ? to fit)"

  def panel(mode), do: "Column width: #{mode.width}  (← →, type a number, or ? to fit)"
end
