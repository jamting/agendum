defmodule Agenda.Core.DateLanguage do
  @moduledoc """
  A language pack for reading dates and times in item text (SPEC R14c).
  `Agenda.Core.DateParser` does the date arithmetic; a pack says which
  phrases mean what. Adding a language is adding one module that
  implements this behaviour and listing it in `packs/0`.

  A pack gives:

    * `rules/0` and `time_rules/0`: `{meaning, pattern}`, where `meaning`
      is one of the parser's rule names (see `Agenda.Core.DateParser`) and
      the pattern's capture groups are in the order that meaning expects.
      Patterns are matched as whole words, ignoring case.
    * `text_excluded/0`: rules that count only in a date typed on its own,
      not in free text (bare abbreviations such as "sat").
    * `words/0`: what captured words mean, by kind: `:weekdays` (1–7),
      `:months` (1–12), `:numbers`, `:ordinals`, `:relative` (-1, 0, 1),
      `:periods` (`:week`, `:month`, `:year`), `:units` (`:day`, `:week`,
      `:month`), `:edges` (`:start`, `:end`), `:offsets` (days from today),
      `:time_words` (a `Time`) and `:time_units` (`:minute`, `:hour`).
    * `numeric_order/0`: `:month_day` ("11/5" is 5 November) or
      `:day_month` ("5/11" is 5 November).
    * `clock/0`: `:agenda` (hours 1–7 without am/pm are afternoon, User's
      Guide 6-12) or `:twenty_four`.
  """

  @type pack :: module

  @callback name() :: String.t()
  @callback rules() :: [{atom | {atom, term}, String.t()}]
  @callback time_rules() :: [{atom, String.t()}]
  @callback text_excluded() :: [atom]
  @callback words() :: %{atom => %{String.t() => term}}
  @callback numeric_order() :: :month_day | :day_month
  @callback clock() :: :agenda | :twenty_four

  @doc "Every language pack, the default (English) first."
  @spec packs() :: [pack]
  def packs, do: [Agenda.Core.DateLanguage.English]

  @doc "A pack by its name (\"english\"), ignoring case."
  @spec find(String.t()) :: {:ok, pack} | :error
  def find(name) do
    case Enum.find(packs(), &(&1.name() == String.downcase(String.trim(name)))) do
      nil -> :error
      pack -> {:ok, pack}
    end
  end

  @doc """
  A regex alternation of words, longest first (so "monday" is tried before
  "mon"); a space in a word matches any whitespace ("i morgon").
  """
  @spec alt([String.t()]) :: String.t()
  def alt(words) do
    words
    |> Enum.sort_by(&(-String.length(&1)))
    |> Enum.map_join("|", fn word ->
      word |> Regex.escape() |> String.replace("\\ ", "\\s+")
    end)
  end

  @doc "The alternation of the words of one kind in a pack."
  @spec alt(pack, atom) :: String.t()
  def alt(pack, kind), do: pack.words() |> Map.fetch!(kind) |> Map.keys() |> alt()
end
