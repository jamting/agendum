defmodule Agendum.TUI.Render.Note do
  @moduledoc """
  The full-screen note editor (F5). Pure.
  """

  alias Agendum.TUI.{Terminal.Draw, State, Typing.TextEdit}

  @doc """
  The note's lines, scrolled to the cursor: a search match highlighted,
  or the region F7 marked (R63).
  """
  def lines(state, mode) do
    edit = mode.edit
    visible = State.body_height(state)
    top = max(edit.row - visible + 1, 0)
    region = TextEdit.region(edit)

    edit.lines
    |> Enum.with_index()
    |> Enum.map(fn {text, row} -> line(text, row, edit, region, Map.get(mode, :match)) end)
    |> Enum.drop(top)
  end

  defp line(text, row, _edit, _region, {row, col, len}) do
    {before, rest} = String.split_at(text, col)
    {found, after_} = String.split_at(rest, len)
    [{:normal, " " <> before}, {:edit_cursor, found}, {:normal, after_}]
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
    [{:normal, " " <> before}, {:edit, marked}, {:normal, after_}]
  end

  defp line(text, row, %{row: row} = edit, _region, _match),
    do: [{:normal, " "}] ++ Draw.field(text, edit.col, :normal)

  defp line(text, _row, _edit, _region, _match), do: [{:normal, " " <> text}]
end
