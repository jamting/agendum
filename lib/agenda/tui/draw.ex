defmodule Agenda.TUI.Draw do
  @moduledoc """
  Pure helpers for building screens.

  A screen is a list of lines; a line is a list of `{style, text}`
  segments. `line/2` pads or truncates a line to an exact width so that
  every frame is a full rectangle. Styles are symbolic and mapped to colors
  by `Agenda.TUI.Theme`.
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

  @spec spaces(integer) :: String.t()
  def spaces(n) when n > 0, do: String.duplicate(" ", n)
  def spaces(_), do: ""

  @doc "Word-wraps text into lines of at most `width` characters (always at least one line)."
  @spec wrap(String.t(), pos_integer) :: [String.t()]
  def wrap(text, width) when width > 0 do
    text
    |> String.split(~r/\s+/u, trim: true)
    |> Enum.flat_map(&chunk_word(&1, width))
    |> Enum.reduce([], fn
      word, [] ->
        [word]

      word, [current | done] ->
        if String.length(current) + 1 + String.length(word) <= width,
          do: [current <> " " <> word | done],
          else: [word, current | done]
    end)
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

  defp take(line, n) do
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

  defp drop(line, n) do
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

  @doc "Builds a framed box (list of lines) around content lines."
  @spec box(String.t(), [line], pos_integer) :: [line]
  def box(title, content, inner_width) do
    title = " #{title} "
    bar = String.duplicate("─", max(inner_width - String.length(title), 0))
    top = [{:box, "┌" <> String.slice(title <> bar, 0, inner_width) <> "┐"}]
    bottom = [{:box, "└" <> String.duplicate("─", inner_width) <> "┘"}]

    body =
      Enum.map(content, fn l -> [{:box, "│"}] ++ line(l, inner_width, :box) ++ [{:box, "│"}] end)

    [top | body] ++ [bottom]
  end

  @doc "Plain text of a screen; used by tests and snapshots."
  @spec to_text([line]) :: String.t()
  def to_text(screen) do
    Enum.map_join(screen, "\n", fn l ->
      l |> Enum.map_join(fn {_, t} -> t end) |> String.trim_trailing()
    end)
  end
end
