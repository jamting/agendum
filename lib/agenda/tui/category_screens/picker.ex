defmodule Agenda.TUI.CategoryScreens.Picker do
  @moduledoc """
  The category picker: its keys and search, and what choosing a category
  does for each purpose the picker is opened for (a section, a column, a
  filter, a condition, an action, a negative link, ...). Pure.
  """

  alias Agenda.Core
  alias Agenda.Core.Database
  alias Agenda.TUI.{CategoryScreens, LineEdit, State}
  alias Agenda.TUI.CategoryScreens.Choices

  # --- category picker ------------------------------------------------------------------

  @doc "Keys of the category picker."
  def screen_key(state, %{type: :picker} = mode, rows, key) do
    case key do
      :esc when mode.search != "" ->
        State.put_mode(state, %{mode | search: ""})

      :esc ->
        State.pop(state)

      # filters, conditions and actions are set several at a time: the box stays open
      :enter
      when elem(mode.purpose, 0) in [
             :filter,
             :condition,
             :also_assign,
             :excludes,
             :schedule_filter
           ] ->
        pick(state, mode.purpose, CategoryScreens.current_id(rows, mode))

      :enter ->
        pick(State.pop(state), mode.purpose, CategoryScreens.current_id(rows, mode))

      :insert ->
        %{state | edit: %{target: :new_pick, line: LineEdit.new()}}

      :backspace ->
        search(state, mode, rows, String.slice(mode.search, 0..-2//1))

      {:char, c} ->
        search(state, mode, rows, mode.search <> c)

      _ ->
        state
    end
  end

  defp search(state, mode, rows, text) do
    wanted = String.downcase(text)

    index =
      Enum.find_index(rows, fn {id, _} ->
        String.starts_with?(String.downcase(state.db.categories[id].name), wanted)
      end)

    State.put_mode(state, %{mode | search: text, cursor: index || mode.cursor})
  end

  # --- picker results -------------------------------------------------------------------------

  @doc "Does what the picker was opened for with the chosen category."
  def pick(state, _purpose, nil), do: state

  def pick(state, {:schedule, field}, id),
    do: Agenda.TUI.ScheduleBox.set_category(state, field, id)

  def pick(state, {:schedule_filter, _}, id), do: Agenda.TUI.ScheduleBox.cycle_filter(state, id)

  # ALT-F2 MAKECAT in a note: back in the note, the category made
  def pick(state, {:make_category, name}, id),
    do: Agenda.TUI.Update.Notes.add_category(state, name, id)

  def pick(state, {:datebook, view_id, row}, id),
    do: Agenda.TUI.DatebookBox.set_category(state, view_id, row, id)

  # `from`: the section the cursor was in, whose linked columns the new
  # one gets (R55)
  def pick(state, {:add_section, index, from}, id) do
    index = min(index, length(State.view(state).sections))

    %{
      State.change_db(state, Core.add_section(state.db, state.view_id, id, index, from))
      | cursor_key: {:section, index}
    }
  end

  def pick(state, {:change_section, sidx}, id) do
    db = Core.set_section_category(state.db, state.view_id, sidx, id)
    %{State.change_db(state, db) | cursor_key: {:section, sidx}}
  end

  # the core decides its width and which sections get it (R55)
  # the highlight goes to the new column (`state.col` counts from 1)
  def pick(state, {:add_column, {sidx, place} = at}, id) do
    index = Agenda.Core.ViewColumns.insert_index(State.view(state), sidx, place)
    %{State.change_db(state, Core.add_column(state.db, state.view_id, id, at)) | col: index + 1}
  end

  # Column Add ▸ Column head: back in the box, which adds it on ENTER
  def pick(state, :column_add, id), do: Agenda.TUI.ColumnAddBox.set_head(state, id)

  # Column Properties ▸ Column head (R55): back in the box, which shows the
  # column's new head (and its kind's settings)
  def pick(state, {:column_head, at}, id),
    do: State.change_db(state, Core.set_column_head(state.db, state.view_id, at, id))

  def pick(state, {:filter, scope}, id) do
    if Agenda.Core.RangeFilter.range_category?(state.db, id) do
      Agenda.TUI.RangeFilterBox.open(state, scope, id)
    else
      {:ok, db} = Core.cycle_filter(state.db, state.view_id, scope, id)
      State.change_db(state, db)
    end
  end

  def pick(state, :execute_root, id), do: Agenda.TUI.ExecuteBox.set_root(state, id)

  def pick(state, {:sort_note, scope, index}, id),
    do: Agenda.TUI.SortBox.set_note(state, scope, index, id)

  def pick(state, {:sort_category, scope, index}, id),
    do: Agenda.TUI.SortBox.set_category(state, scope, index, id)

  # ALT-M (MakeAssign): one item or all marked items
  def pick(state, {:assign_items, ids}, id) do
    cond do
      Database.date_category?(state.db, id) ->
        State.error(state, "Set dates with ALT-F2 (When) or F4 (Done)")

      CategoryScreens.numeric?(state.db, id) ->
        CategoryScreens.numbers_hint(state, id)

      true ->
        db = Enum.reduce(ids, state.db, &Core.assign(&2, &1, id, State.context(state)))
        noun = if length(ids) == 1, do: "Item", else: "#{length(ids)} items"

        state
        |> State.change_db(db)
        |> State.info("#{noun} assigned to #{db.categories[id].name}")
    end
  end

  def pick(state, {:assign_column, item_id, _head}, id),
    do: State.change_db(state, Core.assign(state.db, item_id, id, State.context(state)))

  def pick(state, {:new_view, name}, id) do
    {db, view_id} = Core.add_view(state.db, name, [id])
    %{State.switch_view(State.change_db(state, db), view_id) | modes: []}
  end

  def pick(state, {:move_category, cat_id}, parent),
    do: Choices.move(state, cat_id, {:move, parent, nil})

  # ENTER on a category cycles its condition: none → assigned → not assigned
  def pick(state, {:condition, cat_id}, target) do
    if Agenda.Core.RangeFilter.range_category?(state.db, target),
      do: Agenda.TUI.RangeFilterBox.open_condition(state, cat_id, target),
      else: cycle_condition(state, cat_id, target)
  end

  # Assignment actions (R15b): a date or numeric category opens the action
  # box; another category cycles assign → remove → none.
  def pick(state, {:also_assign, cat_id}, target) do
    cat = state.db.categories[cat_id]

    cond do
      Agenda.Core.RangeFilter.range_category?(state.db, target) ->
        Agenda.TUI.ActionBox.open(state, cat_id, target)

      target in cat.also_assign ->
        action_result(state, Core.set_action(state.db, cat_id, target, :remove))

      List.keymember?(cat.actions, target, 0) ->
        State.change_db(state, Core.remove_action(state.db, cat_id, target))

      true ->
        action_result(state, Core.set_action(state.db, cat_id, target, :assign))
    end
  end

  # Negative links (R9): ENTER toggles one between the two categories.
  def pick(state, {:excludes, cat_id}, target) do
    names = fn -> {state.db.categories[cat_id].name, state.db.categories[target].name} end

    case Core.toggle_exclude(state.db, cat_id, target) do
      {:ok, db} ->
        State.change_db(state, db)

      {:error, :self} ->
        State.error(state, "A category cannot exclude itself")

      {:error, :lineage} ->
        State.error(state, "A category cannot exclude its parents or children")

      {:error, :not_allowed} ->
        State.error(state, "Only standard categories can exclude each other")

      {:error, {:shared, items}} ->
        {a, b} = names.()
        what = if length(items) == 1, do: "1 item is", else: "#{length(items)} items are"
        it = if length(items) == 1, do: "it", else: "them"
        State.error(state, "#{what} in both #{a} and #{b}; move #{it} first")
    end
  end

  defp action_result(state, {:ok, db}), do: State.change_db(state, db)

  defp action_result(state, {:error, :self}),
    do: State.error(state, "A category cannot act on itself")

  defp cycle_condition(state, cat_id, target) do
    case Core.cycle_condition(state.db, cat_id, target) do
      {:ok, db} ->
        state |> State.change_db(db) |> State.info(condition_message(db, cat_id, target))

      {:error, :self} ->
        State.error(state, "A category cannot depend on itself")
    end
  end

  defp condition_message(db, cat_id, target) do
    name = db.categories[cat_id].name
    other = db.categories[target].name

    case List.keyfind(db.categories[cat_id].conditions, target, 0) do
      {_, :assigned} ->
        "#{name} now assigns items in #{other} (Recalc applies it to existing items)"

      {_, :not_assigned} ->
        "#{name} now assigns items not in #{other} (Recalc applies it to existing items)"

      nil ->
        "Condition on #{other} removed"
    end
  end
end
