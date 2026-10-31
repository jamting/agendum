# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Search do
  @moduledoc """
  Text search over items (SPEC R37; User's Guide 15-1 to 15-6).

  A search names the text to look for (`text`), where to look (`on`:
  `:item` text, `:note` text or `:both`) and whether case is ignored.
  Every word of the text must appear as a whole word; a trailing `*`
  matches any ending ("Pat*" finds Pat, Patty, Patricia); a phrase in
  parentheses must appear as written ("(human resources)"). Agenda's
  other text-condition symbols (? ; , ~ !) are not supported.
  """

  @type t :: %__MODULE__{text: String.t(), on: :item | :note | :both, ignore_case: boolean}
  defstruct text: "", on: :item, ignore_case: true

  @doc "Whether an item matches the search."
  @spec matches?(Agendum.Core.Item.t(), t) :: boolean
  def matches?(item, %__MODULE__{} = search), do: matcher(search).(item)

  @doc """
  The search as a function of an item, its patterns compiled once: for
  checking many items, where `matches?/2` would compile them for each.
  """
  @spec matcher(t) :: (Agendum.Core.Item.t() -> boolean)
  def matcher(%__MODULE__{} = search) do
    # The function returned "closes over" `patterns`: it keeps the compiled
    # regexes with it, so every call reuses them.
    case patterns(search) do
      [] ->
        fn _item -> false end

      patterns ->
        fn item ->
          Enum.any?(texts(item, search.on), fn text ->
            Enum.all?(patterns, &Regex.match?(&1, text))
          end)
        end
    end
  end

  defp texts(item, :item), do: [item.text]
  defp texts(item, :note), do: [item.note]
  defp texts(item, :both), do: [item.text, item.note]

  # One regex per word or (phrase).
  defp patterns(%__MODULE__{text: text, ignore_case: ignore_case}) do
    flags = if ignore_case, do: "iu", else: "u"

    ~r/\(([^)]*)\)|(\S+)/u
    |> Regex.scan(text)
    |> Enum.map(fn
      [_, phrase] -> String.split(phrase)
      [_, "", word] -> [word]
    end)
    |> Enum.reject(&(&1 == []))
    |> Enum.map(fn words ->
      body = Enum.map_join(words, "\\s+", &word_pattern/1)
      Regex.compile!("(?<![\\p{L}\\p{N}])#{body}(?![\\p{L}\\p{N}])", flags)
    end)
  end

  defp word_pattern(word) do
    if String.ends_with?(word, "*") and word != "*",
      do: Regex.escape(String.trim_trailing(word, "*")) <> "[\\p{L}\\p{N}]*",
      else: Regex.escape(word)
  end
end
