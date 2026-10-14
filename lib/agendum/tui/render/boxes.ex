defmodule Agendum.TUI.Render.Boxes do
  @moduledoc """
  The boxes drawn over the screen: their place, title and content. The
  category lists and Category Properties are in `Agendum.TUI.Render.CategoryBoxes`.
  Pure.
  """

  alias Agendum.Core.DateFormat
  alias Agendum.TUI.{Boxes.Box, Typing.Completion, Terminal.Draw, State}
  alias Agendum.TUI.Render.{CategoryBoxes, View}

  # boxes with a module of their own (`Agendum.TUI.Boxes.Box`) draw themselves
  @boxes Box.registry()

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
  The highlighted value of the box on top, as shown: `Agendum.TUI.Boxes.BoxChoices`
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

  # settings boxes, and the boxes that act on ENTER (the view manager too,
  # as Agenda's: ENTER shows the view, ESC goes back to the one shown)
  @done_boxes [
    :viewmgr
  ]
  # boxes to choose one thing in
  @accept_boxes [
    :goto,
    :copy_items,
    :calendar,
    :select_file,
    :choice,
    :scope,
    :choice_list,
    :confirm
  ]
  # boxes that only show something
  @return_boxes [:category_stats]
  @return {"Press ENTER or ESC to return", "ENTER/ESC return"}
  # pickers where ENTER cycles a category's choice and ESC finishes
  @esc_pickers [:filter, :condition, :also_assign, :excludes, :schedule_filter]

  defp footer(mode, inner) do
    {long, short} =
      cond do
        box = Box.module(mode) ->
          %{done: @done, accept: @accept, esc_done: @esc_done, return: @return, none: {"", ""}}[
            box.finish()
          ]

        Agendum.TUI.Boxes.BoxCancel.cancels?(mode.type) or mode.type in @done_boxes ->
          @done

        mode.type == :picker and esc_picker?(mode.purpose) ->
          @esc_done

        mode.type in [:picker | @accept_boxes] ->
          @accept

        mode.type in @return_boxes ->
          @return

        true ->
          {"", ""}
      end

    if String.length(long) + 2 <= inner - 2, do: long, else: short
  end

  defp esc_picker?(purpose) when is_tuple(purpose), do: elem(purpose, 0) in @esc_pickers
  defp esc_picker?(_purpose), do: false

  defp box_width(state, %{type: type} = mode) when is_map_key(@boxes, type),
    do: @boxes[type].width(state, mode)

  # the calendar is a small box, as in Agenda; the others share one width
  defp box_width(state, %{type: :calendar}), do: min(state.width - 8, 30)

  defp box_width(state, %{type: :category_stats}), do: min(state.width - 8, 44)
  defp box_width(state, %{type: :viewmgr}), do: min(state.width - 8, 50)

  # a question is as wide as it and its answer need, as Agenda's (and
  # wide enough for the words in its frame)
  defp box_width(state, %{type: :confirm, question: q}),
    do: (String.length(q) + 7) |> max(40) |> min(state.width - 8)

  defp box_width(state, %{type: type})
       when type in [:copy_items, :choice_list],
       do: min(state.width - 8, 32)

  # File Properties and Column Properties have Agenda's two columns of
  # settings side by side (screenshots 130, 127)
  defp box_width(state, %{type: type})
       when type in [:props],
       do: min(state.width - 8, 72)

  defp box_width(state, _mode), do: min(state.width - 8, 60)

  defp box_title(state, %{type: type} = mode) when is_map_key(@boxes, type),
    do: @boxes[type].title(state, mode)

  defp box_title(_state, %{type: :calendar} = mode), do: Agendum.TUI.Boxes.CalendarBox.title(mode)

  defp box_title(state, %{type: :picker, purpose: purpose}), do: picker_title(state, purpose)

  defp box_title(_state, %{type: :item_props}), do: "Item properties"
  defp box_title(_state, %{type: :viewmgr}), do: "View Manager"
  # a question has no title, as Agenda's
  defp box_title(_state, %{type: :confirm}), do: ""

  defp box_title(state, %{type: :category_stats, cat_id: id}),
    do: "Category statistics: " <> state.db.categories[id].name

  defp box_title(_state, %{type: :choice_list, title: ""}), do: "Choices"
  defp box_title(_state, %{type: :choice_list, title: title}), do: "Choices: " <> title

  defp box_title(_state, %{type: :group_profile, item_ids: ids}),
    do: "Assignments: #{Draw.count(length(ids), "marked item")}"

  defp box_title(_state, %{type: :scope}), do: "Marked items"
  defp box_title(_state, %{type: :alarm_list}), do: "Alarm list"
  defp box_title(_state, %{type: :calendars}), do: "Calendars"

  defp box_title(_state, %{type: :questions}), do: "Suggested assignments"
  defp box_title(_state, %{type: :goto}), do: "Go to section"

  # the column's head is the box's first row, as in Agenda (screenshot 142)

  defp box_title(_state, %{type: :copy_items}), do: "Copy"

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
    column = state |> State.view() |> Agendum.Core.View.columns(sidx) |> Enum.at(index)
    "Remove column: #{state.db.categories[column.category_id].name}"
  end

  defp box_title(_state, %{type: :macros}), do: "Macros"

  defp box_title(state, %{type: :select_file} = mode),
    do: Agendum.TUI.Boxes.SelectFile.title(mode, box_width(state, mode))

  defp box_title(state, %{type: :choice, kind: :learn, macro_id: id}),
    do: "Learn: #{state.db.macros[id].name}"

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

  defp box_content(state, %{type: type} = mode, inner, max_rows) when is_map_key(@boxes, type),
    do: @boxes[type].content(state, mode, inner, max_rows)

  defp box_content(state, %{type: type} = mode, inner, max_rows)
       when type in [:picker, :profile, :group_profile, :choice, :props],
       do: CategoryBoxes.content(state, mode, inner, max_rows)

  defp box_content(state, %{type: :viewmgr} = mode, inner, max_rows),
    do: Agendum.TUI.Render.Managers.view_box(state, mode, inner, max_rows)

  defp box_content(state, %{type: :category_stats} = mode, _inner, _max_rows),
    do: Agendum.TUI.CategoryScreens.Properties.stats_content(state, mode)

  # a Y/N question: the question, its answer highlighted after it; a long
  # question goes on over more lines
  defp box_content(_state, %{type: :confirm} = mode, inner, _max_rows) do
    answer = if mode.answer, do: "Yes", else: "No "
    lines = Draw.wrap(mode.question, inner - 7)
    {first, [last]} = Enum.split(lines, -1)

    Enum.map(first, &[{:box, " " <> &1}]) ++
      [[{:box, " " <> last <> "  "}, {:box_selected, answer}]]
  end

  # F3 on a setting (`Agendum.TUI.Boxes.BoxChoices`): its choices, one a line
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
    rows = Agendum.TUI.Boxes.AlarmList.rows(state)
    cursor = min(mode.cursor, max(length(rows) - 1, 0))

    lines =
      rows
      |> Enum.with_index()
      |> Enum.map(fn {{kind, id}, i} ->
        item = state.db.items[id]

        when_text =
          case kind do
            :current ->
              at = NaiveDateTime.add(Agendum.Core.when_at(item), -item.alarm_minutes * 60)
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

  defp box_content(state, %{type: :questions} = mode, inner, _max_rows) do
    item = state.db.items[mode.item]

    cats =
      state
      |> Agendum.TUI.Boxes.QuestionsBox.suggestions(mode)
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

  defp box_content(state, %{type: :goto} = mode, _inner, max_rows) do
    names = Agendum.TUI.Boxes.GoTo.names(state)
    top = max(mode.cursor - max_rows + 1, 0)

    names
    |> Enum.with_index()
    |> Enum.drop(top)
    |> Enum.take(max_rows)
    |> Enum.map(fn {name, i} ->
      [{:box, " "}, {if(i == mode.cursor, do: :box_selected, else: :box), name}]
    end)
  end

  defp box_content(state, %{type: :calendars} = mode, _inner, _max_rows) do
    rows =
      state
      |> Agendum.TUI.Boxes.CalendarsBox.lines(mode)
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

  defp box_content(state, %{type: :copy_items} = mode, _inner, _max_rows),
    do: Agendum.TUI.Boxes.CopyBox.lines(state, mode)

  defp box_content(state, %{type: :macros} = mode, _inner, max_rows) do
    rows =
      state
      |> Agendum.TUI.Macros.lines(mode)
      |> Enum.map(fn {style, text} -> [{style, " " <> text}] end)

    top = max(mode.cursor - (max_rows - 3), 0)

    Enum.drop(rows, top) ++
      [[], [{:box, " INS new · F7 learn · ENTER run · F2 edit · F6 props · DEL"}]]
  end

  defp box_content(state, %{type: :select_file} = mode, _inner, max_rows) do
    rows =
      state
      |> Agendum.TUI.Boxes.SelectFile.lines(mode, max_rows)
      |> Enum.map(fn {style, text} -> [{style, " " <> text}] end)

    rows ++ [[{:box, " ENTER opens · type to narrow · F7 dates · ESC back"}]]
  end

  defp box_content(state, %{type: :calendar} = mode, _inner, _max_rows),
    do: Agendum.TUI.Boxes.CalendarBox.lines(state, mode)

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
    rows = Agendum.TUI.Boxes.ItemProperties.rows(state, mode)
    cursor = min(mode.cursor, length(rows) - 1)
    value_width = inner - 16
    assignments = Agendum.Core.item_assignments(state.db, item.id)
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
  defp recurrence_note(%{recurrence: rule}), do: " · " <> Agendum.Core.Recurrence.describe(rule)

  defp alarm_note(%{alarm_minutes: nil}), do: ""
  defp alarm_note(%{alarm_minutes: m}), do: " · alarm #{m} min before"

  defp assignment_text(state, %{category: id, kind: :numeric, number: number}) do
    number =
      Agendum.Core.NumberFormat.format(
        number,
        %Agendum.Core.NumberFormat{},
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
