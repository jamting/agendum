# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Render.Note do
  @moduledoc """
  The full-screen note editor (F5). A line wider than the screen is
  word-wrapped onto as many rows as it needs (`Agendum.TUI.Typing.Wrap`),
  for the screen only. Pure.
  """

  alias Agendum.TUI.{Terminal.Draw, State, Typing.TextEdit, Typing.Wrap}

  @doc """
  The note's rows on the screen, scrolled to the cursor: a search match
  highlighted, or the region F7 marked (R63).
  """
  def lines(state, mode) do
    edit = mode.edit
    width = Wrap.width(state)
    region = TextEdit.region(edit)
    # links (R73b) on the lines without the cursor, a mark or a match; and
    # Markdown's headings, lists and task boxes there, with the extras on,
    # in a note of text (not a macro's keystrokes; R64h)
    used = Agendum.Core.zettels(state.db)
    markdown? = State.markdown_note?(state, mode)
    code = if markdown?, do: Agendum.Core.markdown_code_rows(edit.lines), else: MapSet.new()

    edit.lines
    |> Enum.with_index()
    |> Enum.flat_map(fn {text, row} ->
      # the whole line styled, then cut into its rows
      # a code block's lines are only text, as on the site
      used = if markdown? and not MapSet.member?(code, row), do: {:markdown, used}, else: used
      styled = line(text, row, edit, region, Map.get(mode, :match), used)
      Wrap.in_columns(text, Wrap.rows(text, width)) |> cut(styled)
    end)
    |> Enum.drop(top(state, mode))
  end

  # each row with the margin before it; the last takes the rest, which may
  # be the cursor after the line's end or the marked line break
  defp cut(rows, styled) do
    last = length(rows) - 1

    for {{start, len}, i} <- Enum.with_index(rows) do
      part = Draw.drop(styled, start)
      [{:normal, " "} | if(i == last, do: part, else: Draw.take(part, len))]
    end
  end

  @doc """
  The first row of the note shown. The note keeps the first row it showed
  (`mode.top`) and scrolls only as far as the cursor's row needs, as an
  editor does: moving up from the bottom moves the cursor, not the note.
  A note just opened (no `top` yet) shows its end, the cursor on the
  bottom row.
  """
  @spec top(State.t(), map) :: non_neg_integer
  def top(state, %{edit: edit} = mode) do
    height = State.body_height(state)
    cursor = screen_row(state, edit, {edit.row, edit.col})
    # with no `top` yet, the lowest top that still shows the cursor
    lowest = max(cursor - height + 1, 0)

    case Map.get(mode, :top) do
      nil -> lowest
      # `top` clamped: the cursor's row at or below it, inside the screen
      top -> top |> min(cursor) |> max(lowest)
    end
  end

  @doc """
  The note with the first row it shows kept (`top/2`), so the next key
  scrolls from there; `Agendum.TUI.Update` calls it after every key for
  each note on the stack.
  """
  @spec keep_top(State.t(), map) :: map
  def keep_top(state, mode), do: %{mode | top: top(state, mode)}

  @doc """
  The row on the screen, counted from the note's first, of the column
  `col` of line `row`: the rows of the lines above, and the rows before
  it in its own line.
  """
  @spec screen_row(State.t(), TextEdit.t(), TextEdit.position()) :: non_neg_integer
  def screen_row(state, edit, {row, col}) do
    width = Wrap.width(state)

    above =
      edit.lines |> Enum.take(row) |> Enum.map(&length(Wrap.rows(&1, width))) |> Enum.sum()

    above + Wrap.locate(Wrap.rows(Enum.at(edit.lines, row), width), col)
  end

  defp line(text, row, _edit, _region, {row, col, len}, _used) do
    {before, rest} = String.split_at(text, col)
    {found, after_} = String.split_at(rest, len)
    [{:normal, before}, {:note_match, found}, {:normal, after_}]
  end

  # an empty mark (just anchored) shows the cursor as usual
  defp line(text, row, edit, {same, same}, _match, used),
    do: line(text, row, edit, nil, nil, used)

  # a line the marked region covers some of
  defp line(text, row, _edit, {{r1, c1}, {r2, c2}}, _match, _used) when row >= r1 and row <= r2 do
    from = if row == r1, do: c1, else: 0
    to = if row == r2, do: c2, else: String.length(text)
    {before, rest} = String.split_at(text, from)
    {marked, after_} = String.split_at(rest, to - from)
    # the line break inside the region shows as a marked space
    marked = if row < r2, do: marked <> " ", else: marked
    [{:normal, before}, {:edit, marked}, {:normal, after_}]
  end

  defp line(text, row, %{row: row} = edit, _region, _match, _used),
    do: Draw.field(text, edit.col, :normal)

  defp line(text, _row, _edit, _region, _match, {:markdown, used}),
    do: markdown(text, used)

  defp line(text, _row, _edit, _region, _match, used),
    do: Agendum.TUI.Render.Text.with_links(text, used, :normal)

  # Domain: the line's own text stays as typed; only its parts are coloured,
  # in styles every theme has: a heading as a section's head, a list's
  # marker and task box as a link, a done task as a done item
  defp markdown(text, used) do
    links = &Agendum.TUI.Render.Text.with_links(&1, used, &2)

    case Agendum.Core.markdown_line(text) do
      {:heading, marker, rest} ->
        [{:section, marker} | links.(rest, :section)]

      {:item, indent, marker, box, rest} when box in ["x", "X", "-"] ->
        [{:normal, indent}, {:link, marker <> "[#{box}] "} | links.(rest, :item_done)]

      {:item, indent, marker, box, rest} ->
        mark = if box, do: marker <> "[#{box}] ", else: marker
        [{:normal, indent}, {:link, mark} | links.(rest, :normal)]

      :text ->
        links.(text, :normal)
    end
    |> Enum.reject(&(elem(&1, 1) == ""))
    |> then(fn
      [] -> [{:normal, ""}]
      parts -> parts
    end)
  end
end
