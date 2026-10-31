# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Typing.Wrap do
  @moduledoc """
  Word wrap in the note editor and in an item's text being typed in a view
  (R21), for the screen only: a line of a note, or an item, that is wider
  than its room is shown on as many rows as it needs, and no line break
  goes into the text. A row ends after the rightmost space
  that fits (the space stays at the end of the row); a word wider than
  the screen is broken at its edge.

  A row is `{start, length}`: where it starts in the line and how many
  characters it shows. Rows are as wide as the screen in columns, so a
  wide character (CJK, emoji) takes two (`Agendum.TUI.Terminal.Width`). The cursor's column `col` in the line is on the
  row it starts, so a column where one row ends and the next begins is
  shown at the start of the next. Pure.
  """

  alias Agendum.TUI.Terminal.Width

  @type row :: {non_neg_integer, non_neg_integer}

  @doc """
  How wide a note's text is wrapped: the screen less the margin on the
  left and a column for the cursor at the end of a line.
  """
  @spec width(Agendum.TUI.State.t()) :: pos_integer
  def width(state), do: max(state.width - 2, 1)

  @doc """
  How wide an item's text being typed is wrapped, in an item text `width`
  wide: a column less, for the cursor at the end of a full last row.
  """
  @spec item_width(pos_integer) :: pos_integer
  def item_width(width), do: max(width - 1, 1)

  @doc """
  The rows of `line` on a screen `width` characters wide. A row holds up
  to `width` characters, or one more when it ends in the space it wraps
  at (that space may hang over the right edge, where the end-of-line
  cursor goes on the last row). Always at least one row.
  """
  @spec rows(String.t(), pos_integer) :: [row]
  def rows(line, width) do
    line
    |> String.graphemes()
    |> Enum.map(&{&1, Width.of(&1)})
    |> rows(0, max(width, 1), [])
  end

  # `chars` are the graphemes left, each with its width in columns
  defp rows(chars, start, width, acc) do
    count = length(chars)
    fit = fitting(chars, width, 0)

    if fit == count do
      Enum.reverse([{start, count} | acc])
    else
      # the rightmost space among the characters that fit and the one
      # after them (a space there may hang over the edge), if any
      window = Enum.take(chars, fit + 1)
      space = window |> Enum.reverse() |> Enum.find_index(&(elem(&1, 0) == " "))
      # with no space, the row breaks at the edge: at least one character,
      # so a wide one on a one-column screen still moves on
      len = if space, do: fit + 1 - space, else: max(fit, 1)

      case {Enum.drop(chars, len), space} do
        # a wide character forced onto a row too narrow for it was the
        # last: no empty row after it (after a hanging space there is one,
        # for the cursor at the line's end)
        {[], nil} -> Enum.reverse([{start, len} | acc])
        {rest, _} -> rows(rest, start + len, width, [{start, len} | acc])
      end
    end
  end

  # how many of the first characters fit in `room` columns
  defp fitting([{_, w} | rest], room, n) when w <= room, do: fitting(rest, room - w, n + 1)
  defp fitting(_chars, _room, n), do: n

  @doc """
  The rows of `line` in screen columns, for cutting its drawing: where
  each row starts and how wide it is, a wide character counting two. The
  same as `rows` when every character is one column wide.
  """
  @spec in_columns(String.t(), [row]) :: [row]
  def in_columns(line, rows) do
    if Width.of(line) == String.length(line) do
      rows
    else
      # `Enum.scan` gives the running sums: the column each character
      # ends at, so the column before character `i` is the sum before it
      ends = line |> String.graphemes() |> Enum.map(&Width.of/1) |> Enum.scan(&+/2)
      at = List.to_tuple([0 | ends])

      Enum.map(rows, fn {start, len} ->
        {elem(at, start), elem(at, start + len) - elem(at, start)}
      end)
    end
  end

  @doc "The index of the row the column `col` is on."
  @spec locate([row], non_neg_integer) :: non_neg_integer
  def locate(rows, col) do
    rows
    |> Enum.with_index()
    |> Enum.reduce(0, fn {{start, _len}, i}, found -> if start <= col, do: i, else: found end)
  end

  @doc """
  The last column the cursor can be on in row `i`: the line's end on the
  last row; on the others the row's last character (one further is the
  start of the next row).
  """
  @spec row_end([row], non_neg_integer) :: non_neg_integer
  def row_end(rows, i) do
    {start, len} = Enum.at(rows, i)
    if i == length(rows) - 1, do: start + len, else: start + len - 1
  end

  @doc "The column `x` characters into row `i`, or that row's end if it is shorter."
  @spec column([row], non_neg_integer, non_neg_integer) :: non_neg_integer
  def column(rows, i, x) do
    {start, _len} = Enum.at(rows, i)
    min(start + x, row_end(rows, i))
  end
end
