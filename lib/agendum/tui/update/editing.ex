# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Update.Editing do
  @moduledoc """
  Inline editing in the view: typing a new item, editing an item's text,
  renaming a section's category, and column entries with completion
  (R32); what Agenda assigned on its own is reported (R14). Pure.
  """

  alias Agendum.Core
  alias Agendum.Core.{Database, DateFormat}
  alias Agendum.TUI.{Typing.Completion, Layout, Typing.LineEdit, State}
  alias Agendum.TUI.Update.ViewKeys

  # --- inline editing in the view ---------------------------------------------

  @doc "A key while an item, a category name or a column entry is edited in the view."
  def view_edit_key(%State{edit: edit} = state, key) do
    completing = Completion.column_entry?(state)

    case key do
      :esc ->
        %{state | edit: nil}

      :enter ->
        commit(state)

      # automatic completion (R32): NEXTSEL / PREVSEL and NEWCAT
      k when completing and k in [{:f, 8}, {:alt, "n"}] ->
        Completion.cycle(state, 1)

      k when completing and k in [{:f, 7}, {:alt, "p"}] ->
        Completion.cycle(state, -1)

      k when completing and k in [:insert, {:f, 5}] ->
        commit_new_category(state)

      # F3 (CHOICES): the column's list of categories, as F3 on the entry
      {:f, 3} when completing ->
        ViewKeys.view_key(%{state | edit: nil}, {:f, 3})

      # a refused text keeps the line open (below), and the highlight with it
      k when k in [:up, :down, :tab, :shift_tab] ->
        case commit(state) do
          %State{edit: nil} = committed -> ViewKeys.view_key(committed, k)
          refused -> refused
        end

      _ ->
        case LineEdit.handle(edit.line, key) do
          # typing starts the completion over at the first match
          {:ok, line} -> %{state | edit: edit |> Map.put(:line, line) |> Map.put(:choice, 0)}
          :unhandled -> state
        end
    end
  end

  # ENTER on a column entry takes the completion shown (R32); with no match
  # the typed name becomes a new category.
  @doc """
  Sets a column entry as if typed (replacing what is there), as the pop-up
  calendar does with the date it picked (R46).
  """
  def set_column_entry(state, item_id, head, text),
    do: commit(state, {:column_entry, item_id, head, :replace}, text)

  defp commit(%State{edit: %{target: {:column_entry, item_id, head, how}, line: line}} = state) do
    shown = Completion.shown(state)
    state = %{state | edit: nil}

    if shown do
      State.run(state, {:type_in_column, item_id, head, {:category, shown}, how == :replace})
    else
      commit(state, {:column_entry, item_id, head, how}, line.text)
    end
  end

  # an item's text emptied is refused while the line is still open, so it
  # can be typed again (Agenda takes an empty text; ours keeps one)
  defp commit(%State{edit: %{target: target, line: line}} = state) do
    if match?({:edit_item, _}, target) and String.trim(line.text) == "",
      do: State.error(state, "Item text cannot be empty (use ALT-F4 to discard)"),
      else: commit(%{state | edit: nil}, target, line.text)
  end

  # INS / F5 (NEWCAT): exactly the typed name, even if it begins an existing one.
  defp commit_new_category(
         %State{edit: %{target: {:column_entry, item_id, head, how}, line: line}} = state
       ) do
    state = %{state | edit: nil}

    command = {:type_in_column, item_id, head, {:new, line.text}, how == :replace}

    case State.command(state, command) do
      {:ok, state, %{new: cat_id}} ->
        State.info(state, "Assigned to #{state.db.categories[cat_id].name}")

      {:error, :empty} ->
        state
    end
  end

  defp commit(state, {:new_item, sidx, key}, text) do
    datebook = State.view(state).datebook

    cond do
      String.trim(text) == "" -> state
      datebook -> new_datebook_item(state, datebook, sidx, text)
      true -> new_item(state, sidx, key, text)
    end
  end

  defp commit(state, {:edit_item, id}, text) do
    before = Database.explicit_categories(state.db, id)
    old_when = Core.when_at(state.db.items[id])

    state
    |> State.run({:edit_item, id, text})
    |> report_auto_assignments(id, MapSet.to_list(before), old_when)
  end

  defp commit(state, {:rename_category, id}, text) do
    case State.command(state, {:rename_category, id, text}) do
      {:ok, state, _} -> state
      {:error, :empty} -> State.error(state, "A category needs a name")
      {:error, :protected} -> State.error(state, "This category cannot be renamed")
    end
  end

  defp commit(state, {:note_line, _, _, _} = target, text), do: set_note_line(state, target, text)

  defp commit(state, {:column_entry, item_id, head, how}, text) do
    case State.command(state, {:type_in_column, item_id, head, {:name, text}, how == :replace}) do
      {:ok, state, _} ->
        state

      {:error, :empty} ->
        state

      {:error, :invalid_date} ->
        State.error(state, Agendum.TUI.Messages.text(:bad_date))

      {:error, :not_a_number} ->
        State.error(state, Agendum.TUI.Messages.text(:bad_number))

      {:error, :ambiguous} ->
        State.error(state, "\"#{text}\" matches several categories; type more or press F3")
    end
  end

  # typed into a datebook slot: filed under the Section category, dated at
  # the slot's start (R47)
  defp new_datebook_item(state, datebook, sidx, text) do
    slot =
      state
      |> Layout.rows()
      |> Enum.find(&(&1.kind == :section and &1.sidx == sidx))
      |> Map.get(:slot)

    section =
      if datebook.section_category == state.db.main_id, do: nil, else: datebook.section_category

    opts = Keyword.put(Agendum.Core.Datebook.entry(datebook, slot), :section, section)
    state |> State.run_with_changes({:add_item, text, opts}) |> added(sidx, List.wrap(section))
  end

  defp new_item(state, sidx, key, text) do
    rows = Layout.rows(state)
    section_rows = Enum.filter(rows, &(&1.kind == :item and &1.sidx == sidx))
    section_cat = Enum.at(State.view(state).sections, sidx).category_id

    {after_id, adjacent} =
      case key do
        {:item, _, id} ->
          next = section_rows |> Enum.drop_while(&(&1.item.id != id)) |> Enum.at(1)
          {id, [id | List.wrap(next && next.item.id)]}

        {:section, _} ->
          case section_rows do
            [] -> {nil, []}
            [first | _] -> {predecessor(state.db.item_order, first.item.id), [first.item.id]}
          end
      end

    section = if section_cat == state.db.main_id, do: nil, else: section_cat

    # a filtered view or section gives new items what the filter needs
    # (R28): the command does it, given the view's section
    required = Core.entry_categories(state.db, state.view_id, sidx)

    command =
      {:add_item, text,
       section: section, after: after_id, adjacent: adjacent, view_section: {state.view_id, sidx}}

    state |> State.run_with_changes(command) |> added(sidx, List.wrap(section) ++ required)
  end

  # The new item is highlighted, and what was filed on its own is told;
  # `already` are the categories it was typed under, not news.
  defp added({state, %{new: id}}, sidx, already) do
    state
    |> Map.put(:cursor_key, {:item, sidx, id})
    |> report_auto_assignments(id, already)
  end

  defp added({state, _refused}, _sidx, _already), do: state

  defp predecessor(order, id) do
    case Enum.find_index(order, &(&1 == id)) do
      0 -> :first
      i -> Enum.at(order, i - 1)
    end
  end

  # Tells the user what Agenda did on its own: categories found in the text,
  # and a When date read from it (R14).
  defp report_auto_assignments(state, item_id, already),
    do: report_auto_assignments(state, item_id, already, nil)

  # A special action (R15b) may have discarded the item at once.
  defp report_auto_assignments(state, item_id, _already, _old_when)
       when not is_map_key(state.db.items, item_id),
       do: State.info(state, Agendum.TUI.Messages.text(:discarded_by_action))

  defp report_auto_assignments(state, item_id, already, old_when) do
    added =
      Database.explicit_categories(state.db, item_id)
      |> Enum.reject(&(&1 in already))
      |> Enum.map(&state.db.categories[&1].name)

    item = state.db.items[item_id]
    new_when = Core.when_at(item)

    parts =
      [
        added != [] && "Also assigned to: " <> Enum.join(added, ", "),
        new_when != old_when && new_when &&
          "When: " <>
            DateFormat.date_time(item.when, item.when_time, state.db.date_format),
        new_when != old_when && is_nil(new_when) && "When date removed"
      ]
      |> Enum.filter(& &1)

    if parts == [], do: state, else: State.info(state, Enum.join(parts, " · "))
  end

  @doc """
  A number as offered for editing: in full, without formatting, with the
  person's decimal separator (`State.number_opts/1`, R54).
  """
  def number_text(value, opts \\ [])
  def number_text(nil, _opts), do: ""

  def number_text(value, opts) do
    if value == Float.round(value),
      do: value |> round() |> Integer.to_string(),
      else:
        value |> :erlang.float_to_binary([:short]) |> String.replace(".", opts[:decimal] || ".")
  end

  @doc """
  Writes a Category note column's line for an item (R56): the note of the
  item's category in that column; an item with none there is told so.
  """
  def set_note_line(state, {:note_line, item_id, head, n}, text) do
    case State.command(state, {:set_column_note, item_id, head, n, text}) do
      {:ok, state, _} ->
        state

      {:error, :no_category} ->
        item = state.db.items[item_id].text

        State.error(
          state,
          "#{item} has no #{state.db.categories[head].name} category to write in"
        )
    end
  end
end
