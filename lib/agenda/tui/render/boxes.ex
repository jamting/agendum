defmodule Agenda.TUI.Render.Boxes do
  @moduledoc """
  The boxes drawn over the screen: their place, title and content. The
  category lists and Category Properties are in `Agenda.TUI.Render.CategoryBoxes`.
  Pure.
  """

  alias Agenda.Core.DateFormat
  alias Agenda.TUI.{Completion, Draw, State}
  alias Agenda.TUI.Render.{CategoryBoxes, View}

  # A box opened from another box (`depth` 1, 2 …) sits a line lower and
  # two columns right of the box beneath (`beneath`, that box's left
  # column; nil for the first box, which is centred), so the one beneath
  # still shows, whatever their widths; the titles of the boxes beneath
  # are dimmed, the active box's is not.
  @doc "Draws the box of `mode` over `body`; also returns the column it starts at."
  def overlay(state, mode, depth, active?, body, beneath \\ nil) do
    inner = box_width(state, mode)
    top = 1 + depth
    max_rows = max(State.body_height(state) - 4 - depth, 3)
    content = box_content(state, mode, inner, max_rows)
    box = Draw.box(box_title(state, mode), content, inner, footer(mode, inner))
    box = if active?, do: box, else: Enum.map(box, &Draw.paint(&1, %{box_title: :box_title_dim}))
    wanted = if beneath, do: beneath + 2, else: div(state.width - inner - 2, 2)
    left = min(wanted, max(state.width - inner - 2, 0))

    body =
      body
      |> Draw.overlay(box, top, left)
      |> Draw.shadow(top, left, length(box), inner + 2)

    {body, left}
  end

  @doc """
  The highlighted value of the box on top, as shown: `Agenda.TUI.BoxChoices`
  reads a setting's choices with it.
  """
  @spec selected_value(State.t()) :: String.t()
  def selected_value(state) do
    state
    |> selected_line()
    |> Enum.filter(&(elem(&1, 0) == :box_selected))
    |> Enum.map_join(&elem(&1, 1))
    |> String.trim()
  end

  @doc """
  The name of the highlighted setting: the words before its value on its
  line ("Date format" in " Date format : YYYYMMDD"), after anything to the
  left of it in a box of two columns.
  """
  @spec selected_name(State.t()) :: String.t()
  def selected_name(state) do
    before =
      state
      |> selected_line()
      |> Enum.take_while(&(elem(&1, 0) != :box_selected))
      |> Enum.map_join(&elem(&1, 1))

    # without its colon, the last piece after a gap of two spaces or more
    before
    |> String.trim_trailing()
    |> String.trim_trailing(":")
    |> String.split(~r/\s{2,}/, trim: true)
    |> List.last("")
    |> String.trim()
  end

  defp selected_line(state) do
    mode = State.mode(state)

    state
    |> box_content(mode, box_width(state, mode), State.body_height(state))
    |> Enum.find([], fn line -> Enum.any?(line, &(elem(&1, 0) == :box_selected)) end)
  end

  # Agenda's words in the bottom edge (screenshots 130, 138, 144): how to
  # finish the box. A short form when the long one does not fit.
  @done {"Press ENTER when done, ESC to cancel", "ENTER done · ESC cancel"}
  @accept {"Press ENTER to accept, ESC to cancel", "ENTER accept · ESC cancel"}
  @esc_done {"Press ESC when done", "ESC when done"}

  # settings boxes, and the boxes that act on ENTER
  @done_boxes [
    :column_add,
    :range_filter,
    :action_box,
    :execute,
    :schedule,
    :search_box,
    :note_search
  ]
  # boxes to choose one thing in
  @accept_boxes [:goto, :copy_items, :calendar, :select_file, :choice, :scope, :choice_list]
  # pickers where ENTER cycles a category's choice and ESC finishes
  @esc_pickers [:filter, :condition, :also_assign, :excludes, :schedule_filter]

  defp footer(mode, inner) do
    {long, short} =
      cond do
        Agenda.TUI.BoxCancel.cancels?(mode.type) or mode.type in @done_boxes -> @done
        mode.type == :picker and esc_picker?(mode.purpose) -> @esc_done
        mode.type in [:picker | @accept_boxes] -> @accept
        true -> {"", ""}
      end

    if String.length(long) + 2 <= inner - 2, do: long, else: short
  end

  defp esc_picker?(purpose) when is_tuple(purpose), do: elem(purpose, 0) in @esc_pickers
  defp esc_picker?(_purpose), do: false

  # the calendar is a small box, as in Agenda; the others share one width
  defp box_width(state, %{type: :calendar}), do: min(state.width - 8, 30)

  defp box_width(state, %{type: type})
       when type in [:numeric_functions, :copy_items, :choice_list],
       do: min(state.width - 8, 32)

  # File Properties and Column Properties have Agenda's two columns of
  # settings side by side (screenshots 130, 127)
  defp box_width(state, %{type: type})
       when type in [:file_props, :column_props, :column_add, :item_column, :props],
       do: min(state.width - 8, 72)

  defp box_width(state, _mode), do: min(state.width - 8, 60)

  defp box_title(_state, %{type: :calendar} = mode), do: Agenda.TUI.CalendarBox.title(mode)

  defp box_title(state, %{type: :picker, purpose: purpose}), do: picker_title(state, purpose)

  defp box_title(_state, %{type: :item_props}), do: "Item properties"
  defp box_title(_state, %{type: :choice_list, title: ""}), do: "Choices"
  defp box_title(_state, %{type: :choice_list, title: title}), do: "Choices: " <> title

  defp box_title(_state, %{type: :group_profile, item_ids: ids}),
    do: "Assignments: #{Draw.count(length(ids), "marked item")}"

  defp box_title(_state, %{type: :scope}), do: "Marked items"
  defp box_title(_state, %{type: :alarm_list}), do: "Alarm list"
  defp box_title(_state, %{type: :search_box, scope: :view}), do: "Search this view"
  defp box_title(_state, %{type: :note_search}), do: "Search/Replace in note"
  defp box_title(_state, %{type: :file_props}), do: "File properties"
  defp box_title(_state, %{type: :date_settings}), do: "Global date settings"
  defp box_title(_state, %{type: :display_format}), do: "Display format"
  defp box_title(_state, %{type: :input_format}), do: "Input format (yours, for every file)"
  defp box_title(_state, %{type: :customize}), do: "Customize (yours, for every file)"
  defp box_title(_state, %{type: :calendars}), do: "Calendars"

  defp box_title(_state, %{type: :auto_assign}), do: "Auto-assign settings"

  defp box_title(state, %{type: :category_match, cat_id: id}),
    do: "Advanced settings: " <> state.db.categories[id].name

  defp box_title(state, %{type: :date_rule, cat_id: id}),
    do: "Advanced settings: " <> state.db.categories[id].name

  defp box_title(_state, %{type: :questions}), do: "Suggested assignments"
  defp box_title(_state, %{type: :goto}), do: "Go to section"

  defp box_title(_state, %{type: :execute}), do: "Execute conditions and actions"

  defp box_title(state, %{type: :action_box} = mode) do
    kind = if Agenda.TUI.ActionBox.numeric?(state, mode), do: "Numeric", else: "Date"
    "#{kind} action: #{state.db.categories[mode.target].name}"
  end

  defp box_title(state, %{type: :range_filter} = mode) do
    kind = if Agenda.TUI.RangeFilterBox.numeric?(state, mode), do: "Numeric", else: "Date"
    what = if match?({:condition, _}, mode.purpose), do: "condition", else: "filter"
    "#{kind} #{what}: #{state.db.categories[mode.cat_id].name}"
  end

  # the column's head is the box's first row, as in Agenda (screenshot 142)
  defp box_title(_state, %{type: :column_props}), do: "Column Properties"

  defp box_title(state, %{type: :section_props} = mode),
    do: Agenda.TUI.SectionBox.title(state, mode)

  defp box_title(_state, %{type: :numeric_functions}), do: "Select Numeric Functions"
  defp box_title(_state, %{type: :copy_items}), do: "Copy"

  defp box_title(_state, %{type: :column_add}), do: "Column Add"
  defp box_title(_state, %{type: :item_column}), do: "Item Column Properties"

  defp box_title(_state, %{type: :search_box, scope: :file}),
    do: "Search the whole file (Show View)"

  defp box_title(_state, %{type: :sort, scope: :view}), do: "Sort items in all sections"

  defp box_title(state, %{type: :sort, scope: {:section, i}}),
    do: "Sort items in #{section_name(state, i)}"

  defp box_title(state, %{type: :profile, item_id: id}),
    do: "Assignments: " <> String.slice(state.db.items[id].text, 0, 40)

  defp box_title(state, %{type: :choice, kind: :move, cat_id: id}),
    do: "Moving #{state.db.categories[id].name} creates a conflict"

  defp box_title(_state, %{type: :choice, kind: :view_type, name: name}), do: "New view: #{name}"
  defp box_title(_state, %{type: :choice, kind: :make_item}), do: "Make item (ALT-F7)"
  defp box_title(_state, %{type: :choice, kind: :clip, action: :copy}), do: "Copy (F3)"
  defp box_title(_state, %{type: :choice, kind: :clip, action: :cut}), do: "Cut (F4)"
  defp box_title(_state, %{type: :choice, kind: :clip, action: :delete}), do: "Delete (ALT-F4)"

  defp box_title(state, %{type: :choice, kind: :remove_column, at: {sidx, index}}) do
    column = state |> State.view() |> Agenda.Core.View.columns(sidx) |> Enum.at(index)
    "Remove column: #{state.db.categories[column.category_id].name}"
  end

  defp box_title(_state, %{type: :schedule}), do: "Show Schedule"
  defp box_title(_state, %{type: :macros}), do: "Macros"

  defp box_title(state, %{type: :select_file} = mode),
    do: Agenda.TUI.SelectFile.title(mode, box_width(state, mode))

  defp box_title(state, %{type: :macro_props} = mode),
    do: Agenda.TUI.MacroProps.title(state, mode)

  defp box_title(state, %{type: :choice, kind: :learn, macro_id: id}),
    do: "Learn: #{state.db.macros[id].name}"

  defp box_title(state, %{type: :datebook_props} = mode),
    do: Agenda.TUI.DatebookBox.title(state, mode)

  defp box_title(state, %{type: :choice, kind: :type, cat_id: id}),
    do: "Category type: #{state.db.categories[id].name}"

  defp box_title(state, %{type: :choice, cat_id: id}),
    do: "Make children of #{state.db.categories[id].name} mutually exclusive"

  defp box_title(state, %{type: :props, cat_id: id}),
    do: "Category properties: " <> state.db.categories[id].name

  # one title per picker purpose
  defp picker_title(_state, {:add_section, _, _}),
    do: "Section head"

  defp picker_title(_state, {:change_section, _}),
    do: "Change section head"

  defp picker_title(_state, {:column_head, _}), do: "Column Head: select a category"
  defp picker_title(_state, {:make_category, name}), do: "Parent of the new category #{name}"
  defp picker_title(_state, :column_add), do: "Column Head: select a category"

  defp picker_title(_state, {:add_column, _}),
    do: "Column head"

  defp picker_title(state, {:assign_column, _, head}),
    do: "Choose " <> state.db.categories[head].name

  defp picker_title(_state, {:new_view, name}),
    do: "First section for view #{name}"

  defp picker_title(_state, {:schedule, :date_category}),
    do: "Date category of the schedule"

  defp picker_title(_state, {:schedule, :section}),
    do: "Section head of the schedule"

  defp picker_title(_state, {:schedule_filter, _}),
    do: "Filter the schedule"

  defp picker_title(_state, {:datebook, _view, :date_category}),
    do: "Date category (a date category)"

  defp picker_title(_state, {:datebook, _view, :end_category}),
    do: "End category (a date category)"

  defp picker_title(_state, {:datebook, _view, :section_category}),
    do: "Section (the head of every section)"

  defp picker_title(state, {:move_category, id}),
    do: "New parent for " <> state.db.categories[id].name

  defp picker_title(state, {:also_assign, id}),
    do: "Actions for items joining #{state.db.categories[id].name}"

  defp picker_title(state, {:excludes, id}),
    do: "Categories that may not share items with #{state.db.categories[id].name}"

  defp picker_title(_state, {:assign_items, [_]}),
    do: "Assign the item to"

  defp picker_title(_state, {:assign_items, ids}),
    do: "Assign #{Draw.count(length(ids), "marked item")} to"

  defp picker_title(state, {:condition, id}),
    do: "Conditions for #{state.db.categories[id].name}"

  defp picker_title(_state, {:filter, :view}),
    do: "Filter the view"

  defp picker_title(state, {:filter, {:section, i}}),
    do: "Filter the #{section_name(state, i)} section"

  defp picker_title(_state, {:sort_category, _, _}),
    do: "Sort by the children of"

  defp picker_title(_state, {:sort_note, _, _}),
    do: "Choose the category whose notes to sort by"

  defp picker_title(_state, :execute_root),
    do: "Apply the conditions of this category and its children"

  defp box_content(state, %{type: type} = mode, inner, max_rows)
       when type in [:picker, :profile, :group_profile, :choice, :props],
       do: CategoryBoxes.content(state, mode, inner, max_rows)

  # F3 on a setting (`Agenda.TUI.BoxChoices`): its choices, one a line
  defp box_content(_state, %{type: :choice_list} = mode, _inner, max_rows) do
    top = max(mode.cursor - max_rows + 1, 0)

    mode.labels
    |> Enum.with_index()
    |> Enum.drop(top)
    |> Enum.take(max_rows)
    |> Enum.map(fn {label, i} ->
      [{:box, " "}, {if(i == mode.cursor, do: :box_selected, else: :box), label}]
    end)
  end

  defp box_content(state, %{type: :alarm_list} = mode, inner, _max_rows) do
    rows = Agenda.TUI.AlarmList.rows(state)
    cursor = min(mode.cursor, max(length(rows) - 1, 0))

    lines =
      rows
      |> Enum.with_index()
      |> Enum.map(fn {{kind, id}, i} ->
        item = state.db.items[id]

        when_text =
          case kind do
            :current ->
              at = NaiveDateTime.add(Agenda.Core.when_at(item), -item.alarm_minutes * 60)
              "rings " <> DateFormat.datetime(at, state.db.date_format)

            :past ->
              "rang " <>
                DateFormat.time(NaiveDateTime.to_time(item.alarm_rung_at), state.db.date_format)
          end

        text = Draw.pad(item.text, max(inner - 28, 10))

        {kind,
         [
           {:box, " "},
           {if(i == cursor, do: :box_selected, else: :box), text},
           {:box, " " <> when_text}
         ]}
      end)

    current = for {:current, line} <- lines, do: line
    past = for {:past, line} <- lines, do: line
    none = [[{:box, "   (none)"}]]

    [[{:box, " Current alarms"}]] ++
      if(current == [], do: none, else: current) ++
      [[], [{:box, " Past alarms today"}]] ++
      if(past == [], do: none, else: past) ++
      [[], [{:box, " DEL removes a past alarm · ALT-A cancels a current one"}]]
  end

  defp box_content(_state, %{type: :search_box} = mode, inner, _max_rows) do
    values = %{
      on: %{item: "Item text", note: "Note text", both: "Both item & note"}[mode.search.on],
      direction:
        %{forward: "Forward", backward: "Backward", beginning: "Search from beginning"}[
          mode.direction
        ],
      ignore_case: if(mode.search.ignore_case, do: "Yes", else: "No")
    }

    labels = %{
      text: "Search for",
      on: "Match on",
      direction: "Direction",
      ignore_case: "Ignore case"
    }

    rows =
      mode
      |> Agenda.TUI.SearchBox.rows()
      |> Enum.with_index()
      |> Enum.map(fn {row, i} ->
        label = [{:box, " " <> Draw.pad(labels[row], 12) <> ": "}]

        value =
          if row == :text,
            do: Draw.input(mode.line, inner - 16, :edit),
            else: [{if(i == mode.cursor, do: :box_selected, else: :box), values[row]}]

        label ++ value
      end)

    rows ++ [[], [{:box, " Pat* finds Pat, Patty… · (a phrase) · ENTER searches"}]]
  end

  defp box_content(state, %{type: :questions} = mode, inner, _max_rows) do
    item = state.db.items[mode.item]

    cats =
      state
      |> Agenda.TUI.QuestionsBox.suggestions(mode)
      |> Enum.with_index()
      |> Enum.map(fn {cat, i} ->
        mark = if cat in mode.picked, do: "*", else: " "

        [
          {:box, " #{mark} "},
          {if(i == mode.cursor, do: :box_selected, else: :box), state.db.categories[cat].name}
        ]
      end)

    [[{:box, " " <> String.slice(item.text, 0, inner - 2)}], [], [{:box, " Assign to:"}]] ++
      cats ++ [[], [{:box, " SPACE picks · TAB picks all · ENTER assigns · ESC stops"}]]
  end

  defp box_content(state, %{type: :execute} = mode, _inner, _max_rows) do
    rows =
      state
      |> Agenda.TUI.ExecuteBox.lines(mode)
      |> Enum.with_index()
      |> Enum.map(fn {{label, value}, i} ->
        [
          {:box, " " <> Draw.pad(label, 20) <> ": "},
          {if(i == mode.cursor, do: :box_selected, else: :box), value}
        ]
      end)

    rows ++ [[], [{:box, " ENTER runs · on the first row: choose · SPACE changes"}]]
  end

  defp box_content(state, %{type: :action_box} = mode, inner, _max_rows) do
    rows =
      state
      |> Agenda.TUI.ActionBox.lines(mode)
      |> Enum.with_index()
      |> Enum.map(fn {{label, value}, i} ->
        label = [{:box, " " <> Draw.pad(label, 12) <> ": "}]

        case value do
          {:line, line} when i == mode.cursor -> label ++ Draw.input(line, inner - 16, :edit)
          {:line, line} -> label ++ [{:box, line.text}]
          text -> label ++ [{if(i == mode.cursor, do: :box_selected, else: :box), text}]
        end
      end)

    rows ++ [[], [{:box, " SPACE changes · ENTER applies · DEL removes · ESC cancels"}]]
  end

  defp box_content(state, %{type: :range_filter} = mode, inner, _max_rows) do
    rows =
      state
      |> Agenda.TUI.RangeFilterBox.lines(mode)
      |> Enum.with_index()
      |> Enum.map(fn {{label, value}, i} ->
        label = [{:box, " " <> Draw.pad(label, 16) <> ": "}]

        case value do
          {:line, line} when i == mode.cursor -> label ++ Draw.input(line, inner - 20, :edit)
          {:line, line} -> label ++ [{:box, line.text}]
          text -> label ++ [{if(i == mode.cursor, do: :box_selected, else: :box), text}]
        end
      end)

    rows ++ [[], [{:box, " Blank = open · ENTER applies · DEL removes · ESC cancels"}]]
  end

  defp box_content(state, %{type: :goto} = mode, _inner, max_rows) do
    names = Agenda.TUI.GoTo.names(state)
    top = max(mode.cursor - max_rows + 1, 0)

    names
    |> Enum.with_index()
    |> Enum.drop(top)
    |> Enum.take(max_rows)
    |> Enum.map(fn {name, i} ->
      [{:box, " "}, {if(i == mode.cursor, do: :box_selected, else: :box), name}]
    end)
  end

  defp box_content(state, %{type: :category_match} = mode, _inner, _max_rows) do
    rows =
      state
      |> Agenda.TUI.CategoryMatchBox.lines(mode)
      |> Enum.with_index()
      |> Enum.map(fn {{label, value}, i} ->
        [
          {:box, " " <> Draw.pad(label, 24) <> ": "},
          {if(i == mode.cursor, do: :box_selected, else: :box), value}
        ]
      end)

    rows ++ [[], [{:box, " SPACE next choice · arrows move"}]]
  end

  defp box_content(state, %{type: :auto_assign} = mode, _inner, _max_rows) do
    rows =
      state
      |> Agenda.TUI.AutoAssignBox.lines()
      |> Enum.with_index()
      |> Enum.map(fn {{label, value}, i} ->
        [
          {:box, " " <> Draw.pad(label, 24) <> ": "},
          {if(i == mode.cursor, do: :box_selected, else: :box), value}
        ]
      end)

    rows ++ [[], [{:box, " SPACE next choice · arrows move"}]]
  end

  defp box_content(state, %{type: :date_rule} = mode, _inner, _max_rows) do
    rows =
      state
      |> Agenda.TUI.DateRuleBox.lines(mode)
      |> Enum.with_index()
      |> Enum.map(fn {{label, value}, i} ->
        [
          {:box, " " <> Draw.pad(label, 23) <> ": "},
          {if(i == mode.cursor, do: :box_selected, else: :box), value}
        ]
      end)

    rows ++ [[], [{:box, " SPACE next choice · arrows move"}]]
  end

  defp box_content(state, %{type: :calendars} = mode, _inner, _max_rows) do
    rows =
      state
      |> Agenda.TUI.CalendarsBox.lines(mode)
      |> Enum.map(fn {style, text} ->
        [{if(style == :selected, do: :box_selected, else: :box), " " <> text}]
      end)

    rows ++
      [
        [],
        [{:box, " INS subscribe · ENTER read now · DEL unsubscribe"}],
        [{:box, " F how often · A how far ahead"}]
      ]
  end

  defp box_content(state, %{type: :customize} = mode, _inner, _max_rows),
    do: Agenda.TUI.CustomizeBox.content(state, mode)

  defp box_content(state, %{type: :input_format} = mode, _inner, _max_rows) do
    rows =
      state
      |> Agenda.TUI.InputFormatBox.lines()
      |> Enum.with_index()
      |> Enum.map(fn {{label, value}, i} ->
        [
          {:box, " " <> Draw.pad(label, 20) <> ": "},
          {if(i == mode.cursor, do: :box_selected, else: :box), value}
        ]
      end)

    rows ++
      [
        [],
        [{:box, " Saved in your preferences, not in this file."}],
        [{:box, " SPACE next choice · arrows move"}]
      ]
  end

  defp box_content(state, %{type: :section_props} = mode, _inner, _max_rows),
    do: Agenda.TUI.SectionBox.content(state, mode)

  defp box_content(state, %{type: :copy_items} = mode, _inner, _max_rows),
    do: Agenda.TUI.CopyBox.lines(state, mode)

  defp box_content(state, %{type: :numeric_functions} = mode, _inner, _max_rows),
    do: Agenda.TUI.NumericFunctionsBox.content(state, mode)

  defp box_content(state, %{type: :column_props} = mode, _inner, _max_rows),
    do: Agenda.TUI.ColumnBox.content(state, mode)

  defp box_content(state, %{type: :column_add} = mode, _inner, _max_rows),
    do: Agenda.TUI.ColumnAddBox.content(state, mode)

  defp box_content(state, %{type: :item_column} = mode, _inner, _max_rows),
    do: Agenda.TUI.ItemColumnBox.content(state, mode)

  defp box_content(state, %{type: :file_props} = mode, _inner, _max_rows),
    do: Agenda.TUI.FileProperties.content(state, mode)

  defp box_content(state, %{type: type} = mode, _inner, _max_rows)
       when type in [:date_settings, :display_format] do
    rows =
      state
      |> Agenda.TUI.FileProperties.lines(type)
      |> Enum.with_index()
      |> Enum.map(fn {{label, value}, i} ->
        [
          {:box, " " <> Draw.pad(label, 21) <> ": "},
          {if(i == mode.cursor, do: :box_selected, else: :box), value}
        ]
      end)

    # the sample under the display settings it shows
    sample =
      if type == :display_format,
        do: [
          [],
          [
            {:box,
             " " <> Draw.pad("Sample", 21) <> ": " <> DateFormat.sample(state.db.date_format)}
          ]
        ],
        else: []

    hint =
      if type == :display_format,
        do: " SPACE next choice · arrows move",
        else: " SPACE next choice or open ... · arrows move"

    rows ++ sample ++ [[], [{:box, hint}]]
  end

  defp box_content(state, %{type: :macros} = mode, _inner, max_rows) do
    rows =
      state
      |> Agenda.TUI.Macros.lines(mode)
      |> Enum.map(fn {style, text} -> [{style, " " <> text}] end)

    top = max(mode.cursor - (max_rows - 3), 0)

    Enum.drop(rows, top) ++
      [[], [{:box, " INS new · F7 learn · ENTER run · F2 edit · F6 props · DEL"}]]
  end

  defp box_content(state, %{type: :select_file} = mode, _inner, max_rows) do
    rows =
      state
      |> Agenda.TUI.SelectFile.lines(mode, max_rows)
      |> Enum.map(fn {style, text} -> [{style, " " <> text}] end)

    rows ++ [[{:box, " ENTER opens · type to narrow · F7 dates · ESC back"}]]
  end

  defp box_content(state, %{type: :macro_props} = mode, _inner, _max_rows) do
    rows =
      state
      |> Agenda.TUI.MacroProps.lines(mode)
      |> Enum.with_index()
      |> Enum.map(fn {{label, value}, i} ->
        [
          {:box, " " <> Draw.pad(label, 26) <> ": "},
          {if(i == mode.cursor, do: :box_selected, else: :box), value}
        ]
      end)

    rows ++ [[], [{:box, " ENTER changes · SPACE switches Yes/No · DEL detaches"}]]
  end

  defp box_content(state, %{type: :schedule} = mode, _inner, _max_rows) do
    rows =
      state
      |> Agenda.TUI.ScheduleBox.lines(mode)
      |> Enum.with_index()
      |> Enum.map(fn {{label, value}, i} ->
        [
          {:box, " " <> Draw.pad(label, 14) <> ": "},
          {if(i == mode.cursor, do: :box_selected, else: :box), value}
        ]
      end)

    rows ++ [[], [{:box, " SPACE changes · F3 calendar · ENTER shows · ESC cancels"}]]
  end

  defp box_content(state, %{type: :datebook_props} = mode, _inner, _max_rows),
    do: Agenda.TUI.DatebookBox.content(state, mode)

  defp box_content(state, %{type: :calendar} = mode, _inner, _max_rows),
    do: Agenda.TUI.CalendarBox.lines(state, mode)

  defp box_content(_state, %{type: :note_search} = mode, inner, _max_rows) do
    rows =
      mode
      |> Agenda.TUI.NoteSearch.lines()
      |> Enum.with_index()
      |> Enum.map(fn {{label, value}, i} ->
        label = [{:box, " " <> Draw.pad(label, 19) <> ": "}]

        case value do
          {:line, line} when i == mode.cursor -> label ++ Draw.input(line, inner - 23, :edit)
          {:line, line} -> label ++ [{:box, line.text}]
          text -> label ++ [{if(i == mode.cursor, do: :box_selected, else: :box), text}]
        end
      end)

    rows ++ [[], [{:box, " Finds the text anywhere · ALT-S in the note: next one"}]]
  end

  defp box_content(state, %{type: :sort} = mode, inner, _max_rows) do
    rows =
      state
      |> Agenda.TUI.SortBox.lines(mode)
      |> Enum.with_index()
      |> Enum.map(fn {{label, value}, i} ->
        [
          {:box, " " <> Draw.pad(label, 16) <> ": "},
          {if(i == mode.cursor, do: :box_selected, else: :box),
           String.slice(value, 0, inner - 20)}
        ]
      end)

    rows ++ [[], [{:box, " SPACE changes the highlighted setting"}]]
  end

  defp box_content(_state, %{type: :scope} = mode, _inner, _max_rows) do
    options = ["Marked items (#{length(mode.marked)})", "Current item"]

    choices =
      options
      |> Enum.with_index()
      |> Enum.map(fn {label, i} ->
        [{:box, "   "}, {if(i == mode.cursor, do: :box_selected, else: :box), " #{label} "}]
      end)

    [[{:box, " " <> scope_question(mode.action)}], []] ++ choices
  end

  defp box_content(state, %{type: :item_props} = mode, inner, max_rows) do
    item = state.db.items[mode.item_id]
    rows = Agenda.TUI.ItemProperties.rows(state, mode)
    cursor = min(mode.cursor, length(rows) - 1)
    value_width = inner - 16
    assignments = Agenda.Core.item_assignments(state.db, item.id)
    entered = DateFormat.date(item.entry, state.db.date_format)

    lines =
      rows
      |> Enum.with_index()
      |> Enum.map(fn {row, i} ->
        selected = i == cursor
        # the name being typed shows on the highlighted assignment or the add row
        assign_row = row == :add or (selected and is_tuple(row))

        {label, value} =
          case row do
            :text ->
              {"Item text", item.text}

            :note ->
              {"Note",
               if(item.note == "", do: "(none)", else: item.note |> String.split("\n") |> hd())}

            :stats ->
              {"Statistics",
               "#{Draw.count(length(assignments), "category", "categories")} · entered #{entered}"}

            {kind, id} when kind in [:prerequisite, :dependent] ->
              {dependency_label(rows, row), dependency_text(state.db, id)}

            {:assigned, a} ->
              {if(a == hd(assignments), do: "Assigned to", else: ""),
               assignment_text(state, a, item)}

            :add ->
              {if(assignments == [], do: "Assigned to", else: ""),
               "(type a category name to add)"}
          end

        value_part =
          case state.edit do
            %{target: {:item_text, _}} when row == :text ->
              Draw.input(state.edit.line, value_width, :edit)

            %{target: {:assign_category, _}} when assign_row ->
              View.completion_field(state, state.edit.line, value_width)

            _ ->
              [{if(selected, do: :box_selected, else: :box), String.slice(value, 0, value_width)}]
          end

        separator = if label == "", do: "  ", else: ": "
        [{:box, " " <> Draw.pad(label, 12) <> separator}] ++ value_part
      end)

    top = max(cursor - max_rows + 1, 0)
    Enum.drop(lines, top) ++ [[], [{:box, " " <> item_props_hint(state)}]]
  end

  # One assignment in the Item Properties box: "When (2026-10-13)",
  # "Anna Lasky (c)" for a conditional one.
  defp assignment_text(%{db: db}, %{category: id}, item) when id == db.special.when do
    db.categories[id].name <>
      " (#{DateFormat.date_time(item.when, item.when_time, db.date_format)})" <>
      recurrence_note(item) <> alarm_note(item)
  end

  defp assignment_text(state, a, _item), do: assignment_text(state, a)

  # R43: the first row of each kind is labelled
  defp dependency_label(rows, {kind, _} = row) do
    cond do
      Enum.find(rows, &match?({^kind, _}, &1)) != row -> ""
      kind == :prerequisite -> "Depends on"
      true -> "Needed by"
    end
  end

  defp dependency_text(db, id) do
    item = db.items[id]
    if item.done, do: "√ " <> item.text, else: item.text
  end

  defp recurrence_note(%{recurrence: nil}), do: ""
  defp recurrence_note(%{recurrence: rule}), do: " · " <> Agenda.Core.Recurrence.describe(rule)

  defp alarm_note(%{alarm_minutes: nil}), do: ""
  defp alarm_note(%{alarm_minutes: m}), do: " · alarm #{m} min before"

  defp assignment_text(state, %{category: id, kind: :numeric, number: number}) do
    number =
      Agenda.Core.NumberFormat.format(
        number,
        %Agenda.Core.NumberFormat{},
        State.number_opts(state)
      )

    "#{state.db.categories[id].name} (#{number})"
  end

  defp assignment_text(%{db: db}, %{category: id, kind: kind, date: date}) do
    name = db.categories[id].name

    case kind do
      :date -> "#{name} (#{DateFormat.date(date, db.date_format)})"
      :conditional -> name <> " (c)"
      :explicit -> name
    end
  end

  defp item_props_hint(state) do
    case state.edit do
      %{target: {:assign_category, _}} ->
        n = length(Completion.matches(state))
        text = String.trim(state.edit.line.text)

        cond do
          text == "" -> "Type a category name"
          n == 0 -> "New category: #{text} · ENTER creates it"
          true -> "#{n} match · ENTER accepts · F8/F7 cycle · INS new"
        end

      _ ->
        "ENTER edit · DEL remove · type to assign · F3 profile"
    end
  end

  defp section_name(state, index) do
    section = Enum.at(State.view(state).sections, index)
    state.db.categories[section.category_id].name
  end

  defp scope_question(action) do
    case action do
      :done -> "Mark as done:"
      :discard -> "Discard:"
      :remove -> "Remove from this section:"
      :when -> "Set the When date of:"
      :move_item -> "Move:"
      :copy_item -> "Copy:"
      :make_assign -> "Assign to a category:"
      :profile -> "Show the assignments of:"
    end
  end
end
