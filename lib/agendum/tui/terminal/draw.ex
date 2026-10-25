defmodule Agendum.TUI.Terminal.Draw do
  @moduledoc """
  Pure helpers for building screens.

  A screen is a list of lines; a line is a list of `{style, text}`
  segments. `line/2` pads or truncates a line to an exact width so that
  every frame is a full rectangle. Styles are symbolic and mapped to colors
  by `Agendum.TUI.Terminal.Theme`.
  """

  @type segment :: {atom, String.t()}
  @type line :: [segment]

  @doc "Pads (with the style of the last segment) or truncates segments to `width`."
  @spec line([segment], non_neg_integer, atom) :: line
  def line(segments, width, fill_style \\ :normal) do
    {segments, used} =
      Enum.reduce(segments, {[], 0}, fn {style, text}, {acc, used} ->
        room = width - used

        if room <= 0 do
          {acc, used}
        else
          text = String.slice(text, 0, room)
          {[{style, text} | acc], used + String.length(text)}
        end
      end)

    segments = Enum.reverse(segments)
    if used < width, do: segments ++ [{fill_style, spaces(width - used)}], else: segments
  end

  @doc "Left-aligns text in a field of `width` characters, truncating if needed."
  @spec pad(String.t(), non_neg_integer) :: String.t()
  def pad(text, width) do
    text = String.slice(text, 0, width)
    text <> spaces(width - String.length(text))
  end

  @doc "Right-aligns text in a field."
  @spec rpad(String.t(), non_neg_integer) :: String.t()
  def rpad(text, width) do
    text = String.slice(text, 0, width)
    spaces(width - String.length(text)) <> text
  end

  @doc "Centers text in a field."
  @spec center(String.t(), non_neg_integer) :: String.t()
  def center(text, width) do
    text = String.slice(text, 0, width)
    left = div(width - String.length(text), 2)
    pad(spaces(left) <> text, width)
  end

  @doc ~S|A count with its noun, singular for one: "1 item", "2 items".|
  @spec count(integer, String.t(), String.t() | nil) :: String.t()
  def count(n, singular, plural \\ nil),
    do: "#{n} " <> if(n == 1, do: singular, else: plural || singular <> "s")

  @doc "Text cut to `width` characters, ending in … when it was longer."
  @spec truncate(String.t(), non_neg_integer) :: String.t()
  def truncate(text, width) do
    cond do
      String.length(text) <= width -> text
      width <= 1 -> String.slice(text, 0, width)
      true -> String.slice(text, 0, width - 1) <> "…"
    end
  end

  @spec spaces(integer) :: String.t()
  def spaces(n) when n > 0, do: String.duplicate(" ", n)
  def spaces(_), do: ""

  @doc "Word-wraps text into lines of at most `width` characters (always at least one line)."
  @spec wrap(String.t(), pos_integer) :: [String.t()]
  def wrap(text, width) when width > 0 do
    text
    |> String.split(~r/\s+/u, trim: true)
    |> Enum.flat_map(&chunk_word(&1, width))
    # the accumulator carries the current line's length, so each word is
    # measured once rather than the growing line at every word
    |> Enum.reduce({[], 0}, fn word, {lines, used} ->
      size = String.length(word)

      case lines do
        [] ->
          {[word], size}

        [current | done] when used + 1 + size <= width ->
          {[current <> " " <> word | done], used + 1 + size}

        _ ->
          {[word | lines], size}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
    |> case do
      [] -> [""]
      lines -> lines
    end
  end

  defp chunk_word(word, width) do
    if String.length(word) <= width,
      do: [word],
      else: word |> String.graphemes() |> Enum.chunk_every(width) |> Enum.map(&Enum.join/1)
  end

  @doc "Draws a text field with a visible cursor at grapheme position `pos`."
  @spec field(String.t(), non_neg_integer, atom, atom) :: [segment]
  def field(text, pos, style, cursor_style \\ :edit_cursor) do
    {before, rest} = String.split_at(text, pos)
    {at, after_} = String.split_at(rest, 1)
    at = if at == "", do: " ", else: at
    [{style, before}, {cursor_style, at}, {style, after_}]
  end

  @doc """
  A line being typed (`Agendum.TUI.Typing.LineEdit`) as an input field `width`
  wide, scrolled so that the cursor shows.
  """
  @spec input(
          %{
            required(:text) => String.t(),
            required(:pos) => non_neg_integer,
            # a `Typing.LineEdit`'s mark, and its `__struct__`
            optional(atom) => term
          },
          non_neg_integer,
          atom
        ) :: line
  def input(%{text: text, pos: pos} = edit, width, style) do
    width = max(width, 1)
    offset = max(pos - width + 1, 0)
    visible = String.slice(text, offset, width)

    case Map.get(edit, :mark) do
      # nothing marked, or just started: the cursor alone
      mark when mark in [nil, pos] ->
        line(field(visible, pos - offset, style), width, style)

      # the text F7 marked (`Typing.LineEdit`), highlighted as the cursor is
      mark ->
        from = (min(mark, pos) - offset) |> max(0) |> min(String.length(visible))
        to = (max(mark, pos) - offset) |> max(0) |> min(String.length(visible))
        {before, rest} = String.split_at(visible, from)
        {marked, after_} = String.split_at(rest, to - from)
        line([{style, before}, {:edit_cursor, marked}, {style, after_}], width, style)
    end
  end

  @doc "Overlays `box` lines onto `screen` starting at row `top`, column `left`."
  @spec overlay([line], [line], non_neg_integer, non_neg_integer) :: [line]
  def overlay(screen, box, top, left) do
    box
    |> Enum.with_index(top)
    |> Enum.reduce(screen, fn {box_line, row}, screen ->
      if row < length(screen),
        do: List.update_at(screen, row, &splice(&1, box_line, left)),
        else: screen
    end)
  end

  defp splice(line, insert, left) do
    width = width(insert)
    before = take(line, left)
    after_ = drop(line, left + width)
    before ++ insert ++ after_
  end

  @spec width(line) :: non_neg_integer
  def width(line), do: line |> Enum.map(fn {_, t} -> String.length(t) end) |> Enum.sum()

  @doc "The first `n` characters of a styled line."
  @spec take(line, non_neg_integer) :: line
  def take(line, n) do
    {acc, _} =
      Enum.reduce(line, {[], n}, fn {s, t}, {acc, left} ->
        cond do
          left <= 0 -> {acc, 0}
          String.length(t) <= left -> {[{s, t} | acc], left - String.length(t)}
          true -> {[{s, String.slice(t, 0, left)} | acc], 0}
        end
      end)

    Enum.reverse(acc)
  end

  @doc "A styled line without its first `n` characters."
  @spec drop(line, non_neg_integer) :: line
  def drop(line, n) do
    {acc, _} =
      Enum.reduce(line, {[], n}, fn {s, t}, {acc, skip} ->
        len = String.length(t)

        cond do
          skip <= 0 -> {[{s, t} | acc], 0}
          len <= skip -> {acc, skip - len}
          true -> {[{s, String.slice(t, skip..-1//1)} | acc], 0}
        end
      end)

    Enum.reverse(acc)
  end

  @doc """
  Builds a framed box (list of lines) around content lines, with the title
  centred in the top edge, and a footer (Agenda's "Press ENTER when done,
  ESC to cancel") centred in the bottom edge. The frame is drawn in
  `:box_frame`, the title and footer in `:box_title`: a theme can show the
  frame as lines or, giving it the same colour in front and behind, as a
  solid band like Agenda's.
  """
  @spec box(String.t(), [line], pos_integer, String.t()) :: [line]
  def box(title, content, inner_width, footer \\ "") do
    # an untitled box (the splash screen) has an unbroken top
    title = if title == "", do: "", else: String.slice(" #{title} ", 0, inner_width)
    left = div(inner_width - String.length(title), 2)
    right = inner_width - left - String.length(title)

    top = [
      {:box_frame, "┌" <> String.duplicate("─", left)},
      {:box_title, title},
      {:box_frame, String.duplicate("─", right) <> "┐"}
    ]

    bottom = edge("└", footer, inner_width, "┘")

    body =
      Enum.map(content, fn l ->
        [{:box_frame, "│"}] ++ line(l, inner_width, :box) ++ [{:box_frame, "│"}]
      end)

    [top | body] ++ [bottom]
  end

  # a bottom edge with `text` in its middle; without text (or room), a plain line
  defp edge(left, text, inner_width, right) do
    text = if text == "", do: "", else: " #{text} "

    if text == "" or String.length(text) > inner_width - 2 do
      [{:box_frame, left <> String.duplicate("─", inner_width) <> right}]
    else
      before = div(inner_width - String.length(text), 2)
      after_ = inner_width - before - String.length(text)

      [
        {:box_frame, left <> String.duplicate("─", before)},
        {:box_title, text},
        {:box_frame, String.duplicate("─", after_) <> right}
      ]
    end
  end

  @doc """
  Restyles a line: with a map, each segment whose style is a key takes the
  value (others keep theirs); with a style, every segment takes it.
  """
  @spec paint(line, %{atom => atom} | atom) :: line
  def paint(line, styles) when is_map(styles),
    do: Enum.map(line, fn {style, text} -> {Map.get(styles, style, style), text} end)

  def paint(line, style) when is_atom(style),
    do: Enum.map(line, fn {_, text} -> {style, text} end)

  defp shade(line, from, len) do
    middle =
      line
      |> take(from + len)
      |> drop(from)
      |> Enum.map(fn
        {:box_frame, text} -> {:shadow, spaces(String.length(text))}
        {_, text} -> {:shadow, text}
      end)

    take(line, from) ++ middle ++ drop(line, from + len)
  end

  @doc "Restyles `len` columns of a line, from column `from`."
  @spec restyle(line, non_neg_integer, non_neg_integer, atom) :: line
  def restyle(line, from, len, style) do
    middle = line |> take(from + len) |> drop(from) |> paint(style)
    take(line, from) ++ middle ++ drop(line, from + len)
  end

  @doc """
  Casts the shadow of a box drawn at `top`, `left` (`height` lines of
  `width` columns): two columns to its right, and the line under it,
  moved two columns right. What is under the shadow stays, in `:shadow`,
  except the frame of a box beneath, whose lines would show through.
  """
  @spec shadow([line], non_neg_integer, non_neg_integer, pos_integer, pos_integer) :: [line]
  def shadow(screen, top, left, height, width) do
    screen
    |> Enum.with_index()
    |> Enum.map(fn {line, row} ->
      cond do
        row > top and row < top + height -> shade(line, left + width, 2)
        row == top + height -> shade(line, left + 2, width)
        true -> line
      end
    end)
  end

  @doc "Plain text of a screen; used by tests and snapshots."
  @spec to_text([line]) :: String.t()
  def to_text(screen) do
    Enum.map_join(screen, "\n", fn l ->
      l |> Enum.map_join(fn {_, t} -> t end) |> String.trim_trailing()
    end)
  end
end
