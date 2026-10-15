defmodule Agendum.TUI.Typing.TextEdit do
  @moduledoc """
  A pure multi-line text buffer, used for notes. `mark` is where F7 MARK
  anchored a region (R63): the region runs from it to the cursor, either
  way; nil when nothing is marked.
  """

  @type position :: {non_neg_integer, non_neg_integer}
  @type t :: %__MODULE__{
          lines: [String.t()],
          row: non_neg_integer,
          col: non_neg_integer,
          mark: position | nil
        }
  defstruct lines: [""], row: 0, col: 0, mark: nil

  alias Agendum.TUI.Typing.Wrap

  @spec new(String.t()) :: t
  def new(text) do
    lines = String.split(text, "\n")
    row = length(lines) - 1
    %__MODULE__{lines: lines, row: row, col: String.length(Enum.at(lines, row))}
  end

  @spec text(t) :: String.t()
  def text(%__MODULE__{lines: lines}), do: lines |> Enum.join("\n") |> String.trim_trailing()

  @aliases %{{:ctrl, "a"} => :home, {:ctrl, "e"} => :end, {:ctrl, "d"} => :delete}

  @doc """
  A key in the text, shown word-wrapped `width` characters wide
  (`Agendum.TUI.Typing.Wrap`): ↑ ↓ move through the rows on the screen,
  keeping the column in the row; HOME and END go to the start and end of
  the row, and pressed there, of the whole line. Without a width (nil)
  every key works on whole lines.
  """
  @spec handle(t, term, pos_integer | nil) :: {:ok, t} | :unhandled
  def handle(e, key, nil), do: handle(e, key)

  def handle(%__MODULE__{} = e, key, width) do
    key = Map.get(@aliases, key, key)

    case wrapped_move(e, key, width) do
      nil -> handle(e, key)
      moved -> {:ok, moved}
    end
  end

  # the cursor's row on the screen: `i` of `rows`, `x` characters into it
  defp wrapped_move(e, key, width) when key in [:up, :down, :home, :end] do
    rows = Wrap.rows(current(e), width)
    i = Wrap.locate(rows, e.col)
    {start, _len} = Enum.at(rows, i)
    move_in_rows(e, key, rows, i, e.col - start, width)
  end

  defp wrapped_move(_e, _key, _width), do: nil

  defp move_in_rows(e, :up, rows, i, x, _width) when i > 0,
    do: %{e | col: Wrap.column(rows, i - 1, x)}

  # from the first row of a line to the last row of the line above
  defp move_in_rows(%{row: row} = e, :up, _rows, _i, x, width) when row > 0 do
    above = Wrap.rows(Enum.at(e.lines, row - 1), width)
    %{e | row: row - 1, col: Wrap.column(above, length(above) - 1, x)}
  end

  defp move_in_rows(e, :down, rows, i, x, _width) when i < length(rows) - 1,
    do: %{e | col: Wrap.column(rows, i + 1, x)}

  defp move_in_rows(%{row: row, lines: lines} = e, :down, _rows, _i, x, width)
       when row < length(lines) - 1 do
    below = Wrap.rows(Enum.at(lines, row + 1), width)
    %{e | row: row + 1, col: Wrap.column(below, 0, x)}
  end

  # HOME at the start of a row goes on to the start of the line
  defp move_in_rows(e, :home, rows, i, _x, _width) do
    {start, _len} = Enum.at(rows, i)
    %{e | col: if(e.col == start, do: 0, else: start)}
  end

  # END at the end of a row goes on to the end of the line
  defp move_in_rows(e, :end, rows, i, _x, _width) do
    row_end = Wrap.row_end(rows, i)
    %{e | col: if(e.col == row_end, do: String.length(current(e)), else: row_end)}
  end

  # ↑ on the first row of the text, ↓ on the last: as without wrapping
  defp move_in_rows(_e, _key, _rows, _i, _x, _width), do: nil

  @spec handle(t, term) :: {:ok, t} | :unhandled
  # a key that changes the text drops the mark first; moving keeps it, so
  # the cursor stretches the region
  def handle(%__MODULE__{mark: mark} = e, key)
      when mark != nil and
             (key in [:enter, :backspace, :delete, {:ctrl, "d"}] or
                (is_tuple(key) and elem(key, 0) == :char)),
      do: handle(%{e | mark: nil}, key)

  def handle(%__MODULE__{} = e, key) do
    line = current(e)

    key = Map.get(@aliases, key, key)

    case key do
      {:char, c} ->
        {before, rest} = String.split_at(line, e.col)
        {:ok, %{put(e, before <> c <> rest) | col: e.col + String.length(c)}}

      :enter ->
        {before, rest} = String.split_at(line, e.col)
        lines = e.lines |> List.replace_at(e.row, before) |> List.insert_at(e.row + 1, rest)
        {:ok, %{e | lines: lines, row: e.row + 1, col: 0}}

      :backspace when e.col > 0 ->
        {before, rest} = String.split_at(line, e.col)
        {:ok, %{put(e, String.slice(before, 0..-2//1) <> rest) | col: e.col - 1}}

      :backspace when e.row > 0 ->
        prev = Enum.at(e.lines, e.row - 1)
        lines = e.lines |> List.delete_at(e.row) |> List.replace_at(e.row - 1, prev <> line)
        {:ok, %{e | lines: lines, row: e.row - 1, col: String.length(prev)}}

      :delete ->
        {before, rest} = String.split_at(line, e.col)

        cond do
          rest != "" ->
            {:ok, put(e, before <> String.slice(rest, 1..-1//1))}

          e.row < length(e.lines) - 1 ->
            next = Enum.at(e.lines, e.row + 1)

            {:ok,
             %{
               e
               | lines:
                   e.lines |> List.delete_at(e.row + 1) |> List.replace_at(e.row, line <> next)
             }}

          true ->
            {:ok, e}
        end

      :left when e.col > 0 ->
        {:ok, %{e | col: e.col - 1}}

      :left when e.row > 0 ->
        {:ok, %{e | row: e.row - 1, col: String.length(Enum.at(e.lines, e.row - 1))}}

      :right ->
        {:ok, if(e.col < String.length(line), do: %{e | col: e.col + 1}, else: down(e, 0))}

      :up when e.row > 0 ->
        {:ok, clamp(%{e | row: e.row - 1})}

      :down ->
        {:ok, down(e, e.col)}

      :home ->
        {:ok, %{e | col: 0}}

      :end ->
        {:ok, %{e | col: String.length(line)}}

      k when k in [:left, :up, :backspace] ->
        {:ok, e}

      _ ->
        :unhandled
    end
  end

  @doc "F7 MARK: anchors a region at the cursor, or drops the one there is."
  @spec toggle_mark(t) :: t
  def toggle_mark(%__MODULE__{mark: nil} = e), do: %{e | mark: {e.row, e.col}}
  def toggle_mark(e), do: %{e | mark: nil}

  @doc "The marked region, start first (`{from, to}`, `to` not included); nil without a mark."
  @spec region(t) :: {position, position} | nil
  def region(%__MODULE__{mark: nil}), do: nil
  # tuples compare element by element, so {row, col} sort as positions do
  def region(%__MODULE__{mark: mark} = e), do: Enum.min_max([mark, {e.row, e.col}])

  @doc "The marked text, lines joined with newlines (\"\" for an empty mark, nil for none)."
  @spec marked(t) :: String.t() | nil
  def marked(e) do
    case region(e) do
      nil -> nil
      {from, to} -> e |> slice(from, to) |> elem(1)
    end
  end

  # the text before `from`, between `from` and `to`, and after `to`
  defp slice(e, {r1, c1}, {r2, c2}) do
    text = Enum.join(e.lines, "\n")
    start = offset(e, r1, c1)
    stop = offset(e, r2, c2)

    {String.slice(text, 0, start), String.slice(text, start, stop - start),
     String.slice(text, stop..-1//1)}
  end

  # the characters before a position: the lines above (each with its newline) and the column
  defp offset(e, row, col),
    do: (e.lines |> Enum.take(row) |> Enum.map(&(String.length(&1) + 1)) |> Enum.sum()) + col

  @doc "Inserts text at the cursor (F2 PASTE); it may hold newlines. The cursor ends after it."
  @spec insert(t, String.t()) :: t
  def insert(e, text) do
    line = current(e)
    {before, rest} = String.split_at(line, e.col)
    [first | more] = String.split(text, "\n")

    case more do
      [] ->
        %{put(e, before <> first <> rest) | col: e.col + String.length(first), mark: nil}

      _ ->
        last = List.last(more)
        middle = Enum.drop(more, -1)
        new = [before <> first] ++ middle ++ [last <> rest]
        lines = e.lines |> List.replace_at(e.row, new) |> List.flatten()
        %{e | lines: lines, row: e.row + length(more), col: String.length(last), mark: nil}
    end
  end

  @doc """
  The word at the cursor (letters and anything but spaces), or the one
  just before it; nil on a blank line or between words' spaces.
  """
  @spec word(t) :: String.t() | nil
  def word(e) do
    case word_span(e) do
      {from, to} -> e |> current() |> String.slice(from, to - from)
      nil -> nil
    end
  end

  # the columns the word at the cursor runs from and to (exclusive)
  defp word_span(e) do
    line = current(e)
    graphemes = String.graphemes(line)
    word_char? = fn i -> i >= 0 and i < length(graphemes) and Enum.at(graphemes, i) != " " end
    # on a word, or just after one
    at = if word_char?.(e.col), do: e.col, else: e.col - 1

    if word_char?.(at) do
      from = Enum.find(at..0//-1, &(not word_char?.(&1 - 1)))
      to = Enum.find(at..length(graphemes), &(not word_char?.(&1)))
      {from, to}
    end
  end

  @doc """
  Takes the word at the cursor (with a space beside it), its line, or all
  the text out of the buffer (ALT-F7 MAKEITM): `{text, buffer}`, or nil
  when there is nothing to take.
  """
  @spec take(t, :mark | :word | :line | :all) :: {String.t(), t} | nil
  def take(e, :mark) do
    case region(e) do
      {same, same} ->
        nil

      {{r1, c1} = from, to} ->
        {before, text, after_} = slice(e, from, to)
        e = %{new(before <> after_) | row: r1, col: c1}
        {text, e}

      nil ->
        nil
    end
  end

  def take(e, :all) do
    case text(e) do
      "" -> nil
      text -> {text, new("")}
    end
  end

  def take(e, :line) do
    case String.trim(current(e)) do
      "" ->
        nil

      text when length(e.lines) == 1 ->
        {text, new("")}

      text ->
        {text,
         clamp(%{
           e
           | lines: List.delete_at(e.lines, e.row),
             row: min(e.row, length(e.lines) - 2),
             col: 0
         })}
    end
  end

  def take(e, :word) do
    case word_span(e) do
      nil ->
        nil

      {from, to} ->
        line = current(e)
        {before, rest} = String.split_at(line, to)
        before = String.slice(before, 0, from)
        # one space goes with it: the one after, or else the one before
        {before, rest} =
          case rest do
            " " <> rest -> {before, rest}
            _ -> {String.trim_trailing(before, " "), rest}
          end

        word = String.slice(line, from, to - from)
        {word, %{put(e, before <> rest) | col: String.length(before)}}
    end
  end

  defp current(e), do: Enum.at(e.lines, e.row)
  defp put(e, line), do: %{e | lines: List.replace_at(e.lines, e.row, line)}

  defp down(e, col),
    do: if(e.row < length(e.lines) - 1, do: clamp(%{e | row: e.row + 1, col: col}), else: e)

  defp clamp(e), do: %{e | col: min(e.col, String.length(current(e)))}
end
