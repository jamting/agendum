defmodule Agendum.TUI.Update.Marked do
  @moduledoc """
  Marked items (User's Guide 13-1 to 13-4): F7 and ALT-J, the box asking
  whether a command acts on the marked items or the current one, the bulk
  commands, and moving items between sections (ALT-F10, R26). Pure.
  """

  alias Agendum.Core
  alias Agendum.TUI.{CategoryScreens, Terminal.Draw, Layout, State}
  alias Agendum.TUI.Update.{Actions, Prompts, ViewKeys}

  # --- marked items (User's Guide 13-1 to 13-4) ----------------------------------

  @doc """
  F7 on an item marks or unmarks it; on a section head it marks every item
  in the section, or unmarks them when all are marked already.
  """
  def mark(state, %{kind: :item} = row), do: ViewKeys.on_item(state, row, &Core.toggle_mark/2)

  def mark(state, %{kind: :section, sidx: sidx}) do
    ids = for %{kind: :item, sidx: ^sidx, item: item} <- Layout.rows(state), do: item.id
    all_marked = ids != [] and Enum.all?(ids, &state.db.items[&1].marked)
    State.change_db(state, Core.set_marked(state.db, ids, not all_marked))
  end

  def mark(state, nil), do: state

  @doc "ALT-J: the next marked item in the view, wrapping around."
  def jump_to_marked(state, rows) do
    indexed = Enum.with_index(rows)
    {after_, before} = Enum.split_with(indexed, fn {_, i} -> i > state.cursor end)

    case Enum.find(after_ ++ before, fn {r, _} -> r.kind == :item and r.item.marked end) do
      nil -> State.error(state, "No marked items in this view")
      {_, index} -> Layout.move_to(state, index)
    end
  end

  @doc "Whether DEL and F3 act on the marked items rather than the highlighted one."
  def bulk?(state, row),
    do: row != nil and row.kind == :item and state.col == 0 and Core.marked_items(state.db) != []

  @doc """
  A command that can act on the marked items or the current item. With
  marked items Agenda asks which (User's Guide 13-2); with none, or when
  the highlight is not on an item, there is nothing to ask.
  """
  def scoped(state, action, row) do
    marked = Core.marked_items(state.db)
    on_item = row != nil and row.kind == :item

    cond do
      marked == [] or (on_item and state.col > 0 and action in [:done, :when, :make_assign]) ->
        single(state, action, row)

      not on_item and action in [:discard, :move_item, :copy_item, :remove, :profile] ->
        single(state, action, row)

      not on_item ->
        bulk(state, action, marked, row)

      true ->
        State.push(state, %{type: :scope, action: action, marked: marked, row: row, cursor: 0})
    end
  end

  @doc "A key in the box asking whether a command acts on the marked items or the current one."
  def scope_key(state, mode, key) do
    case key do
      k when k in [{:char, "m"}, {:char, "M"}] ->
        state |> State.pop() |> bulk(mode.action, mode.marked, mode.row)

      k when k in [{:char, "c"}, {:char, "C"}] ->
        state |> State.pop() |> single(mode.action, mode.row)

      :enter when mode.cursor == 0 ->
        state |> State.pop() |> bulk(mode.action, mode.marked, mode.row)

      :enter ->
        state |> State.pop() |> single(mode.action, mode.row)

      k when k in [:up, :down] ->
        State.put_mode(state, %{mode | cursor: 1 - mode.cursor})

      :esc ->
        State.pop(state)

      _ ->
        state
    end
  end

  # The command for the highlighted item (what it did before marks existed).
  defp single(state, :done, row), do: ViewKeys.toggle_done(state, row)
  defp single(state, :remove, row), do: ViewKeys.delete(state, row)
  defp single(state, :profile, row), do: ViewKeys.choices(state, row)

  defp single(state, :make_assign, %{kind: :item, item: item}),
    do: CategoryScreens.open_picker(state, {:assign_items, [item.id]}, nil)

  defp single(state, :make_assign, _row), do: State.error(state, "Highlight an item first")
  defp single(state, action, _row), do: Actions.perform(state, action)

  # The command for every marked item.
  defp bulk(state, :done, ids, _row) do
    db = Enum.reduce(ids, state.db, &Core.mark_done(&2, &1, state.today))
    state |> State.change_db(db) |> State.info("#{Draw.count(length(ids), "marked item")} done")
  end

  defp bulk(state, :discard, ids, _row),
    do:
      Prompts.confirm(
        state,
        "Discard #{Draw.count(length(ids), "marked item")} from the whole file?",
        {:discard_items, ids}
      )

  defp bulk(state, :remove, ids, %{category: cat}) do
    if cat.id == state.db.main_id do
      State.error(state, "Items cannot be removed from MAIN; use ALT-F4 to discard")
    else
      db =
        Enum.reduce(
          ids,
          state.db,
          &Core.remove_from_category(&2, &1, cat.id, State.context(state))
        )

      state
      |> State.change_db(db)
      |> State.info("Removed #{Draw.count(length(ids), "marked item")} from #{cat.name}")
    end
  end

  defp bulk(state, :when, ids, _row),
    do:
      Prompts.prompt(
        state,
        "When date for #{Draw.count(length(ids), "marked item")}:",
        {:when_items, ids}
      )

  defp bulk(state, :move_item, ids, _row) do
    # each item leaves the first section of this view that holds it
    rows = Layout.rows(state)

    froms =
      for id <- ids,
          do:
            {id,
             Enum.find_value(rows, fn r ->
               r.kind == :item and r.item.id == id and r.category.id
             end)}

    start_move(state, froms)
  end

  defp bulk(state, :copy_item, ids, _row), do: Agendum.TUI.Boxes.CopyBox.open(state, ids)

  defp bulk(state, :make_assign, ids, _row),
    do: CategoryScreens.open_picker(state, {:assign_items, ids}, nil)

  defp bulk(state, :profile, ids, _row), do: CategoryScreens.open_group_profile(state, ids)

  @doc "Starts moving items (`{id, from_category}`) to a position the person highlights."
  def start_move(state, moves) do
    what =
      if length(moves) == 1,
        do: "Move to where?",
        else: "Move #{Draw.count(length(moves), "marked item")} to where?"

    state
    |> State.push(%{type: :move_item, moves: moves})
    |> State.info(what <> " Highlight the new position and press ENTER (ESC cancels)")
  end

  # --- moving an item between sections (ALT-F10) --------------------------------

  @doc "A key while moving items: the highlight moves, ENTER drops them, ESC cancels."
  def move_key(state, mode, key) do
    case key do
      :esc ->
        State.pop(state)

      :enter ->
        state |> State.pop() |> drop_item(mode, Layout.current_row(state))

      k when k in [:up, :down, :pgup, :pgdn, :home, :end, :ctrl_pgup, :ctrl_pgdn] ->
        ViewKeys.view_key(state, k)

      _ ->
        state
    end
  end

  # Moves the item(s) to the highlighted position, one after another so
  # marked items keep their order.
  defp drop_item(state, _move, %{slot: %{}}),
    do: State.error(state, "In a datebook view, change the item's date instead")

  defp drop_item(state, %{moves: moves}, row) do
    to = Enum.at(State.view(state).sections, row.sidx).category_id
    first_after = if row.kind == :item, do: row.item.id

    {db, _} =
      Enum.reduce(moves, {state.db, first_after}, fn {id, from}, {db, after_id} ->
        from = from || db.main_id
        {Core.move_item(db, id, from, to, after: after_id, clock: State.context(state)), id}
      end)

    {last_id, _} = List.last(moves)
    %{State.change_db(state, db) | cursor_key: {:item, row.sidx, last_id}}
  end
end
