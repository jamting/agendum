defmodule Agendum.TUI.Update.Actions do
  @moduledoc """
  Named actions shared by keys and the menu (`perform/2`): the place a
  command layer (ADR 0020) will grow from. Pure.
  """

  alias Agendum.Core
  alias Agendum.Core.{Database, View}

  alias Agendum.TUI.{
    AlarmList,
    CategoryScreens,
    ColumnAddBox,
    ColumnBox,
    ColumnWidth,
    Draw,
    FileProperties,
    History,
    ItemProperties,
    Layout,
    Menu,
    SearchBox,
    SortBox,
    State,
    TextEdit,
    ViewManager
  }

  alias Agendum.TUI.Update.{Marked, Prompts, ViewKeys}

  # --- actions (shared by keys and menus) --------------------------------------

  @doc "Performs a named action. Used by key handlers and the menu."
  @spec perform(State.t(), atom | tuple) :: State.t()
  # a datebook view's sections are its time slots (R47)
  @section_commands [
    :section_below,
    :section_above,
    :remove_section,
    :collapse_section,
    :filter_section,
    :sort_section,
    :section_props,
    :section_move
  ]

  def perform(state, action) do
    if action in @section_commands and State.view(state).datebook,
      do: datebook_sections(state),
      else: do_perform(state, action, Layout.current_row(state))
  end

  @doc "Section commands in a datebook view say why they do nothing (R47)."
  def datebook_sections(state),
    do: State.error(state, "A datebook view's sections are its dates; they follow its settings")

  defp do_perform(state, :menu, _row), do: Menu.open(state)
  defp do_perform(state, :view_manager, _), do: ViewManager.open(state)
  defp do_perform(state, :category_manager, _), do: CategoryScreens.open_catmgr(state)
  defp do_perform(state, :help, _), do: State.push(state, %{type: :help, top: 0})
  defp do_perform(state, :undo, _), do: History.undo(state)
  defp do_perform(state, :redo, _), do: History.redo(state)

  defp do_perform(state, :save, _) do
    if state.path,
      do: State.effect(state, {:save, state.path}),
      else: Prompts.prompt(state, "Save file as:", :save_as)
  end

  defp do_perform(state, :save_as, _),
    do: Prompts.prompt(state, "Save file as:", :save_as, state.path || "")

  # Commands that replace the open file ask first when it has unsaved changes.
  defp do_perform(%State{dirty: true} = state, command, _)
       when command in [:retrieve, :new_file, :import_json],
       do: Prompts.ask(state, "Save changes first?", {:leave_for, command})

  defp do_perform(state, command, _) when command in [:retrieve, :new_file, :import_json],
    do: Prompts.replace_file(state, command)

  defp do_perform(state, :export_json, _) do
    name = if state.path, do: Path.rootname(state.path) <> ".json", else: "agendum.json"
    Prompts.prompt(state, "Export to JSON file:", :export_json, name)
  end

  defp do_perform(state, :export, _),
    do: Prompts.prompt(state, "Print view to text file:", :export, "agendum-view.txt")

  defp do_perform(state, :quit, _) do
    if state.dirty,
      do: Prompts.ask(state, "Save changes before quitting?", :quit),
      else: State.effect(state, :quit)
  end

  defp do_perform(state, :save_and_quit, _) do
    if state.path,
      do: state |> State.effect({:save, state.path}) |> State.effect(:quit),
      else: Prompts.prompt(state, "Save file as:", :save_as_then_quit)
  end

  defp do_perform(state, :note, %{kind: :item, item: item}) do
    State.push(state, %{
      type: :note,
      target: {:item, item.id},
      title: item.text,
      edit: TextEdit.new(item.note)
    })
  end

  defp do_perform(state, :note, %{kind: :section, category: cat}) do
    State.push(state, %{
      type: :note,
      target: {:category, cat.id},
      title: cat.name,
      edit: TextEdit.new(cat.note)
    })
  end

  defp do_perform(state, :discard, %{kind: :item, item: item}) do
    Prompts.confirm(
      state,
      "Discard this item from the whole file?",
      {:discard_item, item.id}
    )
  end

  defp do_perform(state, :discard, %{kind: :section, category: cat}) do
    if Database.protected?(state.db, cat.id),
      do: State.error(state, "#{cat.name} cannot be discarded"),
      else:
        Prompts.confirm(
          state,
          "Discard category #{cat.name} and its children?",
          {:discard_category, cat.id}
        )
  end

  defp do_perform(state, :done, row),
    do: ViewKeys.toggle_done(state, row)

  defp do_perform(state, :mark, row), do: Marked.mark(state, row)
  defp do_perform(state, :make_assign, row), do: Marked.scoped(state, :make_assign, row)

  defp do_perform(state, :when, %{kind: :item, item: item}) do
    current = if item.when, do: Agendum.Core.DateParser.format(item.when), else: ""
    Prompts.prompt(state, "When date (overrides dates in the text):", {:when, item.id}, current)
  end

  defp do_perform(state, :file_props, _), do: FileProperties.open(state)
  defp do_perform(state, :customize, _), do: Agendum.TUI.CustomizeBox.open(state)
  defp do_perform(state, :calendars, _), do: Agendum.TUI.CalendarsBox.open(state)
  defp do_perform(state, :execute, _), do: Agendum.TUI.ExecuteBox.open(state)
  defp do_perform(state, :questions, _), do: Agendum.TUI.QuestionsBox.open(state)

  # one box for every column, its lower part by the column's kind (R55)
  defp do_perform(state, :column_props, row) when row != nil and state.col > 0 do
    {_column, at} = Layout.current_column(state)
    ColumnBox.open(state, at)
  end

  # on the item text: the section's item column (R55)
  defp do_perform(state, :column_props, row) when row != nil do
    if State.view(state).datebook,
      do: State.error(state, "A datebook view's item text fills the width its columns leave"),
      else: Agendum.TUI.ItemColumnBox.open(state, row.sidx)
  end

  defp do_perform(state, :column_props, _),
    do: State.error(state, "Highlight a column head or entry first")

  defp do_perform(state, :toggle_auto_date, _) do
    db = Core.toggle_auto_date(state.db)

    message =
      if Core.auto_dating?(db),
        do: "Dates in item text set When dates",
        else: "Dates in item text are ignored"

    state |> State.change_db(db) |> State.info(message)
  end

  defp do_perform(state, :item_props, %{kind: :item, item: item}),
    do: ItemProperties.open(state, item.id)

  defp do_perform(state, :assign, %{kind: :item, item: item}),
    do: CategoryScreens.open_profile(state, item.id)

  defp do_perform(state, :copy_item, %{kind: :item, item: item}),
    do: Agendum.TUI.CopyBox.open(state, [item.id])

  defp do_perform(state, :copy_item, _row), do: State.error(state, "Highlight an item to copy")

  defp do_perform(state, :move_item, %{kind: :item, item: item, category: cat}) do
    Marked.start_move(state, [{item.id, cat.id}])
  end

  # ALT-A (Item Alarm): set an alarm, or cancel the one already set
  defp do_perform(state, :alarm, %{kind: :item, item: item}) do
    cond do
      item.alarm_minutes != nil ->
        state
        |> State.change_db(Core.cancel_alarm(state.db, item.id))
        |> State.info("Alarm cancelled")

      item.when == nil ->
        State.error(state, "Give the item a When date and time first (ALT-F2)")

      true ->
        Prompts.prompt(
          state,
          "Alarm: minutes before the When time (0-60):",
          {:alarm, item.id},
          "5"
        )
    end
  end

  defp do_perform(state, :alarm_list, _), do: AlarmList.open(state)

  defp do_perform(state, :search_view, _), do: SearchBox.open(state, :view)
  defp do_perform(state, :search_file, _), do: SearchBox.open(state, :file)

  # Utilities Show Depends / Show Prereqs (User's Guide 13-15, R43)
  defp do_perform(state, {:show_related, direction, level}, row) do
    item_id =
      case row do
        %{kind: :item, item: item} -> item.id
        _ -> nil
      end

    if item_id == nil and level != :every do
      State.error(state, "Highlight an item first")
    else
      case Core.related_items(state.db, item_id, direction, level) do
        [] ->
          State.info(
            state,
            if(direction == :dependents,
              do: "No items depend on this one",
              else: "This item depends on no other items"
            )
          )

        ids ->
          {db, view_id} = Core.show_items(state.db, ids)
          noun = if direction == :dependents, do: "dependent", else: "prerequisite"

          state
          |> State.change_db(db)
          |> State.switch_view(view_id)
          |> State.info(
            "#{Draw.count(length(ids), noun <> " item")} · ALT-F8 returns to the last view"
          )
      end
    end
  end

  # ALT-F8 (LAST VW): back to the view shown before this one.
  defp do_perform(state, :last_view, _) do
    if state.last.view && Map.has_key?(state.db.views, state.last.view),
      do: State.switch_view(state, state.last.view),
      else: State.error(state, "No previous view")
  end

  defp do_perform(state, :filter_view, _),
    do: CategoryScreens.open_picker(state, {:filter, :view}, nil)

  defp do_perform(state, :sort_view, _), do: SortBox.open(state, :view)

  defp do_perform(state, :filter_section, %{sidx: sidx}),
    do: CategoryScreens.open_picker(state, {:filter, {:section, sidx}}, nil)

  defp do_perform(state, :sort_section, %{sidx: sidx}), do: SortBox.open(state, {:section, sidx})

  defp do_perform(state, :section_props, %{sidx: sidx}),
    do: Agendum.TUI.SectionBox.open(state, sidx)

  # a view that sorts its sections shows them in that order whatever their
  # place (View Properties ▸ Section sorting)
  defp do_perform(state, :section_move, %{sidx: sidx}) do
    if State.view(state).section_sort == :none,
      do: Agendum.TUI.SectionMove.open(state, sidx),
      else: State.error(state, "This view sorts its sections; set Section sorting to None first")
  end

  defp do_perform(state, :unmark_all, _) do
    state |> State.change_db(Core.unmark_all(state.db)) |> State.info("All items unmarked")
  end

  defp do_perform(state, :add_category, _),
    do: Prompts.prompt(state, "New category name (under MAIN):", :add_category)

  defp do_perform(state, :recalc, _) do
    state
    |> State.change_db(Core.reassign_all(state.db, State.context(state)))
    |> State.info("Automatic assignments recalculated")
  end

  defp do_perform(state, :add_view, _), do: Prompts.prompt(state, "Name of new view:", :add_view)

  defp do_perform(state, :browse, _), do: Agendum.TUI.Browse.open(state)
  defp do_perform(state, :show_schedule, _), do: Agendum.TUI.ScheduleBox.open(state)

  defp do_perform(state, :view_props, _) do
    if State.view(state).datebook,
      do: Agendum.TUI.DatebookBox.open(state, state.view_id),
      else: State.error(state, "A standard view's settings are in View ▸ Hide, Filter and Order")
  end

  defp do_perform(state, :rename_view, _),
    do: Prompts.prompt(state, "Rename view to:", :rename_view, State.view(state).name)

  defp do_perform(state, :discard_view, _) do
    Prompts.confirm(
      state,
      "Discard view #{State.view(state).name}? Items and categories are kept.",
      {:discard_view, state.view_id}
    )
  end

  # the new section gets the columns of the one the cursor is in (R55)
  defp do_perform(state, :section_below, row) do
    from = section_index(state, row)
    CategoryScreens.open_picker(state, {:add_section, from + 1, max(from, 0)}, nil)
  end

  defp do_perform(state, :section_above, row) do
    from = max(section_index(state, row), 0)
    CategoryScreens.open_picker(state, {:add_section, from, from}, nil)
  end

  defp do_perform(state, :remove_section, %{sidx: sidx}) do
    State.change_db(state, Core.remove_section(state.db, state.view_id, sidx))
  end

  defp do_perform(state, :collapse_section, %{sidx: sidx}) do
    %{
      State.change_db(state, Core.toggle_section_collapsed(state.db, state.view_id, sidx))
      | cursor_key: {:section, sidx}
    }
  end

  # a new column goes into the section the cursor is in, and into the
  # others as File ▸ Properties says (R55; all sections for now)
  defp do_perform(state, :column_right, row),
    do:
      CategoryScreens.open_picker(
        state,
        {:add_column, {sidx(row), beside(state, :right_of)}},
        nil
      )

  defp do_perform(state, :column_left, row),
    do:
      CategoryScreens.open_picker(state, {:add_column, {sidx(row), beside(state, :left_of)}}, nil)

  # the Column Add box: its own Position and Insert in (R55)
  defp do_perform(state, :column_add, row), do: ColumnAddBox.open(state, sidx(row), state.col)

  defp do_perform(state, :remove_column, _) do
    with_column(state, fn at ->
      # a column linked into other sections: which to remove it from (R55)
      if View.in_other_sections?(State.view(state), at),
        do: State.push(state, %{type: :choice, kind: :remove_column, at: at, cursor: 0}),
        else: remove_column(state, at, :section)
    end)
  end

  # on the item text (a section head or an item): the item column's (R55)
  defp do_perform(state, :column_width, row) when row != nil and state.col == 0 do
    if State.view(state).datebook,
      do: State.error(state, "A datebook view's item text fills the width its columns leave"),
      else: ColumnWidth.open(state, {:items, row.sidx})
  end

  defp do_perform(state, :column_width, _),
    do: with_column(state, &ColumnWidth.open(state, {:column, &1}))

  # on the item text: the item column among the columns (R55)
  defp do_perform(state, :column_move, row) when row != nil and state.col == 0 do
    if State.view(state).datebook,
      do: State.error(state, "A datebook view's item text stays first"),
      else: Agendum.TUI.ColumnMove.open(state, row.sidx, :items)
  end

  defp do_perform(state, :column_move, _),
    do:
      with_column(state, fn {sidx, index} -> Agendum.TUI.ColumnMove.open(state, sidx, index) end)

  defp do_perform(state, {:toggle_view, option}, _),
    do: State.change_db(state, Core.toggle_view_option(state.db, state.view_id, option))

  defp do_perform(state, _action, _row), do: State.error(state, "Highlight an item first")

  defp section_index(state, nil), do: length(State.view(state).sections) - 1
  defp section_index(_state, row), do: row.sidx

  defp sidx(nil), do: 0
  defp sidx(row), do: row.sidx

  @doc """
  Where a column added right or left of the highlight goes: beside the
  item column or the highlighted column, as Agenda's Position says (R55).
  """
  def beside(state, side), do: {side, if(state.col == 0, do: :items, else: state.col - 1)}

  @doc """
  Removes the column at `at` from its section only or from all (R55); the
  highlight moves to the column on its left.
  """
  def remove_column(state, at, from) do
    %{
      State.change_db(state, Core.remove_column(state.db, state.view_id, at, from))
      | col: state.col - 1
    }
  end

  # Does `fun` with the place of the highlighted column, or says to highlight one.
  defp with_column(state, fun) do
    case Layout.current_column(state) do
      nil -> State.error(state, "Highlight a column first (use → or TAB)")
      {_column, at} -> fun.(at)
    end
  end
end
