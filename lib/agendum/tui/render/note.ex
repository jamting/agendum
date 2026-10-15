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

    edit.lines
    |> Enum.with_index()
    |> Enum.flat_map(fn {text, row} ->
      # the whole line styled, then cut into its rows
      styled = line(text, row, edit, region, Map.get(mode, :match))
      text |> Wrap.rows(width) |> cut(styled)
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
  The first row of the note shown: the note scrolls so that the cursor's
  row shows.
  """
  @spec top(State.t(), map) :: non_neg_integer
  def top(state, %{edit: edit}),
    do: max(screen_row(state, edit, {edit.row, edit.col}) - State.body_height(state) + 1, 0)

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

  defp line(text, row, _edit, _region, {row, col, len}) do
    {before, rest} = String.split_at(text, col)
    {found, after_} = String.split_at(rest, len)
    [{:normal, before}, {:note_match, found}, {:normal, after_}]
  end

  # an empty mark (just anchored) shows the cursor as usual
  defp line(text, row, edit, {same, same}, _match), do: line(text, row, edit, nil, nil)

  # a line the marked region covers some of
  defp line(text, row, _edit, {{r1, c1}, {r2, c2}}, _match) when row >= r1 and row <= r2 do
    from = if row == r1, do: c1, else: 0
    to = if row == r2, do: c2, else: String.length(text)
    {before, rest} = String.split_at(text, from)
    {marked, after_} = String.split_at(rest, to - from)
    # the line break inside the region shows as a marked space
    marked = if row < r2, do: marked <> " ", else: marked
    [{:normal, before}, {:edit, marked}, {:normal, after_}]
  end

  defp line(text, row, %{row: row} = edit, _region, _match),
    do: Draw.field(text, edit.col, :normal)

  defp line(text, _row, _edit, _region, _match), do: [{:normal, text}]
end
