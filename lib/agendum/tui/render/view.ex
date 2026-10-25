defmodule Agendum.TUI.Render.View do
  @moduledoc """
  The body of a view: section heads, items with their columns, datebook
  slots and section calculations. Pure.
  """

  alias Agendum.Core.{DateFormat, ViewModel}
  alias Agendum.Core.View.Column
  alias Agendum.TUI.{Typing.Completion, Terminal.Draw, Layout, State}
  alias Agendum.TUI.Render.Text

  @doc "The view's lines, scrolled: at most a screenful (the body's height)."
  def lines(state) do
    rows = Layout.rows(state)
    editing = state.modes == [] && state.edit
    # the Zettel ids in use, once for the whole screen, to find links (R73b)
    used = Agendum.Core.zettels(state.db)

    {skipped_rows, skipped_lines} = above_screen(rows, state)

    # A `Stream` is lazy: rows are drawn only until the screen is full
    # (`Enum.take/2` below), and the rows wholly above it not at all, not
    # every row of a long view (the News view).
    rows
    |> Stream.with_index()
    |> Stream.drop(skipped_rows)
    |> Stream.flat_map(fn {row, index} ->
      # each section has its own columns, and its item text the rest (R55)
      columns = row.columns
      tw = Layout.text_width(state, row)
      selected = index == state.cursor
      lines = row_lines(state, row, index, selected, editing, {tw, used}, columns)
      lines = if selected, do: Enum.map(lines, &tint_line(&1, state.width)), else: lines

      lines =
        case editing do
          %{target: {:new_item, _, key}} when selected and key == row.key ->
            {left, right} = Enum.split(columns, Layout.items_at(row))

            lines ++
              [
                blank_cells(left) ++
                  [{:symbol, "    • "}] ++
                  Draw.input(editing.line, tw, :edit) ++ blank_cells(right)
              ]

          _ ->
            lines
        end

      lines ++ calc_lines(Map.get(row, :calcs, []), tw, row)
    end)
    |> Stream.drop(state.scroll - skipped_lines)
    |> Enum.take(State.body_height(state))
    |> first_heads_only()
  end

  # How many rows lie wholly above the screen, and their lines: their
  # heights are the ones scrolling goes by (`Layout.heights/2`). Only rows
  # before the cursor's are counted, as the cursor's row may be edited and
  # take other lines than its height.
  defp above_screen(rows, state) do
    rows
    |> Enum.take(state.cursor)
    |> Layout.heights(state)
    |> Enum.reduce_while({0, 0}, fn height, {count, lines} ->
      if lines + height <= state.scroll,
        do: {:cont, {count + 1, lines + height}},
        else: {:halt, {count, lines}}
    end)
  end

  # Hide column heads (R57): a section head line comes as
  # `{:head, with_heads, without}` when its heads may be hidden; only the
  # first on the screen (after scrolling) keeps them. `Enum.map_reduce/3`
  # carries whether that one has been seen from line to line.
  defp first_heads_only(lines) do
    lines
    |> Enum.map_reduce(false, fn
      {:head, with_heads, _without}, false -> {with_heads, true}
      {:head, _with_heads, without}, true -> {without, true}
      line, seen -> {line, seen}
    end)
    |> elem(0)
  end

  defp tint_line({:head, with_heads, without}, width),
    do: {:head, tint(with_heads, width), tint(without, width)}

  defp tint_line(line, width), do: tint(line, width)

  # The highlighted line is a lighter shade across the screen, so the eye
  # finds it when the highlight is in a column (Agenda drew a » instead).
  @tint %{
    normal: :row,
    symbol: :row,
    item: :row,
    item_done: :row_done,
    cell: :row_cell,
    section: :row_cell,
    column_head: :row_cell,
    link: :row_link,
    link_broken: :row_link_broken
  }

  defp tint([], _width), do: []
  defp tint(line, width), do: line |> Draw.paint(@tint) |> Draw.line(width, :row)

  # A datebook slot's head: its name in a line across, as Agenda drew it
  defp slot_rule(label, style, width) do
    rest = max(width - 3 - String.length(label) - 2, 0)

    Draw.line(
      [{:section, " ──"}, {style, " " <> label <> " "}, {:section, String.duplicate("─", rest)}],
      width,
      :section
    )
  end

  # A datebook slot's name (R47), in the file's date format: "10:00",
  # "Mon 2026-10-12", "Mon 2026-09-28 → Fri 2026-10-02", "October 2026".
  @weekdays ~w(Mon Tue Wed Thu Fri Sat Sun)
  @months ~w(January February March April May June July August September October November December)

  defp slot_label(state, %{kind: :time, from: from}),
    do: DateFormat.time(NaiveDateTime.to_time(from), state.db.date_format)

  defp slot_label(_state, %{kind: :month, from: from}),
    do: "#{Enum.at(@months, from.month - 1)} #{from.year}"

  defp slot_label(state, %{kind: :week, from: from, to: to}),
    do: day_label(state, from) <> " → " <> day_label(state, to)

  defp slot_label(state, %{from: day}), do: day_label(state, day)

  defp day_label(state, date) do
    format = %{
      state.db.date_format
      | day_of_week: false,
        order: plain_order(state.db.date_format.order)
    }

    Enum.at(@weekdays, Date.day_of_week(date) - 1) <> " " <> DateFormat.date(date, format)
  end

  # relative and counting formats name days, not dates; a slot needs its date
  defp plain_order(order)
       when order in [:relative, :relative_number, :day_number, :day, :week_number, :week],
       do: :yyyymmdd

  defp plain_order(order), do: order

  # A section's calculations (R29): the label under the item text, each
  # result under its column.
  defp calc_lines(calcs, tw, row) do
    Enum.map(calcs, fn {calc, cells} ->
      label = Agendum.Core.NumberFormat.label(calc)

      row.columns
      |> Enum.zip(cells)
      |> Enum.map(fn {column, cell} ->
        [{:normal, " "}, {:calc, right(cell, column.width)}] ++ percent_part(column, {:calc, ""})
      end)
      |> around_items(row, [{:normal, "      "}, {:calc, String.pad_leading(label <> " ", tw)}])
    end)
  end

  # A line's column parts (one list of segments per column) with `middle`,
  # the item text's part, among them where the item column is shown (R55):
  # after the columns left of it.
  defp around_items(per_column, row, middle) do
    {left, right} = Enum.split(per_column, Layout.items_at(row))
    Enum.concat(left) ++ middle ++ Enum.concat(right)
  end

  defp right(text, width), do: text |> String.pad_leading(width) |> Draw.pad(width)

  defp row_lines(state, %{kind: :section} = row, index, selected, editing, {tw, _used}, columns) do
    style = if selected and state.col == 0, do: :cursor, else: :section

    name_part = name_part(state, row, style, selected, editing, tw)

    heads =
      columns
      # with_index(1): column i is highlighted when state.col == i (0 is the name)
      |> Enum.with_index(1)
      |> Enum.map(fn {c, i} ->
        head_style = if selected and state.col == i, do: :cursor_cell, else: :column_head

        [
          {:normal, " "},
          {head_style, Draw.pad(ViewModel.column_head(state.db, c), c.width)}
        ] ++ percent_part(c, {:column_head, "% tot"})
      end)

    view = State.view(state)
    renaming = match?(%{target: {:rename_category, _}}, editing) and selected

    # with Section separators (R58) the head line is a rule across the
    # screen, except while its name is being typed; a datebook's slots are
    # lines already (R47)
    rule? = view.section_separators and not renaming and row.slot == nil
    draw = fn line -> if rule?, do: ruled(line, state.width), else: line end

    head = draw.(around_items(heads, row, name_part))

    # with Hide column heads (R57) the heads may give way to blanks of the
    # same width; not while one of them is highlighted
    head =
      if view.hide_column_heads and not (selected and state.col > 0),
        do: {:head, head, draw.(around_items(blank_heads(columns), row, name_part))},
        else: head

    if index == 0 or row.slot != nil or view.section_separators, do: [head], else: [[], head]
  end

  defp row_lines(
         state,
         %{kind: :item, item: item} = row,
         _index,
         selected,
         editing,
         {tw, used},
         columns
       ) do
    # Agenda's row (checked in Agenda 2.0, 2026-10-25): four spaces, the
    # item's tag (♪ in the bullet's place when it has a note), its mark (♦
    # when marked), then the text from the seventh column
    tag =
      cond do
        item.done -> "√"
        Agendum.Core.waiting?(state.db, item.id) -> "&"
        item.alarm_minutes != nil -> "@"
        item.note != "" -> "♪"
        true -> "•"
      end

    mark = if item.marked, do: "♦", else: " "
    text_style = if item.done, do: :item_done, else: :item

    text_lines =
      case editing do
        %{target: {:edit_item, id}} when id == item.id ->
          [Draw.input(editing.line, tw, :edit)]

        _ ->
          item.text
          |> Draw.wrap(tw)
          |> Enum.map(fn line ->
            if selected and state.col == 0,
              do: [{:cursor, Draw.pad(line, tw)}],
              else: line |> Draw.pad(tw) |> Text.with_links(used, text_style)
          end)
      end

    cells = item_cells(state, row, selected, editing)

    # Number items (R79): the item's number between its marks and its text
    number = Layout.number_label(row)
    marks = [{:normal, "    "}, {:symbol, tag}, {:symbol, mark}, {:normal, number}]

    [first | rest] = text_lines
    first_line = around_items(cells, row, marks ++ first)
    # a wrapped line keeps its text under the first, past the columns left
    # of it, the marks and the number
    blank = columns |> Enum.take(Layout.items_at(row)) |> blank_cells()
    indent = [{:normal, Draw.spaces(6 + String.length(number))}]
    [first_line | Enum.map(rest, &(blank ++ indent ++ &1))]
  end

  defp name_part(state, row, style, selected, editing, tw) do
    cat = row.category
    # The name part is as wide as an item line's start ("    •♦", 6) and
    # text, so each column head starts where its entries do, as in Agenda.
    # Its first column holds ♪ when the category has a note, as Agenda's
    # (checked in Agenda 2.0, 2026-10-25: "♪Göran", " Unassigned").
    note = if cat.note != "", do: {:symbol, "♪"}, else: {:normal, " "}

    case editing do
      %{target: {:rename_category, id}} when selected and id == cat.id ->
        [note] ++ Draw.input(editing.line, tw + 5, :edit)

      _ when row.slot != nil ->
        slot_rule(slot_label(state, row.slot), style, tw + 6)

      _ ->
        section = Enum.at(State.view(state).sections, row.sidx)

        suffix =
          if(row.collapsed, do: " §#{row.count}", else: "") <>
            Text.filter_text(state, section.filter)

        [note, {style, Draw.pad(cat.name <> suffix, tw + 5)}]
    end
  end

  # An item's cells, one list of segments per column: its entry (or the
  # field being typed into) and, beside a number, its "% tot".
  # A section head line as a rule (R58): the spaces before and after each
  # part become the line, the words stay, and the line runs on to the edge
  # of the screen, as in Agenda's screenshot 48.
  defp ruled(line, width) do
    parts =
      Enum.flat_map(line, fn {style, text} ->
        core = String.trim(text)
        before = String.length(text) - String.length(String.trim_leading(text))
        after_core = String.length(text) - String.length(core) - before

        if core == "",
          do: [rule(String.length(text))],
          else: [rule(before), {style, core}, rule(after_core)]
      end)

    # parts with no text (no space to turn into the line) are left out
    Enum.reject(parts ++ [rule(width - Draw.width(parts))], &(elem(&1, 1) == ""))
  end

  defp rule(n), do: {:section, String.duplicate("─", max(n, 0))}

  # a section head's column heads as blanks of the same width (R57)
  defp blank_heads(columns) do
    Enum.map(columns, fn c ->
      [{:normal, String.duplicate(" ", c.width + 1)}] ++ percent_part(c, {:normal, ""})
    end)
  end

  defp item_cells(state, %{item: item} = row, selected, editing) do
    row.columns
    |> Enum.zip(row.cells)
    |> Enum.zip(row.percents)
    |> Enum.with_index(1)
    |> Enum.map(fn {{{column, cell}, percent}, i} ->
      cell_part =
        case editing do
          %{target: {:column_entry, id, head, _}}
          when selected and id == item.id and head == column.category_id and state.col == i ->
            completion_field(state, editing.line, column.width)

          # a Category note line being typed (R56)
          %{target: {:note_line, id, head, _}}
          when selected and id == item.id and head == column.category_id and state.col == i ->
            Draw.input(editing.line, column.width, :edit)

          _ ->
            text =
              if Text.numeric?(state, column),
                do: right(cell, column.width),
                else: Draw.pad(cell, column.width)

            [{if(selected and state.col == i, do: :cursor_cell, else: :cell), text}]
        end

      [{:normal, " "} | cell_part] ++ percent_part(column, {:cell, percent || ""})
    end)
  end

  defp blank_cells(columns),
    do: Enum.flat_map(columns, &[{:normal, " "}, {:normal, Draw.spaces(Column.shown_width(&1))}])

  # A numeric column's "% tot" beside it (Display % of total, R29): a
  # space and 5 for the text, right-aligned as numbers are; nothing for a
  # column without it.
  defp percent_part(%Column{number: %{percent: true}}, {style, text}),
    do: [{:normal, " "}, {style, right(text, 5)}]

  defp percent_part(_column, _part), do: []

  @doc """
  A column cell being typed into, with the rest of the shown completion
  in grey after the cursor (\"Me\" + \"dium\").
  """
  def completion_field(state, line, width) do
    shown = Completion.shown(state)
    typed = line.text
    name = if shown, do: state.db.categories[shown].name, else: ""
    rest = String.slice(name, String.length(typed)..-1//1)

    if shown && line.pos == String.length(typed) && String.length(typed) < width && rest != "" do
      {first, after_} = String.split_at(rest, 1)
      Draw.line([{:edit, typed}, {:edit_cursor, first}, {:edit_hint, after_}], width, :edit)
    else
      Draw.input(line, width, :edit)
    end
  end
end
