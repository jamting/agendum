# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Typing.TextEdit do
  @moduledoc """
  A pure multi-line text buffer, used for notes. `mark` is where F7 MARK
  anchored a region (R63): the region runs from it to the cursor, either
  way; nil when nothing is marked. `goal` is the column in the row on the
  screen that ↑ and ↓ keep through shorter rows (R64), with the place it
  was left at: once the cursor is anywhere else, it no longer counts.
  """

  @type position :: {non_neg_integer, non_neg_integer}
  @type t :: %__MODULE__{
          lines: [String.t()],
          row: non_neg_integer,
          col: non_neg_integer,
          mark: position | nil,
          goal: {non_neg_integer, position} | nil,
          overwrite: boolean
        }
  defstruct lines: [""], row: 0, col: 0, mark: nil, goal: nil, overwrite: false

  alias Agendum.TUI.Keymap
  alias Agendum.TUI.Typing.{LineEdit, Wrap}

  @spec new(String.t()) :: t
  def new(text) do
    lines = String.split(text, "\n")
    row = length(lines) - 1
    %__MODULE__{lines: lines, row: row, col: String.length(Enum.at(lines, row))}
  end

  @spec text(t) :: String.t()
  def text(%__MODULE__{lines: lines}), do: lines |> Enum.join("\n") |> String.trim_trailing()

  @doc """
  A key in the text, shown word-wrapped `width` characters wide
  (`Agendum.TUI.Typing.Wrap`): ↑ ↓ move through the rows on the screen,
  keeping the column in the row (through shorter rows too); HOME and END go to the start and end of
  the row, and pressed there, of the whole line. Without a width (nil)
  every key works on whole lines.
  """
  @spec handle(t, term, pos_integer | nil) :: {:ok, t} | :unhandled
  def handle(e, key, nil), do: handle(e, key)

  def handle(%__MODULE__{} = e, key, width) do
    case wrapped_move(e, Keymap.lookup(:text, key), width) do
      nil -> handle(e, key)
      moved -> {:ok, moved}
    end
  end

  # the cursor's row on the screen: `i` of `rows`, `x` characters into it;
  # ↑ and ↓ go on from the column they kept, if the cursor is where they
  # left it, and keep it again
  defp wrapped_move(e, id, width) when id in [:up, :down] do
    {rows, i, x} = place(e, width)
    x = kept(e, x)

    case move_in_rows(e, id, rows, i, x, width) do
      nil -> nil
      moved -> %{moved | goal: {x, {moved.row, moved.col}}}
    end
  end

  defp wrapped_move(e, id, width) when id in [:line_start, :line_end] do
    {rows, i, x} = place(e, width)
    move_in_rows(e, id, rows, i, x, width)
  end

  defp wrapped_move(_e, _id, _width), do: nil

  defp kept(%{goal: {goal, at}, row: row, col: col}, _x) when at == {row, col}, do: goal
  defp kept(_e, x), do: x

  defp place(e, width) do
    rows = Wrap.rows(current(e), width)
    i = Wrap.locate(rows, e.col)
    {start, _len} = Enum.at(rows, i)
    {rows, i, e.col - start}
  end

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
  defp move_in_rows(e, :line_start, rows, i, _x, _width) do
    {start, _len} = Enum.at(rows, i)
    %{e | col: if(e.col == start, do: 0, else: start)}
  end

  # END at the end of a row goes on to the end of the line
  defp move_in_rows(e, :line_end, rows, i, _x, _width) do
    row_end = Wrap.row_end(rows, i)
    %{e | col: if(e.col == row_end, do: String.length(current(e)), else: row_end)}
  end

  # ↑ on the first row of the text, ↓ on the last: as without wrapping
  defp move_in_rows(_e, _key, _rows, _i, _x, _width), do: nil

  @doc """
  A key on whole lines: a character is typed; other keys run the command
  the `:text` keymap binds them to (`Agendum.TUI.Keymap`, R65).
  """
  @spec handle(t, term) :: {:ok, t} | :unhandled
  # typed over (OVR, R64e), what is typed replaces as many characters
  # after the cursor, as far as the line goes
  def handle(%__MODULE__{} = e, {:char, c}) do
    e = %{e | mark: nil}
    {before, rest} = String.split_at(current(e), e.col)
    rest = if e.overwrite, do: String.slice(rest, String.length(c)..-1//1), else: rest
    {:ok, %{put(e, before <> c <> rest) | col: e.col + String.length(c)}}
  end

  def handle(%__MODULE__{} = e, key) do
    case Keymap.lookup(:text, key) do
      nil -> :unhandled
      id -> {:ok, run(e, id)}
    end
  end

  @doc """
  Runs a text-editing command (`Agendum.TUI.Commands`, `:text`) on whole
  lines. One that changes the text drops the mark first; moving keeps it,
  so the cursor stretches the region.
  """
  # the commands that change the text (guards need lists known when
  # compiling, so they are module attributes)
  @changing [:new_line, :delete_back, :delete, :delete_word, :delete_word_right, :delete_to_end]
  @words [:word_left, :word_right, :delete_word, :delete_word_right, :delete_to_end] ++
           [:text_start, :text_end]

  @spec run(t, atom) :: t
  def run(%__MODULE__{mark: mark} = e, id) when mark != nil and id in @changing,
    do: run(%{e | mark: nil}, id)

  # words and the ends of the note (R64e): a word as one-line fields have
  # it (`LineEdit`), a move going on to the line above or below
  def run(%__MODULE__{} = e, id) when id in @words, do: words(e, id, current(e))

  def run(%__MODULE__{} = e, id) do
    line = current(e)

    case id do
      :new_line ->
        {before, rest} = String.split_at(line, e.col)
        lines = e.lines |> List.replace_at(e.row, before) |> List.insert_at(e.row + 1, rest)
        %{e | lines: lines, row: e.row + 1, col: 0}

      :delete_back when e.col > 0 ->
        {before, rest} = String.split_at(line, e.col)
        %{put(e, String.slice(before, 0..-2//1) <> rest) | col: e.col - 1}

      :delete_back when e.row > 0 ->
        prev = Enum.at(e.lines, e.row - 1)
        lines = e.lines |> List.delete_at(e.row) |> List.replace_at(e.row - 1, prev <> line)
        %{e | lines: lines, row: e.row - 1, col: String.length(prev)}

      :delete ->
        {before, rest} = String.split_at(line, e.col)

        cond do
          rest != "" ->
            put(e, before <> String.slice(rest, 1..-1//1))

          e.row < length(e.lines) - 1 ->
            next = Enum.at(e.lines, e.row + 1)
            lines = e.lines |> List.delete_at(e.row + 1) |> List.replace_at(e.row, line <> next)
            %{e | lines: lines}

          true ->
            e
        end

      :left when e.col > 0 ->
        %{e | col: e.col - 1}

      :left when e.row > 0 ->
        %{e | row: e.row - 1, col: String.length(Enum.at(e.lines, e.row - 1))}

      :right ->
        if e.col < String.length(line), do: %{e | col: e.col + 1}, else: down(e, 0)

      :up when e.row > 0 ->
        clamp(%{e | row: e.row - 1})

      :down ->
        down(e, e.col)

      :line_start ->
        %{e | col: 0}

      :line_end ->
        %{e | col: String.length(line)}

      # ← at the very start, ↑ on the first line, BACKSPACE at the start
      _ ->
        e
    end
  end

  defp words(e, :word_left, line) do
    start = LineEdit.previous_word(line, e.col)
    blank_before? = String.trim(String.slice(line, 0, e.col)) == ""

    if blank_before? and e.row > 0 do
      above = Enum.at(e.lines, e.row - 1)
      %{e | row: e.row - 1, col: LineEdit.previous_word(above, String.length(above))}
    else
      %{e | col: start}
    end
  end

  defp words(e, :word_right, line) do
    blank_after? = String.trim(String.slice(line, e.col..-1//1)) == ""

    if blank_after? and e.row < length(e.lines) - 1 do
      below = Enum.at(e.lines, e.row + 1)
      %{e | row: e.row + 1, col: LineEdit.next_word(below, 0)}
    else
      %{e | col: LineEdit.next_word(line, e.col)}
    end
  end

  # at the start of a line the word before is across the line break:
  # BACKSPACE's joining of the lines does instead
  defp words(%{col: 0} = e, :delete_word, _line), do: run(e, :delete_back)

  defp words(e, :delete_word, line) do
    start = LineEdit.previous_word(line, e.col)
    {before, _} = String.split_at(line, start)
    {_, rest} = String.split_at(line, e.col)
    %{put(e, before <> rest) | col: start}
  end

  defp words(e, :delete_word_right, line) do
    if e.col == String.length(line) do
      run(e, :delete)
    else
      {before, _} = String.split_at(line, e.col)
      {_, rest} = String.split_at(line, LineEdit.next_word(line, e.col))
      put(e, before <> rest)
    end
  end

  defp words(e, :delete_to_end, line), do: put(e, String.slice(line, 0, e.col))
  defp words(e, :text_start, _line), do: %{e | row: 0, col: 0}

  defp words(e, :text_end, _line) do
    last = length(e.lines) - 1
    %{e | row: last, col: String.length(Enum.at(e.lines, last))}
  end

  @doc "INS (R64e): switches between inserting and typing over."
  @spec toggle_overwrite(t) :: t
  def toggle_overwrite(e), do: %{e | overwrite: not e.overwrite}

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

  @doc "The line the cursor is on."
  @spec line(t) :: String.t()
  def line(e), do: current(e)

  @doc """
  The cursor's line replaced by `text`, changed from column `at` on: a
  cursor before `at` stays where it is, one after it moves by as much as
  the line grew or shrank, so it stays on the same character; the mark
  goes, as on any change.
  """
  @spec replace_line(t, String.t(), non_neg_integer) :: t
  def replace_line(e, text, at \\ 0) do
    shift = if e.col < at, do: 0, else: String.length(text) - String.length(current(e))
    col = (e.col + shift) |> max(0) |> min(String.length(text))
    %{put(e, text) | col: col, mark: nil}
  end

  defp current(e), do: Enum.at(e.lines, e.row)
  defp put(e, line), do: %{e | lines: List.replace_at(e.lines, e.row, line)}

  defp down(e, col),
    do: if(e.row < length(e.lines) - 1, do: clamp(%{e | row: e.row + 1, col: col}), else: e)

  defp clamp(e), do: %{e | col: min(e.col, String.length(current(e)))}
end
