defmodule Agendum.TUI.ItemProperties do
  @moduledoc """
  The Item Properties box (F6 on an item; User's Guide 4-13 to 4-15): the
  item's text, note, statistics, the items it depends on ("Depends on")
  and those depending on it ("Needed by", R43), and every category it is
  assigned to.

    * F2 on the text edits it; SPACE (or F2) on the note opens it
    * on a dependency: SPACE opens that item's properties (ESC comes
      back); DEL removes that one dependency
    * on an assignment: DEL breaks it; F4 changes a date or a
      number
    * typing anywhere in the assignments assigns a category, with automatic
      completion over all categories (ENTER accepts, F8/F7 cycle, INS
      creates exactly what was typed under MAIN); a date category asks for
      its date
    * F3 opens the assignment profile; ENTER or F6 closes the box, ESC
      closes it and cancels its changes (`Agendum.TUI.BoxCancel`)

  Pure, like the rest of the TUI state machine.
  """

  import Agendum.TUI.BoxNav, only: [is_move: 1]
  alias Agendum.TUI.BoxNav

  alias Agendum.Core
  alias Agendum.TUI.{CategoryScreens, Completion, LineEdit, State, TextEdit}
  alias Agendum.TUI.Update.{Editing, Prompts}

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
      # ENTER is done (ESC cancels: `Agendum.TUI.BoxCancel`)
      {k, _} when k in [:esc, :enter, {:f, 6}] ->
        State.pop(state)

      {k, _} when is_move(k) ->
        BoxNav.move(state, mode, BoxNav.column(rows), k)

      {{:f, 3}, _} ->
        CategoryScreens.open_profile(state, mode.item_id)

      {{:f, 2}, :text} ->
        edit_text(state, mode)

      {k, :note} when k in [{:f, 2}, {:char, " "}] ->
        open_note(state, mode)

      {k, {kind, id}} when kind in [:prerequisite, :dependent] ->
        dependency_key(state, mode, k, kind, id)

      {{:f, 4}, {:assigned, %{kind: :date} = a}} ->
        ask_date(state, mode, a.category)

      {{:f, 4}, {:assigned, %{kind: :numeric} = a}} ->
        ask_number(state, mode, a)

      {:delete, {:assigned, a}} ->
        remove(state, mode, a)

      {:insert, row} when row != :text and row != :note ->
        start_assign(state, "")

      {{:char, c}, row} when row == :stats or row == :add or elem(row, 0) == :assigned ->
        start_assign(state, c)

      _ ->
        state
    end
  end

  defp dependency_key(state, _mode, {:char, " "}, _kind, id), do: open(state, id)

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
  # `Update.Prompts` (`prompt_action/3`) for {:item_date, item, category}.
  defp ask_date(state, mode, cat_id) do
    db = state.db

    current =
      Agendum.Core.DateParser.format(Agendum.Core.Database.item_date(db, mode.item_id, cat_id))

    Prompts.prompt(
      state,
      "#{db.categories[cat_id].name} date:",
      {:item_date, mode.item_id, cat_id},
      current
    )
  end

  # Prompts for the number in a numeric category (R29); see
  # `Update.Prompts` (`prompt_action/3`) for {:item_number, item, category}.
  defp ask_number(state, mode, %{category: cat_id, number: number}) do
    Prompts.prompt(
      state,
      "#{state.db.categories[cat_id].name}:",
      {:item_number, mode.item_id, cat_id},
      Editing.number_text(number, State.number_opts(state))
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
      shown && Agendum.Core.Database.date_category?(state.db, shown) ->
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

  @doc "The highlighted field, for its help in the control panel (`Agendum.TUI.FieldHelp`)."
  def field(state, mode) do
    rows = rows(state, mode)

    case Enum.at(rows, mode.cursor |> min(length(rows) - 1) |> max(0)) do
      # a dependency or an assignment: the kind of row, not which one
      {kind, _id} -> kind
      row -> row
    end
  end
end
