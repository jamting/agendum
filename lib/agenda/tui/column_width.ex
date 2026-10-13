defmodule Agenda.TUI.ColumnWidth do
  @moduledoc """
  View ▸ Column ▸ Width (User's Guide 5-21 to 5-22): choosing the
  highlighted column's width. The control panel shows it, and

    * ← / → make it one narrower / wider
    * typing a number replaces it (BACKSPACE takes a digit back)
    * SHIFT-? fits the column to its head and entries (R22a)
    * ENTER keeps the width: one undo step
    * ESC goes back to the old width

  While the width is chosen the file is not changed: the mode holds the
  width, and the view is shown with it (`State.view/1` asks `view/2`, as
  for browsing), so the column changes on the screen at once. A linked
  column changes in every section it is in (R55). Pure.
  """

  alias Agenda.Core
  alias Agenda.Core.View
  alias Agenda.TUI.State

  @doc "Starts choosing the width of the column at `at` (`{section, column}`)."
  def open(state, at) do
    column = state |> State.view() |> View.columns(elem(at, 0)) |> Enum.at(elem(at, 1))

    State.push(state, %{
      type: :column_width,
      view_id: state.view_id,
      at: at,
      width: column.width,
      typed: ""
    })
  end

  @doc "A view as shown while its column's width is chosen: with that width."
  def view(%State{modes: modes} = state, view) do
    case Enum.find(modes, &match?(%{type: :column_width, view_id: id} when id == view.id, &1)) do
      nil -> view
      mode -> chosen(state, mode).views[view.id]
    end
  end

  # the file as it would be with the width chosen; only shown, never kept
  # until ENTER
  defp chosen(state, mode),
    do: Core.set_column_width(state.db, mode.view_id, mode.at, mode.width)

  def handle(state, mode, key) do
    case key do
      :left -> put_width(state, mode, mode.width - 1)
      :right -> put_width(state, mode, mode.width + 1)
      {:char, "?"} -> put_width(state, mode, fitted(state, mode))
      {:char, d} when d in ~w(0 1 2 3 4 5 6 7 8 9) -> type(state, mode, mode.typed <> d)
      :backspace -> type(state, mode, String.slice(mode.typed, 0..-2//1))
      :enter -> State.change_db(State.pop(state), chosen(state, mode))
      :esc -> State.pop(state)
      _ -> state
    end
  end

  # the width as the core would keep it (at least 3, at most 80), so what
  # the control panel says is what ENTER keeps
  defp put_width(state, mode, width) do
    kept = chosen(state, %{mode | width: width}).views[mode.view_id]
    {sidx, index} = mode.at
    width = kept |> View.columns(sidx) |> Enum.at(index) |> Map.fetch!(:width)
    State.put_mode(state, %{mode | width: width, typed: ""})
  end

  # typing builds a number; the column follows each digit
  defp type(state, mode, ""), do: State.put_mode(state, %{mode | typed: ""})

  defp type(state, mode, typed),
    do: state |> put_width(mode, String.to_integer(typed)) |> keep_typed(typed)

  defp keep_typed(state, typed), do: State.put_mode(state, %{State.mode(state) | typed: typed})

  # R22a's width: the core fits the column, and the width is read back
  defp fitted(state, mode) do
    {sidx, index} = mode.at
    db = Core.fit_column(state.db, mode.view_id, mode.at, State.context(state))
    db.views[mode.view_id] |> View.columns(sidx) |> Enum.at(index) |> Map.fetch!(:width)
  end

  @doc "The control panel's line while the width is chosen (the key bar has the keys)."
  def panel(mode), do: "Column width: #{mode.width}  (← →, type a number, or ? to fit)"
end
