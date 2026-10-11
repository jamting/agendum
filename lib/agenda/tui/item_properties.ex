defmodule Agenda.TUI.ItemProperties do
  @moduledoc """
  The Item Properties box (F6 on an item; User's Guide 4-13 to 4-15): the
  item's text, note, statistics, the items it depends on ("Depends on")
  and those depending on it ("Needed by", R43), and every category it is
  assigned to.

    * ENTER / F2 on the text edits it; ENTER / SPACE on the note opens it
    * on a dependency: ENTER opens that item's properties (ESC comes
      back); DEL removes that one dependency
    * on an assignment: DEL breaks it; F4 (or ENTER) changes a date or a
      number
    * typing anywhere in the assignments assigns a category, with automatic
      completion over all categories (ENTER accepts, F8/F7 cycle, INS
      creates exactly what was typed under MAIN); a date category asks for
      its date
    * F3 opens the assignment profile; ESC or F6 closes the box

  Pure, like the rest of the TUI state machine.
  """

  alias Agenda.Core
  alias Agenda.TUI.{CategoryScreens, Completion, LineEdit, State, TextEdit, Update}

  def open(state, item_id),
    do: State.push(state, %{type: :item_props, item_id: item_id, cursor: 0})

  @doc "The rows of the box, top to bottom."
  @spec rows(State.t(), map) :: [term]
  def rows(state, mode) do
    [:text, :note, :stats] ++
      Enum.map(Core.prerequisites(state.db, mode.item_id), &{:prerequisite, &1}) ++
      Enum.map(Core.dependents(state.db, mode.item_id), &{:dependent, &1}) ++
      Enum.map(Core.item_assignments(state.db, mode.item_id), &{:assigned, &1}) ++ [:add]
  end

  # --- keys ---------------------------------------------------------------------

  def handle(%State{edit: edit} = state, mode, key) when edit != nil,
    do: edit_key(state, mode, key)

  def handle(state, mode, key) do
    rows = rows(state, mode)
    mode = %{mode | cursor: mode.cursor |> min(length(rows) - 1) |> max(0)}
    state = State.put_mode(state, mode)
    row = Enum.at(rows, mode.cursor)

    case {key, row} do
      {k, _} when k in [:esc, {:f, 6}] ->
        State.pop(state)

      {:up, _} ->
        State.put_mode(state, %{mode | cursor: max(mode.cursor - 1, 0)})

      {:down, _} ->
        State.put_mode(state, %{mode | cursor: min(mode.cursor + 1, length(rows) - 1)})

      {:home, _} ->
        State.put_mode(state, %{mode | cursor: 0})

      {:end, _} ->
        State.put_mode(state, %{mode | cursor: length(rows) - 1})

      {{:f, 3}, _} ->
        CategoryScreens.open_profile(state, mode.item_id)

      {k, :text} when k in [:enter, {:f, 2}] ->
        edit_text(state, mode)

      {k, :note} when k in [:enter, {:char, " "}] ->
        open_note(state, mode)

      {k, {kind, id}} when kind in [:prerequisite, :dependent] ->
        dependency_key(state, mode, k, kind, id)

      {k, {:assigned, %{kind: :date} = a}} when k in [:enter, {:f, 4}] ->
        ask_date(state, mode, a.category)

      {k, {:assigned, %{kind: :numeric} = a}} when k in [:enter, {:f, 4}] ->
        ask_number(state, mode, a)

      {:delete, {:assigned, a}} ->
        remove(state, mode, a)

      {k, row} when k in [:insert, :enter] and row != :text and row != :note ->
        start_assign(state, "")

      {{:char, c}, row} when row == :stats or row == :add or elem(row, 0) == :assigned ->
        start_assign(state, c)

      _ ->
        state
    end
  end

  defp dependency_key(state, _mode, :enter, _kind, id), do: open(state, id)

  defp dependency_key(state, mode, :delete, :prerequisite, id),
    do: State.change_db(state, Core.remove_dependency(state.db, mode.item_id, id))

  defp dependency_key(state, mode, :delete, :dependent, id),
    do: State.change_db(state, Core.remove_dependency(state.db, id, mode.item_id))

  defp dependency_key(state, _mode, _key, _kind, _id), do: state

  defp edit_text(state, mode) do
    %{
      state
      | edit: %{
          target: {:item_text, mode.item_id},
          line: LineEdit.new(state.db.items[mode.item_id].text)
        }
    }
  end

  defp open_note(state, mode) do
    item = state.db.items[mode.item_id]

    State.push(state, %{
      type: :note,
      target: {:item, item.id},
      title: item.text,
      edit: TextEdit.new(item.note)
    })
  end

  defp start_assign(state, text) do
    mode = State.mode(state)

    %{
      state
      | edit: %{target: {:assign_category, mode.item_id}, line: LineEdit.new(text), choice: 0}
    }
  end

  defp remove(state, mode, %{category: cat_id, kind: kind}) do
    cond do
      cat_id == state.db.special.entry ->
        State.error(state, "The Entry date cannot be removed")

      kind == :date ->
        State.change_db(
          state,
          Core.remove_from_category(state.db, mode.item_id, cat_id, State.context(state))
        )

      true ->
        State.change_db(
          state,
          Core.toggle_assignment(state.db, mode.item_id, cat_id, State.context(state))
        )
    end
  end

  # Prompts for a date for a date category (When, Done, Entry); see
  # `Update.prompt_action/3` for {:item_date, item, category}.
  defp ask_date(state, mode, cat_id) do
    db = state.db

    current =
      Agenda.Core.DateParser.format(Agenda.Core.Database.item_date(db, mode.item_id, cat_id))

    Update.prompt(
      state,
      "#{db.categories[cat_id].name} date:",
      {:item_date, mode.item_id, cat_id},
      current
    )
  end

  # Prompts for the number in a numeric category (R29); see
  # `Update.prompt_action/3` for {:item_number, item, category}.
  defp ask_number(state, mode, %{category: cat_id, number: number}) do
    Update.prompt(
      state,
      "#{state.db.categories[cat_id].name}:",
      {:item_number, mode.item_id, cat_id},
      Update.number_text(number)
    )
  end

  # --- editing inside the box ----------------------------------------------------

  defp edit_key(%State{edit: edit} = state, mode, key) do
    assigning = match?({:assign_category, _}, edit.target)

    case key do
      :esc ->
        %{state | edit: nil}

      :enter ->
        commit(%{state | edit: nil}, mode, edit, Completion.shown(state))

      k when assigning and k in [{:f, 8}, {:alt, "n"}] ->
        Completion.cycle(state, 1)

      k when assigning and k in [{:f, 7}, {:alt, "p"}] ->
        Completion.cycle(state, -1)

      k when assigning and k in [:insert, {:f, 5}] ->
        new_category(%{state | edit: nil}, mode, edit.line.text)

      _ ->
        case LineEdit.handle(edit.line, key) do
          {:ok, line} -> %{state | edit: edit |> Map.put(:line, line) |> Map.put(:choice, 0)}
          :unhandled -> state
        end
    end
  end

  defp commit(state, _mode, %{target: {:item_text, item_id}, line: line}, _shown) do
    if String.trim(line.text) == "",
      do: State.error(state, "Item text cannot be empty"),
      else:
        State.change_db(state, Core.edit_item(state.db, item_id, line.text, State.context(state)))
  end

  defp commit(state, mode, %{target: {:assign_category, item_id}, line: line}, shown) do
    cond do
      shown && Agenda.Core.Database.date_category?(state.db, shown) ->
        ask_date(state, mode, shown)

      shown && state.db.categories[shown].kind == :numeric ->
        ask_number(state, mode, %{category: shown, number: nil})

      shown ->
        state |> State.change_db(Core.assign(state.db, item_id, shown, State.context(state)))

      String.trim(line.text) == "" ->
        state

      true ->
        new_category(state, mode, line.text)
    end
  end

  # INS / F5 (NEWCAT): exactly the typed name, as a new category under MAIN.
  defp new_category(state, mode, text) do
    case Core.assign_new_by_name(state.db, mode.item_id, state.db.main_id, text) do
      {:ok, db, cat_id} ->
        state |> State.change_db(db) |> State.info("Assigned to #{db.categories[cat_id].name}")

      {:error, :empty} ->
        state
    end
  end
end
