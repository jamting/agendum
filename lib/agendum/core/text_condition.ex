defmodule Agendum.Core.TextCondition do
  @moduledoc """
  A category's text conditions, its "Also match" setting (SPEC R15d; User's
  Guide 19-2 to 19-4): words and phrases that pull items whose text
  contains them into the category, as its name does.

    * `;` separates alternatives (any may match), `,` conditions that must
      all match: `calls;phone`, `expenses,sales`
    * a word or phrase matches as whole words in that order, ignoring case;
      `(meet with)` may be put in parentheses
    * `!` before a condition: the text must not contain it (`Cost,!Deduction`)
    * `~` before a condition: case must match (`~LOTS`)
    * `?` stands for one character, `*` for any characters within a word
      (`Budget??`, `sl*`)
    * `\\` makes the next character plain text (`Surprise\\!`)

  Pure.
  """

  alias Agendum.Core.TextMatch

  @doc "Whether `text` meets the conditions, with Agenda's default matching settings."
  @spec matches?(String.t(), String.t()) :: boolean
  def matches?(condition, text) do
    settings = %TextMatch{}
    level(condition, TextMatch.prepare(text, settings), settings) != :none
  end

  @doc """
  How well prepared text (`TextMatch.prepare/2`) meets the conditions:
  `:full`, `:partial` (enough words for the required match strength, R16a)
  or `:none`. The best alternative counts; in an alternative every
  condition must hold.
  """
  @spec level(String.t(), TextMatch.prepared(), TextMatch.t()) :: :full | :partial | :none
  def level(condition, prepared, settings) do
    condition
    |> split(";")
    |> Enum.map(fn alternative ->
      alternative |> split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
    end)
    |> Enum.reject(&(&1 == []))
    |> Enum.map(fn terms ->
      terms |> Enum.map(&term_level(&1, prepared, settings)) |> weakest()
    end)
    |> best()
  end

  defp weakest(levels) do
    cond do
      :none in levels -> :none
      :partial in levels -> :partial
      true -> :full
    end
  end

  defp best(levels) do
    cond do
      :full in levels -> :full
      :partial in levels -> :partial
      true -> :none
    end
  end

  defp term_level(term, prepared, settings) do
    {negated, term} = flag(term, "!")
    {exact_case, term} = flag(term, "~")
    {exact_words, term} = flag(term, "^")
    {negated, term} = if negated, do: {true, term}, else: flag(term, "!")

    {in_order, term} =
      case Regex.run(~r/^\((.*)\)$/su, term) do
        [_, inner] -> {true, String.trim(inner)}
        nil -> {false, term}
      end

    level =
      if in_order or exact_case or Regex.match?(~r/(?<!\\)[?*]/u, term),
        do: pattern_level(term, prepared.text, exact_case),
        else:
          TextMatch.level(String.replace(term, "\\", ""), prepared, settings,
            exact_words: exact_words
          )

    cond do
      not negated -> level
      level == :none -> :full
      true -> :none
    end
  end

  # Wildcards and matching case: the words as a pattern, in order.
  defp pattern_level(term, text, exact_case) do
    case pattern(term) do
      "" ->
        :none

      pattern ->
        regex = "(?<![\\p{L}\\p{N}])" <> pattern <> "(?![\\p{L}\\p{N}])"

        if Regex.match?(Regex.compile!(regex, if(exact_case, do: "u", else: "iu")), text),
          do: :full,
          else: :none
    end
  end

  defp flag(term, mark) do
    if String.starts_with?(term, mark),
      do: {true, term |> String.replace_prefix(mark, "") |> String.trim_leading()},
      else: {false, term}
  end

  # The term as a regex: literal characters, wildcards, flexible spaces.
  defp pattern(term), do: term |> String.graphemes() |> pattern([])

  defp pattern([], acc), do: acc |> Enum.reverse() |> Enum.join()
  defp pattern(["\\", c | rest], acc), do: pattern(rest, [Regex.escape(c) | acc])
  defp pattern(["?" | rest], acc), do: pattern(rest, ["[^\\s]" | acc])
  defp pattern(["*" | rest], acc), do: pattern(rest, ["[^\\s]*" | acc])

  defp pattern([c | rest], acc) do
    if String.trim(c) == "" do
      rest = Enum.drop_while(rest, &(String.trim(&1) == ""))
      pattern(rest, if(acc == [] or rest == [], do: acc, else: ["\\s+" | acc]))
    else
      pattern(rest, [Regex.escape(c) | acc])
    end
  end

  # Splits on a separator that is not escaped with \.
  defp split(text, separator) do
    {parts, current, _escaped} =
      text
      |> String.graphemes()
      |> Enum.reduce({[], "", false}, fn
        c, {parts, current, true} -> {parts, current <> c, false}
        "\\", {parts, current, false} -> {parts, current <> "\\", true}
        ^separator, {parts, current, false} -> {[current | parts], "", false}
        c, {parts, current, false} -> {parts, current <> c, false}
      end)

    Enum.reverse([current | parts])
  end
end
