defmodule Agendum.TUI.CategoryScreens.Picker do
  @moduledoc """
  The category picker: its keys and search, and what choosing a category
  does for each purpose the picker is opened for (a section, a column, a
  filter, a condition, an action, a negative link, ...). Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :accept

  alias Agendum.Core.Database
  alias Agendum.TUI.{Boxes.Box, CategoryScreens, Terminal.Draw, Typing.LineEdit, State}
  alias Agendum.TUI.CategoryScreens.Choices

  # purposes where SPACE switches a category's choice, several at a time,
  # and ENTER or ESC finishes keeping them, as Agenda's lists (ADR 0030)
  @esc_pickers [:filter, :condition, :also_assign, :excludes, :schedule_filter, :sections]

  # --- the box (`Agendum.TUI.Boxes.Box`) ---------------------------------------------------

  @impl Box
  def handle(state, mode, key), do: CategoryScreens.handle(state, mode, key)

  @impl Box
  def about(state, %{purpose: purpose} = mode)
      when is_tuple(purpose) and elem(purpose, 0) in @esc_pickers do
    """
    #{title(state, mode)}: set several categories at a time.
    Move to one with ↑ ↓ (HOME the parent, CTRL-PGUP CTRL-PGDN the siblings),
    or type the start of its name to jump there (ENTER ends the typing).
    SPACE switches the highlighted category, as the line under the list
    says. ENTER or ESC closes the list, keeping what you switched.
    """
  end

  def about(state, mode) do
    """
    #{title(state, mode)}: choose a category from the hierarchy.

    Move to it with ↑ ↓ (HOME the parent, CTRL-PGUP CTRL-PGDN the siblings),
    or type the start of its name to jump there. ENTER picks the
    highlighted category. INS makes a new one, with the name you type.
    ALT-− and ALT-= collapse and expand families.

    ESC forgets what you typed, then closes the box.
    """
  end

  # R65: the hierarchy's moves, ENTER picks, INS a new category; typing
  # finds one (in `handle/3`). F6 (PROPS) opens the highlighted category's
  # properties; in a list of several, F7 (INCLCAT) switches it as SPACE
  # does and F4 (CLRCATS) clears them all, as Agenda's (checked in Agenda
  # 2.0, 2026-10-25)
  @impl Box
  def keymap(mode) do
    several =
      if several?(mode), do: %{{:f, 7} => :toggle, {:f, 4} => :clear_all}, else: %{}

    # Section Select's F5 (CHLDRN): a parent's children instead of it
    several =
      if match?(%{purpose: {:sections, _}}, mode),
        do: Map.put(several, {:f, 5}, :children),
        else: several

    CategoryScreens.list_keymap()
    |> Map.merge(%{
      :enter => :pick,
      :insert => :new,
      :esc => :close,
      {:f, 6} => :category_props
    })
    |> Map.merge(several)
  end

  @impl Box
  def commands(mode) do
    several =
      if several?(mode),
        do: [
          {:toggle, "Switch", "Switch the category, as SPACE does"},
          {:clear_all, "Clear all", "Take every category out of the list"}
        ],
        else: []

    several =
      if match?(%{purpose: {:sections, _}}, mode),
        do: several ++ [{:children, "Children", "The parent's children as sections"}],
        else: several

    [{:pick, "Pick", "Pick the highlighted category"}, {:new, "New", "Make a new category"}] ++
      several ++
      [{:category_props, "Props", "The highlighted category's properties"}] ++
      CategoryScreens.list_commands() ++ [{:close, "Cancel", "Close (first: what was typed)"}]
  end

  defp several?(%{purpose: purpose}),
    do: is_tuple(purpose) and elem(purpose, 0) in @esc_pickers

  defp several?(_mode), do: false

  # the key each command is in `screen_key/4`
  @keys %{pick: :enter, new: :insert, close: :esc}

  @impl Box
  def run(state, mode, id) when id in [:pick, :new, :close] do
    rows = CategoryScreens.rows(state, mode)
    mode = if rows == [], do: mode, else: CategoryScreens.clamp(mode, rows)
    screen_key(State.put_mode(state, mode), mode, rows, Map.fetch!(@keys, id))
  end

  def run(state, mode, id) when id in [:toggle, :category_props] do
    rows = CategoryScreens.rows(state, mode)
    mode = if rows == [], do: mode, else: CategoryScreens.clamp(mode, rows)
    current = CategoryScreens.current_id(rows, mode)

    case id do
      :toggle -> pick(state, mode.purpose, current)
      :category_props -> Box.category_props(state, current)
    end
  end

  def run(state, mode, :clear_all), do: clear(state, mode.purpose)

  # F5 (CHLDRN) in Section Select: each child of the highlighted category a
  # section, the category itself no longer one (User's Guide 9-8)
  def run(state, %{purpose: {:sections, view_id}} = mode, :children) do
    rows = CategoryScreens.rows(state, mode)
    mode = if rows == [], do: mode, else: CategoryScreens.clamp(mode, rows)
    parent = CategoryScreens.current_id(rows, mode)
    heads = section_heads(state, view_id)

    case parent && state.db.categories[parent].children do
      [_ | _] = children ->
        add = for c <- children, c not in heads, do: c
        state = add_sections(state, view_id, add)

        if parent in heads,
          do: remove_section(state, view_id, parent),
          else: state

      _ ->
        state
    end
  end

  def run(state, mode, id), do: CategoryScreens.run_list(state, mode, id)

  # F4 CLRCATS: every category taken out of what the list sets, one change
  defp clear(state, {:sections, view_id}) do
    count = length(state.db.views[view_id].sections)
    remove = for i <- (count - 1)..0//-1, do: {:remove_section, view_id, i}
    if remove == [], do: state, else: State.run(state, {:batch, remove})
  end

  defp clear(state, {:filter, scope}),
    do: State.run(state, {:set_filters, state.view_id, scope, []})

  defp clear(state, {:schedule_filter, _}), do: Agendum.TUI.Boxes.ScheduleBox.clear_filter(state)

  defp clear(state, {purpose, cat_id}) when purpose in [:condition, :also_assign, :excludes] do
    cat = state.db.categories[cat_id]

    commands =
      case purpose do
        :condition ->
          for {target, _} <- cat.conditions, do: {:remove_condition, cat_id, target}

        :also_assign ->
          for(target <- cat.also_assign, do: {:toggle_also_assign, cat_id, target}) ++
            for {target, _} <- cat.actions, do: {:remove_action, cat_id, target}

        :excludes ->
          for target <- cat.excludes, do: {:toggle_exclude, cat_id, target}
      end

    if commands == [], do: state, else: State.run(state, {:batch, commands})
  end

  # several categories are set at a time in some pickers: ESC ends them
  @impl Box
  def finish(%{purpose: purpose}) when is_tuple(purpose) and elem(purpose, 0) in @esc_pickers,
    do: :enter_accept

  def finish(_mode), do: :accept

  @impl Box
  def title(state, mode), do: title_for(state, mode.purpose)

  # one title per purpose
  defp title_for(_state, {:add_section, _, _}),
    do: "Section head"

  defp title_for(_state, {:change_section, _}),
    do: "Change section head"

  defp title_for(_state, :section_add_head), do: "Section head"

  defp title_for(_state, {:column_head, _}), do: "Column Head: select a category"
  defp title_for(_state, {:make_category, name}), do: "Parent of the new category #{name}"
  defp title_for(_state, :column_add), do: "Column Head: select a category"

  defp title_for(_state, {:add_column, _}),
    do: "Column head"

  defp title_for(state, {:assign_column, _, head}),
    do: "Choose " <> state.db.categories[head].name

  defp title_for(_state, {:new_view, name}),
    do: "First section for view #{name}"

  defp title_for(_state, {:schedule, :date_category}),
    do: "Date category of the schedule"

  defp title_for(_state, {:schedule, :section}),
    do: "Section head of the schedule"

  defp title_for(_state, {:schedule_filter, _}),
    do: "Filter the schedule"

  defp title_for(_state, {:datebook, _view, :date_category}),
    do: "Date category (a date category)"

  defp title_for(_state, {:datebook, _view, :end_category}),
    do: "End category (a date category)"

  defp title_for(_state, {:datebook, _view, :section_category}),
    do: "Section (the head of every section)"

  defp title_for(state, {:move_category, id}),
    do: "New parent for " <> state.db.categories[id].name

  defp title_for(state, {:also_assign, id}),
    do: "Actions for items joining #{state.db.categories[id].name}"

  defp title_for(state, {:excludes, id}),
    do: "Categories that may not share items with #{state.db.categories[id].name}"

  defp title_for(_state, {:assign_items, [_]}),
    do: "Assign the item to"

  defp title_for(_state, {:assign_items, ids}),
    do: "Assign #{Draw.count(length(ids), "marked item")} to"

  defp title_for(state, {:condition, id}),
    do: "Conditions for #{state.db.categories[id].name}"

  defp title_for(_state, {:sections, _}), do: "Section Select"

  defp title_for(_state, {:filter, :view}),
    do: "Filter the view"

  defp title_for(state, {:filter, {:section, i}}),
    do: "Filter the #{section_name(state, i)} section"

  defp title_for(_state, {:sort_category, _, _}),
    do: "Sort by the children of"

  defp title_for(_state, {:sort_note, _, _}),
    do: "Choose the category whose notes to sort by"

  defp title_for(_state, :execute_root),
    do: "Apply the conditions of this category and its children"

  defp section_name(state, index) do
    section = Enum.at(State.view(state).sections, index)
    state.db.categories[section.category_id].name
  end

  @impl Box
  # Section Select names the view first, as Agenda's ("Current View:
  # People")
  def content(state, %{purpose: {:sections, view_id}} = mode, inner, max_rows) do
    [[{:box, "   Current View: " <> state.db.views[view_id].name}]] ++
      CategoryScreens.list_lines(state, mode, inner, max_rows - 1, &marker/3)
  end

  def content(state, mode, inner, max_rows),
    do:
      CategoryScreens.list_lines(state, mode, inner, max_rows, &marker/3) ++
        [[], footer(state, mode, inner)]

  defp footer(state, mode, inner) do
    case state.edit do
      %{target: :new_pick} ->
        [{:box, " New category: "}] ++ Draw.input(state.edit.line, inner - 16, :edit)

      _ when mode.search != "" ->
        [{:box, " Search: " <> mode.search}]

      _ when elem(mode.purpose, 0) == :also_assign ->
        [{:box, " SPACE switches: + assign · - remove · none (dates, numbers: a box)"}]

      _ when elem(mode.purpose, 0) == :excludes ->
        [{:box, " SPACE switches: x may not share items"}]

      _ when elem(mode.purpose, 0) in [:condition, :filter, :schedule_filter] ->
        [{:box, " SPACE switches: + assigned · - not assigned · none"}]

      _ ->
        [{:box, " ENTER selects · INS creates · type to search"}]
    end
  end

  # the mark left of a category: what choosing it again would undo
  defp marker(state, %{purpose: {:filter, scope}}, id) do
    view = State.view(state)

    filter =
      if scope == :view, do: view.filter, else: Enum.at(view.sections, elem(scope, 1)).filter

    case List.keyfind(filter, id, 0) do
      {_, :not_assigned} -> "-"
      {_, _assigned_or_range} -> "+"
      nil -> " "
    end
  end

  defp marker(state, %{purpose: {:condition, cat_id}}, id) do
    case List.keyfind(state.db.categories[cat_id].conditions, id, 0) do
      {_, :not_assigned} -> "-"
      {_, _assigned_or_range} -> "+"
      nil -> " "
    end
  end

  defp marker(state, %{purpose: {:also_assign, cat_id}}, id) do
    cat = state.db.categories[cat_id]

    cond do
      id in cat.also_assign -> "+"
      List.keyfind(cat.actions, id, 0) in [{id, :remove}, {id, :clear}] -> "-"
      List.keymember?(cat.actions, id, 0) -> "="
      true -> " "
    end
  end

  defp marker(state, %{purpose: {:schedule_filter, _}}, id),
    do: Agendum.TUI.Boxes.ScheduleBox.filter_mark(state, id)

  defp marker(state, %{purpose: {:excludes, cat_id}}, id),
    do: if(id in state.db.categories[cat_id].excludes, do: "x", else: " ")

  # * on a section head of the view (Agenda's Section Select)
  defp marker(state, %{purpose: {:sections, view_id}}, id),
    do: if(id in section_heads(state, view_id), do: "*", else: " ")

  defp marker(_state, _mode, _id), do: " "

  @impl Box
  def keys(_state, _mode),
    do: [
      {"ENTER", "Select"},
      {"INS", "New category"},
      {"type", "Search", "Search by name"},
      {"ESC", "Cancel"}
    ]

  @impl Box
  # Agenda's words for Section Select (checked in Agenda 2.0, 2026-10-25);
  # the other pickers have none
  def help do
    %{
      sections:
        "Highlight each category for the section head(s) and press SPACE BAR. " <>
          "Press F5 to use the child categories instead of the parent."
    }
  end

  @impl Box
  def field(_state, %{purpose: {:sections, _}}), do: :sections
  def field(_state, _mode), do: nil

  # --- category picker ------------------------------------------------------------------

  @doc "Keys of the category picker."
  def screen_key(state, %{type: :picker} = mode, rows, key) do
    case key do
      :esc when mode.search != "" ->
        State.put_mode(state, %{mode | search: ""})

      :esc ->
        State.pop(state)

      # filters, conditions and actions are set several at a time (SPACE),
      # as in Agenda: ENTER first ends a name being typed to find one,
      # then closes the list keeping them
      :enter when mode.search != "" and elem(mode.purpose, 0) in @esc_pickers ->
        State.put_mode(state, %{mode | search: ""})

      :enter when elem(mode.purpose, 0) in @esc_pickers ->
        State.pop(state)

      {:char, " "} when mode.search == "" and elem(mode.purpose, 0) in @esc_pickers ->
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
    do: Agendum.TUI.Boxes.ScheduleBox.set_category(state, field, id)

  def pick(state, {:schedule_filter, _}, id),
    do: Agendum.TUI.Boxes.ScheduleBox.cycle_filter(state, id)

  # ALT-F2 MAKECAT in a note: back in the note, the category made
  def pick(state, {:make_category, name}, id),
    do: Agendum.TUI.Update.Notes.add_category(state, name, id)

  def pick(state, {:datebook, view_id, row}, id),
    do: Agendum.TUI.Boxes.DatebookSettings.set_category(state, view_id, row, id)

  # `from`: the section the cursor was in, whose linked columns the new
  # one gets (R55)
  def pick(state, {:add_section, index, from}, id) do
    index = min(index, length(State.view(state).sections))

    %{
      State.run(state, {:add_section, state.view_id, id, index, from})
      | cursor_key: {:section, index}
    }
  end

  # Section Select: SPACE makes a category a section of the view (at the
  # end, with the last section's linked columns, R55), or no longer one
  def pick(state, {:sections, view_id}, id) do
    if id in section_heads(state, view_id),
      do: remove_section(state, view_id, id),
      else: add_sections(state, view_id, [id])
  end

  # Section Add's head (F3 in the box): the box adds the section
  def pick(state, :section_add_head, id),
    do: Agendum.TUI.Boxes.SectionBox.set_new_head(state, id)

  def pick(state, {:change_section, sidx}, id) do
    %{
      State.run(state, {:set_section_category, state.view_id, sidx, id})
      | cursor_key: {:section, sidx}
    }
  end

  # the core decides its width and which sections get it (R55)
  # the highlight goes to the new column (`state.col` counts from 1)
  def pick(state, {:add_column, {sidx, place} = at}, id) do
    index = Agendum.Core.ViewColumns.insert_index(State.view(state), sidx, place)
    %{State.run(state, {:add_column, state.view_id, id, at, nil, nil}) | col: index + 1}
  end

  # Column Add ▸ Column head: back in the box, which adds it on ENTER
  def pick(state, :column_add, id), do: Agendum.TUI.Boxes.ColumnAddBox.set_head(state, id)

  # Column Properties ▸ Column head (R55): back in the box, which shows the
  # column's new head (and its kind's settings)
  def pick(state, {:column_head, at}, id),
    do: State.run(state, {:set_column_head, state.view_id, at, id})

  def pick(state, {:filter, scope}, id) do
    if Agendum.Core.RangeFilter.range_category?(state.db, id) do
      Agendum.TUI.Boxes.RangeFilterBox.open(state, scope, id)
    else
      State.run(state, {:cycle_filter, state.view_id, scope, id})
    end
  end

  def pick(state, :execute_root, id), do: Agendum.TUI.Boxes.ExecuteBox.set_root(state, id)

  def pick(state, {:sort_note, scope, index}, id),
    do: Agendum.TUI.Boxes.SortBox.set_note(state, scope, index, id)

  def pick(state, {:sort_category, scope, index}, id),
    do: Agendum.TUI.Boxes.SortBox.set_category(state, scope, index, id)

  # ALT-M (MakeAssign): one item or all marked items
  def pick(state, {:assign_items, ids}, id) do
    cond do
      Database.date_category?(state.db, id) ->
        State.error(state, "Set dates with ALT-F2 (When) or F4 (Done)")

      CategoryScreens.numeric?(state.db, id) ->
        CategoryScreens.numbers_hint(state, id)

      true ->
        noun = if length(ids) == 1, do: "Item", else: "#{length(ids)} items"
        name = state.db.categories[id].name

        State.run(
          state,
          {:batch, Enum.map(ids, &{:assign, &1, id})},
          "#{noun} assigned to #{name}"
        )
    end
  end

  def pick(state, {:assign_column, item_id, _head}, id),
    do: State.run(state, {:assign, item_id, id})

  def pick(state, {:new_view, name}, id) do
    {:ok, state, %{new: view_id}} = State.command(state, {:add_view, name, [id]})
    %{State.switch_view(state, view_id) | modes: []}
  end

  def pick(state, {:move_category, cat_id}, parent),
    do: Choices.move(state, cat_id, {:move, parent, nil})

  # ENTER on a category cycles its condition: none → assigned → not assigned
  def pick(state, {:condition, cat_id}, target) do
    if Agendum.Core.RangeFilter.range_category?(state.db, target),
      do: Agendum.TUI.Boxes.RangeFilterBox.open_condition(state, cat_id, target),
      else: cycle_condition(state, cat_id, target)
  end

  # Assignment actions (R15b): a date or numeric category opens the action
  # box; another category cycles assign → remove → none.
  def pick(state, {:also_assign, cat_id}, target) do
    cat = state.db.categories[cat_id]

    cond do
      Agendum.Core.RangeFilter.range_category?(state.db, target) ->
        Agendum.TUI.Boxes.ActionBox.open(state, cat_id, target)

      target in cat.also_assign ->
        action_result(state, State.command(state, {:set_action, cat_id, target, :remove}))

      List.keymember?(cat.actions, target, 0) ->
        State.run(state, {:remove_action, cat_id, target})

      true ->
        action_result(state, State.command(state, {:set_action, cat_id, target, :assign}))
    end
  end

  # Negative links (R9): SPACE toggles one between the two categories.
  def pick(state, {:excludes, cat_id}, target) do
    names = fn -> {state.db.categories[cat_id].name, state.db.categories[target].name} end

    case State.command(state, {:toggle_exclude, cat_id, target}) do
      {:ok, state, _} ->
        state

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

  defp action_result(_state, {:ok, state, _changes}), do: state

  defp action_result(state, {:error, :self}),
    do: State.error(state, "A category cannot act on itself")

  defp cycle_condition(state, cat_id, target) do
    case State.command(state, {:cycle_condition, cat_id, target}) do
      {:ok, state, _} ->
        State.info(state, condition_message(state.db, cat_id, target))

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

  # --- Section Select (`{:sections, view}`) -----------------------------------

  defp section_heads(state, view_id),
    do: Enum.map(state.db.views[view_id].sections, & &1.category_id)

  defp add_sections(state, _view_id, []), do: state

  defp add_sections(state, view_id, ids) do
    count = length(state.db.views[view_id].sections)

    adds =
      ids
      |> Enum.with_index(count)
      |> Enum.map(fn {id, at} -> {:add_section, view_id, id, at, max(at - 1, 0)} end)

    State.run(state, {:batch, adds})
  end

  defp remove_section(state, view_id, id) do
    case Enum.find_index(section_heads(state, view_id), &(&1 == id)) do
      nil -> state
      at -> State.run(state, {:remove_section, view_id, at})
    end
  end
end
