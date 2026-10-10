defmodule Agenda.Core.TextSearch do
  @moduledoc """
  Finding and replacing literal text in a note (SPEC R39; User's Guide
  15-6 to 15-8). Unlike `Agenda.Core.Search`, the text is matched as
  written, anywhere: "son" is found in "Personnel".

  A note is a list of lines and a position is `{row, column}`, counted in
  characters. A search never spans two lines. Pure.
  """

  @type position :: {non_neg_integer, non_neg_integer}

  @doc """
  The position of the first occurrence at or after `from` (`:forward`), or
  of the last one before it (`:backward`); `nil` when there is none.
  """
  @spec find([String.t()], String.t(), position, :forward | :backward, boolean) ::
          position | nil
  def find(_lines, "", _from, _direction, _ignore_case), do: nil

  def find(lines, pattern, from, :forward, ignore_case),
    do: lines |> positions(pattern, ignore_case) |> Enum.find(&(&1 >= from))

  def find(lines, pattern, from, :backward, ignore_case),
    do: lines |> positions(pattern, ignore_case) |> Enum.filter(&(&1 < from)) |> List.last()

  @doc "Replaces as many characters as `pattern` has, at `position`, with `replacement`."
  @spec replace_at([String.t()], position, String.t(), String.t()) :: [String.t()]
  def replace_at(lines, {row, col}, pattern, replacement) do
    List.update_at(lines, row, fn line ->
      String.slice(line, 0, col) <>
        replacement <> String.slice(line, (col + String.length(pattern))..-1//1)
    end)
  end

  @doc "Replaces every occurrence, left to right, and counts them."
  @spec replace_all([String.t()], String.t(), String.t(), boolean) ::
          {[String.t()], non_neg_integer}
  def replace_all(lines, "", _replacement, _ignore_case), do: {lines, 0}

  def replace_all(lines, pattern, replacement, ignore_case) do
    wanted = normalize(pattern, ignore_case)

    Enum.map_reduce(lines, 0, fn line, count ->
      {parts, n} = replace_line(String.graphemes(line), wanted, replacement, ignore_case, [], 0)
      {IO.iodata_to_binary(parts), count + n}
    end)
  end

  defp replace_line([], _wanted, _replacement, _ignore_case, acc, n), do: {Enum.reverse(acc), n}

  defp replace_line([g | rest] = graphemes, wanted, replacement, ignore_case, acc, n) do
    if starts_with?(graphemes, wanted, ignore_case) do
      rest = Enum.drop(graphemes, length(wanted))
      replace_line(rest, wanted, replacement, ignore_case, [replacement | acc], n + 1)
    else
      replace_line(rest, wanted, replacement, ignore_case, [g | acc], n)
    end
  end

  # Every position where the pattern starts, in order.
  defp positions(lines, pattern, ignore_case) do
    wanted = normalize(pattern, ignore_case)

    for {line, row} <- Enum.with_index(lines),
        col <- starts(String.graphemes(line), wanted, ignore_case, 0),
        do: {row, col}
  end

  defp starts([], _wanted, _ignore_case, _col), do: []

  defp starts([_ | rest] = graphemes, wanted, ignore_case, col) do
    found = if starts_with?(graphemes, wanted, ignore_case), do: [col], else: []
    found ++ starts(rest, wanted, ignore_case, col + 1)
  end

  defp starts_with?(graphemes, wanted, ignore_case),
    do: graphemes |> Enum.take(length(wanted)) |> normalize_list(ignore_case) == wanted

  # Characters are compared one by one, so that positions stay character
  # positions even when lowercasing changes a character's length.
  defp normalize(text, ignore_case), do: text |> String.graphemes() |> normalize_list(ignore_case)
  defp normalize_list(graphemes, true), do: Enum.map(graphemes, &String.downcase/1)
  defp normalize_list(graphemes, false), do: graphemes
end
