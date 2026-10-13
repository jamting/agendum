defmodule Agenda.TUI.TextEdit do
  @moduledoc "A pure multi-line text buffer, used for notes."

  @type t :: %__MODULE__{lines: [String.t()], row: non_neg_integer, col: non_neg_integer}
  defstruct lines: [""], row: 0, col: 0

  @spec new(String.t()) :: t
  def new(text) do
    lines = String.split(text, "\n")
    row = length(lines) - 1
    %__MODULE__{lines: lines, row: row, col: String.length(Enum.at(lines, row))}
  end

  @spec text(t) :: String.t()
  def text(%__MODULE__{lines: lines}), do: lines |> Enum.join("\n") |> String.trim_trailing()

  @spec handle(t, term) :: {:ok, t} | :unhandled
  def handle(%__MODULE__{} = e, key) do
    line = current(e)

    key =
      Map.get(%{{:ctrl, "a"} => :home, {:ctrl, "e"} => :end, {:ctrl, "d"} => :delete}, key, key)

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
  @spec take(t, :word | :line | :all) :: {String.t(), t} | nil
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
