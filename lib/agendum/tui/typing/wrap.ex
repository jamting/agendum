defmodule Agendum.TUI.Typing.Wrap do
  @moduledoc """
  Word wrap in the note editor, for the screen only: a line of a note that
  is wider than the screen is shown on as many rows as it needs, and no
  line break goes into the text. A row ends after the rightmost space
  that fits (the space stays at the end of the row); a word wider than
  the screen is broken at its edge.

  A row is `{start, length}`: where it starts in the line and how many
  characters it shows. The cursor's column `col` in the line is on the
  row it starts, so a column where one row ends and the next begins is
  shown at the start of the next. Pure.
  """

  @type row :: {non_neg_integer, non_neg_integer}

  @doc """
  How wide a note's text is wrapped: the screen less the margin on the
  left and a column for the cursor at the end of a line.
  """
  @spec width(Agendum.TUI.State.t()) :: pos_integer
  def width(state), do: max(state.width - 2, 1)

  @doc """
  The rows of `line` on a screen `width` characters wide. A row holds up
  to `width` characters, or one more when it ends in the space it wraps
  at (that space may hang over the right edge, where the end-of-line
  cursor goes on the last row). Always at least one row.
  """
  @spec rows(String.t(), pos_integer) :: [row]
  def rows(line, width), do: line |> String.graphemes() |> rows(0, max(width, 1), [])

  defp rows(chars, start, width, acc) do
    count = length(chars)

    if count <= width do
      Enum.reverse([{start, count} | acc])
    else
      # the rightmost space among the first width + 1 characters, if any
      window = Enum.take(chars, width + 1)
      space = window |> Enum.reverse() |> Enum.find_index(&(&1 == " "))
      len = if space, do: width + 1 - space, else: width
      rows(Enum.drop(chars, len), start + len, width, [{start, len} | acc])
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
