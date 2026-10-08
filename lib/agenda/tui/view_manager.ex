defmodule Agenda.TUI.ViewManager do
  @moduledoc "The view manager (F8): switch between, add, rename and discard views."

  alias Agenda.Core
  alias Agenda.TUI.{LineEdit, State, Update}

  def open(state) do
    index = Enum.find_index(state.db.view_order, &(&1 == state.view_id)) || 0
    State.push(state, %{type: :viewmgr, cursor: index})
  end

  def handle(%State{edit: edit} = state, _mode, key) when edit != nil do
    case key do
      :esc ->
        %{state | edit: nil}

      :enter ->
        name = String.trim(edit.line.text)
        state = %{state | edit: nil}

        if name == "",
          do: state,
          else: State.change_db(state, Core.rename_view(state.db, edit.target, name))

      _ ->
        case LineEdit.handle(edit.line, key) do
          {:ok, line} -> %{state | edit: %{edit | line: line}}
          :unhandled -> state
        end
    end
  end

  def handle(state, mode, key) do
    order = state.db.view_order
    count = length(order)
    view_id = Enum.at(order, mode.cursor)

    case key do
      k when k in [:esc, {:f, 8}] ->
        State.pop(state)

      :up ->
        State.put_mode(state, %{mode | cursor: max(mode.cursor - 1, 0)})

      :down ->
        State.put_mode(state, %{mode | cursor: min(mode.cursor + 1, count - 1)})

      :home ->
        State.put_mode(state, %{mode | cursor: 0})

      :end ->
        State.put_mode(state, %{mode | cursor: count - 1})

      :enter ->
        %{State.pop(state) | view_id: view_id, cursor: 0, cursor_key: nil, col: 0, scroll: 0}

      :insert ->
        Update.prompt(state, "Name of new view:", :add_view)

      {:f, 2} ->
        %{state | edit: %{target: view_id, line: LineEdit.new(state.db.views[view_id].name)}}

      {:alt, :up} ->
        reorder(state, mode, -1)

      {:alt, :down} ->
        reorder(state, mode, 1)

      k when k in [:delete, {:alt_f, 4}, {:ctrl, "d"}] ->
        Update.confirm(
          state,
          "Discard view #{state.db.views[view_id].name}? Items are kept. (Y/N)",
          {:discard_view, view_id}
        )

      _ ->
        state
    end
  end

  defp reorder(state, mode, delta) do
    order = state.db.view_order
    target = mode.cursor + delta

    if target < 0 or target >= length(order) do
      state
    else
      {id, rest} = List.pop_at(order, mode.cursor)
      db = %{state.db | view_order: List.insert_at(rest, target, id)}
      state |> State.change_db(db) |> State.put_mode(%{mode | cursor: target})
    end
  end
end
