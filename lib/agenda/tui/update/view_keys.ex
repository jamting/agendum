defmodule Agenda.TUI.Update.ViewKeys do
  @moduledoc """
  Keys in the view itself (no box open): moving the highlight, collapsing
  sections, starting to type an item or a column entry, and the commands
  on the highlighted row (F2, F3, F4, F6, DEL, ALT-O, ALT-E). Pure.
  """

  alias Agenda.Core
  alias Agenda.Core.{Database, DateFormat, ViewModel}

  alias Agenda.TUI.{
    CalendarBox,
    CategoryScreens,
    Draw,
    GoTo,
    ItemProperties,
    Layout,
    LineEdit,
    SearchBox,
    State
  }

  alias Agenda.TUI.Update.{Actions, Editing, Prompts}

  # the key chart in view_key/2 stays one line per key
  import Agenda.TUI.Update.Marked, only: [bulk?: 2, jump_to_marked: 2, mark: 2, scoped: 3]

  # --- the view ----------------------------------------------------------------

  @doc "A key in the view: moving, a command on the highlighted row, or inline editing."
  def view_key(%State{edit: edit} = state, key) when edit != nil,
    do: Editing.view_edit_key(state, key)

  # One branch per key, like Agenda's key chart.
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def view_key(state, key) do
    row = Layout.current_row(state)
    rows = Layout.rows(state)

    case key do
      :up ->
        Layout.move_to(state, state.cursor - 1)

      :down ->
        Layout.move_to(state, state.cursor + 1)

      :enter ->
        Layout.move_to(state, state.cursor + 1)

      :pgup ->
        Layout.move_to(state, state.cursor - State.body_height(state))

      :pgdn ->
        Layout.move_to(state, state.cursor + State.body_height(state))

      :home ->
        Layout.move_to(state, 0)

      :end ->
        Layout.move_to(state, length(rows) - 1)

      :ctrl_home ->
        Layout.move_to(state, 0)

      :ctrl_end ->
        Layout.move_to(state, length(rows) - 1)

      :ctrl_pgup ->
        Layout.move_to(state, section_head_index(rows, state.cursor, -1))

      :ctrl_pgdn ->
        Layout.move_to(state, section_head_index(rows, state.cursor, 1))

      # the highlight goes left and right as the columns are shown: the
      # item column may be among them (R55)
      k when k in [:right, :tab] ->
        Layout.step_col(state, row, 1)

      k when k in [:left, :shift_tab] ->
        Layout.step_col(state, row, -1)

      {:char, "/"} ->
        Actions.perform(state, :menu)

      {:char, c} ->
        start_typing(state, row, c)

      :insert ->
        insert(state, row)

      :delete ->
        if bulk?(state, row), do: scoped(state, :remove, row), else: delete(state, row)

      {:f, 1} ->
        Actions.perform(state, :help)

      {:f, 2} ->
        edit(state, row)

      {:f, 3} ->
        if bulk?(state, row), do: scoped(state, :profile, row), else: choices(state, row)

      {:f, 4} ->
        scoped(state, :done, row)

      # in a column, the note of the column head or of the entry's category
      {:f, 5} when state.col > 0 ->
        column_note(state)

      {:f, 5} ->
        Actions.perform(state, :note)

      {:f, 6} ->
        props(state, row)

      {:f, 7} ->
        mark(state, row)

      {:alt_f, 7} ->
        Actions.perform(state, :unmark_all)

      {:alt, "j"} ->
        jump_to_marked(state, rows)

      {:alt, "m"} ->
        scoped(state, :make_assign, row)

      {:f, 8} ->
        Actions.perform(state, :view_manager)

      {:f, 9} ->
        Actions.perform(state, :category_manager)

      {:f, 10} ->
        Actions.perform(state, :menu)

      {:alt_f, 4} ->
        scoped(state, :discard, row)

      {:alt_f, 2} ->
        scoped(state, :when, row)

      {:ctrl, "d"} ->
        scoped(state, :discard, row)

      # on a column head (a section head line) the column moves, as in
      # Agenda (User's Guide 5-20); elsewhere the item(s)
      {:alt_f, 10} when row.kind == :section and state.col > 0 ->
        Actions.perform(state, :column_move)

      # on a section head the section moves (User's Guide 5-8)
      {:alt_f, 10} when row.kind == :section ->
        Actions.perform(state, :section_move)

      {:alt_f, 10} ->
        scoped(state, :move_item, row)

      {:alt, "d"} ->
        Actions.perform(state, :section_below)

      {:alt_f, 5} ->
        GoTo.open(state)

      {:alt, "n"} ->
        step_view(state, 1)

      {:alt, "p"} ->
        step_view(state, -1)

      {:alt, "w"} ->
        Actions.perform(state, :save)

      {:alt, "g"} ->
        Actions.perform(state, :retrieve)

      {:alt, "v"} ->
        Actions.perform(state, {:toggle_view, :hide_empty})

      {:alt, "i"} ->
        insert(state, row)

      {:alt, "o"} ->
        dependency(state, row)

      {:alt, "x"} ->
        Agenda.TUI.ExecuteBox.run(state, state.db.main_id, :all)

      {:alt, "e"} ->
        execute_category(state, row)

      {:alt_f, 6} ->
        SearchBox.open(state, :view)

      {:alt, "a"} ->
        Actions.perform(state, :alarm)

      {:alt, "c"} ->
        CalendarBox.open(state, nil)

      {:alt, "b"} ->
        Agenda.TUI.Browse.open(state)

      {:alt_f, 8} ->
        Actions.perform(state, :last_view)

      {:alt, "-"} ->
        collapse_sections(state, row, true)

      {:alt, "="} ->
        collapse_sections(state, row, false)

      {:alt, "u"} ->
        Actions.perform(state, :section_above)

      {:alt, "r"} ->
        Actions.perform(state, :column_right)

      {:alt, "l"} ->
        Actions.perform(state, :column_left)

      _ ->
        state
    end
  end

  # ALT-N / ALT-P: the next / previous view in the view manager's order.
  defp step_view(state, step) do
    order = state.db.view_order
    index = Enum.find_index(order, &(&1 == state.view_id)) || 0
    State.switch_view(state, Enum.at(order, Integer.mod(index + step, length(order))))
  end

  # ALT-- / ALT-= collapse or expand the current section; pressed twice,
  # every section in the view (User's Guide 5-5).
  defp collapse_sections(state, nil, _collapsed), do: state
  defp collapse_sections(state, %{slot: %{}}, _collapsed), do: Actions.datebook_sections(state)

  defp collapse_sections(state, row, collapsed) do
    twice = state.last_key.key == {:alt, if(collapsed, do: "-", else: "=")}

    db =
      if twice,
        do: Core.set_all_sections_collapsed(state.db, state.view_id, collapsed),
        else: Core.set_section_collapsed(state.db, state.view_id, row.sidx, collapsed)

    %{State.change_db(state, db) | cursor_key: {:section, row.sidx}}
  end

  defp section_head_index(rows, from, direction) do
    indexed = Enum.with_index(rows)

    candidates =
      if direction < 0,
        do: indexed |> Enum.take(from) |> Enum.reverse(),
        else: Enum.drop(indexed, from + 1)

    Enum.find_value(candidates, from, fn {r, i} -> if r.kind == :section, do: i end)
  end

  # In a standard column the Format decides (R56; User's Guide 5-31 to
  # 5-37): SPACE stars, Y and N answer, a Category note line is typed;
  # otherwise the letter starts a column entry.
  defp start_typing(state, %{kind: :item} = row, c) when state.col > 0 do
    case {standard_format(state), c} do
      {:star, " "} -> star(state, row)
      {:yes_no, y} when y in ["y", "Y"] -> set_in_column(state, row, true)
      {:yes_no, n} when n in ["n", "N"] -> set_in_column(state, row, false)
      {:note, _} -> %{state | edit: %{target: note_target(state, row), line: LineEdit.new(c)}}
      _ -> %{state | edit: %{target: column_target(state, row, :replace), line: LineEdit.new(c)}}
    end
  end

  defp start_typing(state, row, c) when row != nil, do: begin_new_item(state, row, c)
  defp start_typing(state, nil, _c), do: State.error(state, "Add a section first (ALT-D)")

  defp insert(state, nil), do: Actions.perform(state, :section_below)

  defp insert(state, %{kind: :item} = row) when state.col > 0 do
    target = column_target(state, row, :add)
    %{state | edit: %{target: target, line: LineEdit.new()}}
  end

  defp insert(state, row), do: begin_new_item(state, row, "")

  defp begin_new_item(state, row, text) do
    %{state | col: 0, edit: %{target: {:new_item, row.sidx, row.key}, line: LineEdit.new(text)}}
  end

  # the highlighted column's Format, for a standard column; nil otherwise
  defp standard_format(state) do
    {column, _at} = Layout.current_column(state)
    if state.db.categories[column.category_id].kind == :standard, do: column.format
  end

  defp star(state, row) do
    {:column_entry, item_id, head, _} = column_target(state, row, :replace)
    set_in_column(state, row, not Database.member?(state.db, item_id, head))
  end

  defp set_in_column(state, row, in?) do
    {:column_entry, item_id, head, _} = column_target(state, row, :replace)
    State.change_db(state, Core.set_in_column(state.db, item_id, head, in?, State.context(state)))
  end

  # what a Category note column's cell types into: that line of the note
  defp note_target(state, row) do
    {column, _at} = Layout.current_column(state)
    {:note_line, row.item.id, column.category_id, column.note_line}
  end

  # NOTE (F5) in a column opens the note of the category highlighted there
  # (User's Guide 12-4: "Highlight the item or category")
  defp column_note(state) do
    case Layout.note_target(state) do
      {:category, id} -> CategoryScreens.open_note(state, id)
      _ -> State.error(state, "No category here to have a note")
    end
  end

  defp column_target(state, row, how) do
    {column, _at} = Layout.current_column(state)
    {:column_entry, row.item.id, column.category_id, how}
  end

  # on a column head (ours; the manual does not say): the head's category
  defp edit(state, %{kind: :section}) when state.col > 0 do
    {column, _at} = Layout.current_column(state)
    rename(state, state.db.categories[column.category_id])
  end

  defp edit(state, %{kind: :section, category: cat}), do: rename(state, cat)

  defp edit(state, %{kind: :item, item: item}) when state.col == 0 do
    %{state | edit: %{target: {:edit_item, item.id}, line: LineEdit.new(item.text)}}
  end

  # F2 in a Category note column: what its line says now (R56)
  defp edit(state, %{kind: :item} = row) when state.col > 0 do
    if standard_format(state) == :note,
      do: edit_note(state, row),
      else: edit_entry(state, row)
  end

  defp edit(state, nil), do: state

  defp edit_note(state, row) do
    {:note_line, item_id, head, n} = target = note_target(state, row)

    text =
      case ViewModel.column_entries(state.db, item_id, head) do
        [] -> ""
        [cat_id | _] -> ViewModel.note_line(state.db.categories[cat_id].note, n)
      end

    %{state | edit: %{target: target, line: LineEdit.new(text)}}
  end

  defp edit_entry(state, row) do
    {:column_entry, item_id, head, _} = column_target(state, row, :replace)
    numeric = state.db.categories[head].kind == :numeric

    case Database.date_category?(state.db, head) do
      false when numeric ->
        text =
          Editing.number_text(Database.number(state.db, item_id, head), State.number_opts(state))

        %{
          state
          | edit: %{target: {:column_entry, item_id, head, :replace}, line: LineEdit.new(text)}
        }

      false ->
        case ViewModel.column_entries(state.db, item_id, head) do
          [] ->
            %{
              state
              | edit: %{target: {:column_entry, item_id, head, :replace}, line: LineEdit.new()}
            }

          [cat_id | _] ->
            %{
              state
              | edit: %{
                  target: {:rename_category, cat_id},
                  line: LineEdit.new(state.db.categories[cat_id].name)
                }
            }
        end

      true ->
        text = Agenda.Core.DateParser.format(Database.item_date(state.db, item_id, head))

        %{
          state
          | edit: %{target: {:column_entry, item_id, head, :replace}, line: LineEdit.new(text)}
        }
    end
  end

  defp rename(state, cat) do
    if Database.protected?(state.db, cat.id),
      do: State.error(state, "#{cat.name} cannot be renamed"),
      else: %{state | edit: %{target: {:rename_category, cat.id}, line: LineEdit.new(cat.name)}}
  end

  @doc """
  DEL on the highlighted row: removes the column (on its head), the section
  from the view, the item from the section's category, or the column entry.
  """
  def delete(state, %{kind: :section}) when state.col > 0,
    do: Actions.perform(state, :remove_column)

  def delete(state, %{kind: :section, slot: %{}}), do: Actions.datebook_sections(state)

  def delete(state, %{kind: :section, sidx: sidx}) do
    state
    |> State.change_db(Core.remove_section(state.db, state.view_id, sidx))
    |> State.info("Section removed from view (category kept)")
  end

  def delete(state, %{kind: :item, item: item, category: cat}) when state.col == 0 do
    if cat.id == state.db.main_id do
      State.error(state, "Items cannot be removed from MAIN; use ALT-F4 to discard")
    else
      state
      |> State.change_db(
        Core.remove_from_category(state.db, item.id, cat.id, State.context(state))
      )
      |> State.info("Removed from #{cat.name}")
    end
  end

  # DEL in a column: a Category note line is emptied, a Star or Yes/No
  # column takes the item out of the head (R56), others lose their entries
  def delete(state, %{kind: :item} = row) do
    case standard_format(state) do
      :note ->
        Editing.set_note_line(state, note_target(state, row), "")

      format when format in [:star, :yes_no] ->
        set_in_column(state, row, false)

      _ ->
        {:column_entry, item_id, head, _} = column_target(state, row, :replace)

        State.change_db(
          state,
          Editing.clear_column(state.db, item_id, head, State.context(state))
        )
    end
  end

  def delete(state, nil), do: state

  @doc """
  F3 (CHOICES) on the highlighted row: the column's choices or calendar,
  the item's assignment profile, or the categories for the section or
  column head (User's Guide 5-25).
  """
  def choices(state, %{kind: :item} = row) when state.col > 0 do
    {:column_entry, item_id, head, _} = column_target(state, row, :replace)

    cond do
      Database.date_category?(state.db, head) ->
        CalendarBox.open(state, {item_id, head})

      state.db.categories[head].kind == :numeric ->
        State.error(state, "Type a number, e.g. 120 or 1,234.50")

      true ->
        CategoryScreens.open_picker(state, {:assign_column, item_id, head}, head)
    end
  end

  def choices(state, %{kind: :item, item: item}),
    do: CategoryScreens.open_profile(state, item.id)

  def choices(state, %{kind: :section}) when state.col > 0 do
    {_column, at} = Layout.current_column(state)
    CategoryScreens.open_picker(state, {:column_head, at}, nil)
  end

  def choices(state, %{kind: :section, slot: %{}}), do: Actions.datebook_sections(state)

  def choices(state, %{kind: :section, sidx: sidx}),
    do: CategoryScreens.open_picker(state, {:change_section, sidx}, nil)

  def choices(state, nil), do: state

  defp props(state, %{kind: :section}) when state.col > 0,
    do: Actions.perform(state, :column_props)

  defp props(state, %{kind: :item, item: item}), do: ItemProperties.open(state, item.id)

  # Agenda's PROPS on a section head: Section Properties, whose head field
  # opens the category's properties with F6 again
  defp props(state, %{kind: :section}), do: Actions.perform(state, :section_props)

  defp props(state, nil), do: state

  # ALT-E: the conditions and actions of the highlighted section's category
  # (or the item's section) and its children, on all items (R15e).
  defp execute_category(state, nil), do: state

  defp execute_category(state, row),
    do: Agenda.TUI.ExecuteBox.run(state, row.category.id, :all)

  # ALT-O (User's Guide 13-12): make the item depend on the marked items,
  # or, with nothing marked, clear its dependencies.
  defp dependency(state, %{kind: :item, item: item}) do
    marked = Core.marked_items(state.db) -- [item.id]

    cond do
      marked != [] ->
        Prompts.confirm(
          state,
          "Make this item depend on the #{Draw.count(length(marked), "marked item")}? (Y/N)",
          {:make_dependent, item.id, marked}
        )

      Core.prerequisites(state.db, item.id) != [] ->
        Prompts.confirm(
          state,
          "Clear this item's dependencies? (Y/N)",
          {:clear_dependencies, item.id}
        )

      true ->
        State.error(state, "Mark the items it depends on with F7, then ALT-O")
    end
  end

  defp dependency(state, _row), do: State.error(state, "Highlight an item first")

  @doc "F4 DONE; for a recurring item, says when its next occurrence is (R14a)."
  def toggle_done(state, row) do
    next = on_item(state, row, &Core.toggle_done(&1, &2, State.context(state)))

    case next.db.item_order -- state.db.item_order do
      [copy] ->
        date = DateFormat.date(next.db.items[copy].when, next.db.date_format)
        State.info(next, "Done · the next one is on #{date}")

      _ ->
        next
    end
  end

  @doc "Changes the database with `fun.(db, item_id)` when the row is an item."
  def on_item(state, %{kind: :item, item: item}, fun),
    do: State.change_db(state, fun.(state.db, item.id))

  def on_item(state, _row, _fun), do: state
end
