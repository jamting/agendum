defmodule Agenda.TUI.Render.View do
  @moduledoc """
  The body of a view: section heads, items with their columns, datebook
  slots and section calculations. Pure.
  """

  alias Agenda.Core.{DateFormat, ViewModel}
  alias Agenda.TUI.{Completion, Draw, Layout, State}
  alias Agenda.TUI.Render.Text

  @doc "The view's lines, scrolled."
  def lines(state) do
    rows = Layout.rows(state)
    editing = state.modes == [] && state.edit

    rows
    |> Enum.with_index()
    |> Enum.flat_map(fn {row, index} ->
      # each section has its own columns, and its item text the rest (R55)
      columns = row.columns
      tw = Layout.text_width(state, row)
      selected = index == state.cursor
      lines = row_lines(state, row, index, selected, editing, tw, columns)
      lines = if selected, do: Enum.map(lines, &tint(&1, state.width)), else: lines

      lines =
        case editing do
          %{target: {:new_item, _, key}} when selected and key == row.key ->
            lines ++
              [[{:symbol, " • "}] ++ Draw.input(editing.line, tw, :edit) ++ blank_cells(columns)]

          _ ->
            lines
        end

      lines ++ calc_lines(Map.get(row, :calcs, []), tw, columns)
    end)
    |> Enum.drop(state.scroll)
  end

  # The highlighted line is a lighter shade across the screen, so the eye
  # finds it when the highlight is in a column (Agenda drew a » instead).
  @tint %{
    normal: :row,
    symbol: :row,
    item: :row,
    item_done: :row_done,
    cell: :row_cell,
    section: :row_cell,
    column_head: :row_cell
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
  defp calc_lines(calcs, tw, columns) do
    Enum.map(calcs, fn {calc, cells} ->
      label = Agenda.Core.NumberFormat.label(calc)

      [{:normal, "   "}, {:calc, String.pad_leading(label <> " ", tw)}] ++
        Enum.flat_map(Enum.zip(columns, cells), fn {column, cell} ->
          [{:normal, " "}, {:calc, right(cell, column.width)}]
        end)
    end)
  end

  defp right(text, width), do: text |> String.pad_leading(width) |> Draw.pad(width)

  defp row_lines(state, %{kind: :section} = row, index, selected, editing, tw, columns) do
    cat = row.category
    style = if selected and state.col == 0, do: :cursor, else: :section

    name_part =
      case editing do
        %{target: {:rename_category, id}} when selected and id == cat.id ->
          [{:normal, " "}] ++ Draw.input(editing.line, tw + 1, :edit)

        _ when row.slot != nil ->
          slot_rule(slot_label(state, row.slot), style, tw + 2)

        _ ->
          section = Enum.at(State.view(state).sections, row.sidx)

          suffix =
            if(row.collapsed, do: " §#{row.count}", else: "") <>
              Text.filter_text(state, section.filter)

          [{:normal, " "}, {style, Draw.pad(cat.name <> suffix, tw + 1)}]
      end

    heads =
      columns
      # with_index(1): column i is highlighted when state.col == i (0 is the name)
      |> Enum.with_index(1)
      |> Enum.flat_map(fn {c, i} ->
        head_style = if selected and state.col == i, do: :cursor_cell, else: :column_head

        [
          {:normal, " "},
          {head_style,
           Draw.pad(ViewModel.column_label(state.db, c.category_id, c.width), c.width)}
        ]
      end)

    head = name_part ++ heads
    if index == 0 or row.slot, do: [head], else: [[], head]
  end

  defp row_lines(state, %{kind: :item, item: item} = row, _index, selected, editing, tw, columns) do
    symbol =
      cond do
        item.done -> "√"
        item.marked -> "♦"
        Agenda.Core.waiting?(state.db, item.id) -> "&"
        item.alarm_minutes != nil -> "@"
        true -> "•"
      end

    note = if item.note != "", do: "♪", else: " "
    text_style = if item.done, do: :item_done, else: :item

    text_lines =
      case editing do
        %{target: {:edit_item, id}} when id == item.id ->
          [Draw.input(editing.line, tw, :edit)]

        _ ->
          item.text
          |> Draw.wrap(tw)
          |> Enum.map(
            &[{if(selected and state.col == 0, do: :cursor, else: text_style), Draw.pad(&1, tw)}]
          )
      end

    cells =
      columns
      |> Enum.zip(row.cells)
      |> Enum.with_index(1)
      |> Enum.flat_map(fn {{column, cell}, i} ->
        cell_part =
          case editing do
            %{target: {:column_entry, id, head, _}}
            when selected and id == item.id and head == column.category_id and state.col == i ->
              completion_field(state, editing.line, column.width)

            _ ->
              text =
                if Text.numeric?(state, column),
                  do: right(cell, column.width),
                  else: Draw.pad(cell, column.width)

              [{if(selected and state.col == i, do: :cursor_cell, else: :cell), text}]
          end

        [{:normal, " "} | cell_part]
      end)

    [first | rest] = text_lines
    first_line = [{:symbol, " " <> symbol}, {:symbol, note}] ++ first ++ cells
    [first_line | Enum.map(rest, &([{:normal, "   "}] ++ &1))]
  end

  defp blank_cells(columns),
    do: Enum.flat_map(columns, &[{:normal, " "}, {:normal, Draw.spaces(&1.width)}])

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
