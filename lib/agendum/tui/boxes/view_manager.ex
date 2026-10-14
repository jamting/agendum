defmodule Agendum.TUI.Boxes.ViewManager do
  @moduledoc """
  The view manager (F8): switch between, add, rename and discard views. A
  box over the view, as Agenda's (screenshot 40;
  `Agendum.TUI.Render.Managers.view_box/4`).

  Typing highlights a view (R53; User's Guide 9-5, Starter Applications
  1-10): the first letter the next view starting with it, round the list;
  more letters narrow it down; BACKSPACE takes one back. A letter that
  fits no view starts again from it, so the same letter again goes on to
  the next view with it. Moving forgets what was typed.
  """

  alias Agendum.Core
  alias Agendum.TUI.{Typing.LineEdit, State}
  alias Agendum.TUI.Update.Prompts

  def open(state) do
    index = Enum.find_index(state.db.view_order, &(&1 == state.view_id)) || 0
    State.push(state, %{type: :viewmgr, cursor: index, typed: "", from: index})
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

  def handle(state, mode, {:char, c}), do: find(state, mode, mode.typed <> c, c)

  def handle(state, %{typed: typed} = mode, :backspace) when typed != "",
    do: find(state, mode, String.slice(typed, 0..-2//1), nil)

  def handle(state, mode, key) do
    order = state.db.view_order
    count = length(order)
    # undo can remove views while the manager is open; any other key
    # forgets what was typed
    mode = %{mode | cursor: min(mode.cursor, count - 1), typed: ""}
    state = State.put_mode(state, mode)
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
        state |> State.pop() |> State.switch_view(view_id)

      :insert ->
        Prompts.prompt(state, "Name of new view:", :add_view)

      {:f, 2} ->
        %{state | edit: %{target: view_id, line: LineEdit.new(state.db.views[view_id].name)}}

      {:alt_f, 5} ->
        state |> State.change_db(Core.sort_views(state.db)) |> State.put_mode(%{mode | cursor: 0})

      {:alt, :up} ->
        reorder(state, mode, -1)

      {:alt, :down} ->
        reorder(state, mode, 1)

      # F4 (DELETE) is Agenda's key here; DEL and ALT-F4 as everywhere
      k when k in [:delete, {:f, 4}, {:alt_f, 4}, {:ctrl, "d"}] ->
        Prompts.confirm(
          state,
          "Discard view #{state.db.views[view_id].name}? Items are kept.",
          {:discard_view, view_id}
        )

      _ ->
        state
    end
  end

  # highlights the first view after `from` whose name starts with `typed`;
  # failing that, starts again from the letter just typed
  defp find(state, mode, typed, letter) do
    from = if mode.typed == "", do: mode.cursor, else: mode.from

    case {typed, match(state, from, typed), letter && match(state, mode.cursor, letter)} do
      {"", _, _} ->
        State.put_mode(state, %{mode | typed: "", cursor: from})

      {_, i, _} when i != nil ->
        State.put_mode(state, %{mode | typed: typed, from: from, cursor: i})

      {_, nil, i} when i != nil ->
        State.put_mode(state, %{mode | typed: letter, from: mode.cursor, cursor: i})

      _ ->
        state
    end
  end

  defp match(state, from, typed) do
    order = state.db.view_order
    count = length(order)
    typed = String.downcase(typed)

    Enum.find(Enum.map(1..count//1, &rem(from + &1, count)), fn i ->
      state.db.views[Enum.at(order, i)].name |> String.downcase() |> String.starts_with?(typed)
    end)
  end

  defp reorder(state, mode, delta) do
    order = state.db.view_order
    target = mode.cursor + delta

    if target < 0 or target >= length(order) do
      state
    else
      db = Core.move_view(state.db, Enum.at(order, mode.cursor), target)
      state |> State.change_db(db) |> State.put_mode(%{mode | cursor: target})
    end
  end
end
