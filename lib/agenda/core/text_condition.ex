defmodule Agenda.Core.TextCondition do
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

  Not done: Agenda's `"` (exclude words from matching) and suffix marks.
  Pure.
  """

  @doc "Whether `text` meets the conditions."
  @spec matches?(String.t(), String.t()) :: boolean
  def matches?(condition, text) do
    condition
    |> split(";")
    |> Enum.map(fn alternative ->
      alternative |> split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
    end)
    |> Enum.reject(&(&1 == []))
    |> Enum.any?(fn terms -> Enum.all?(terms, &term_matches?(&1, text)) end)
  end

  defp term_matches?(term, text) do
    {negated, term} = flag(term, "!")
    {exact_case, term} = flag(term, "~")
    {negated, term} = if negated, do: {true, term}, else: flag(term, "!")

    term =
      case Regex.run(~r/^\((.*)\)$/su, term) do
        [_, inner] -> String.trim(inner)
        nil -> term
      end

    found =
      case pattern(term) do
        "" ->
          false

        pattern ->
          regex = "(?<![\\p{L}\\p{N}])" <> pattern <> "(?![\\p{L}\\p{N}])"
          Regex.match?(Regex.compile!(regex, if(exact_case, do: "u", else: "iu")), text)
      end

    found != negated
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
