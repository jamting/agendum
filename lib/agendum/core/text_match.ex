defmodule Agendum.Core.TextMatch do
  @moduledoc """
  How a file matches item text to categories (SPEC R16a; Agenda's
  Auto-assign Global Settings, User's Guide 19-7 to 19-12):

    * `enabled` (Text matching): off, no names or text conditions match
    * `match_on`: the item text (`:item`), the note (`:note`) or both
    * `strength` (Required match strength): the share of a name's or text
      condition's words the text must have: `:exact` all (100%),
      `:partial` at least half (50%), `:minimal` one; in any order
    * `enclosed_by` (Ignore text enclosed by): text between these marks is
      left out: `:quotes` ("…" and “…”), `:angle_brackets`, `:apostrophes`,
      `:braces`, `:brackets`, `:number_signs`, `:parentheses`, `:slashes`
    * `ignore_suffixes`: "Show" matches shows, showing, showed (words of
      three letters or fewer must match exactly)
    * `ignore_accents`: résumé matches resume

  A name of two or more capitalized words is a proper name (R16c, User's
  Guide 19-17): it matches its last name, alone, after a title ("Mrs.
  Wohl") or after its own first name, but not after another capitalized
  word ("John Wohl" is someone else), whatever the required strength.

  Text is read as words: a word starts with a letter or digit and may
  hold apostrophes, hyphens and underscores ("can't", "high-capacity").
  Pure.
  """

  @type match_on :: :item | :note | :both
  @type strength :: :exact | :partial | :minimal
  @type t :: %__MODULE__{
          enabled: boolean,
          match_on: match_on,
          strength: strength,
          enclosed_by: atom,
          ignore_suffixes: boolean,
          ignore_accents: boolean
        }

  defstruct enabled: true,
            match_on: :item,
            strength: :exact,
            enclosed_by: :quotes,
            ignore_suffixes: true,
            ignore_accents: false

  @enclosers [
    quotes: [{"\"", "\""}, {"“", "”"}],
    angle_brackets: [{"<", ">"}],
    apostrophes: [{"'", "'"}, {"‘", "’"}],
    braces: [{"{", "}"}],
    brackets: [{"[", "]"}],
    number_signs: [{"#", "#"}],
    parentheses: [{"(", ")"}],
    slashes: [{"/", "/"}]
  ]

  # Agenda's suffixes (User's Guide 19-11); -ied, -ier, -ies, -iful and
  # -ily become y ("families" is "family").
  @suffixes ~w(ably ally able ible ment wise iful ing est ies ied ier ily ed er es al ly s d)
            |> Enum.sort_by(&(-String.length(&1)))
  @to_y ~w(ied ier ies iful ily)

  # Titles Agenda ignores in names, with or without a period (User's Guide 19-17).
  @titles ~w(mr ms miss mrs messrs dr m mm monsieur madame mme mmes mademoiselle mlle mlles
             herr hr frau fr fraulein fräulein fri fru froken fröken frk)
  @word ~r/[\p{L}\p{N}][\p{L}\p{N}'’_\-]*/u

  @doc "The settings with the next (step 1) or previous (-1) choice for one of them."
  @spec cycle(t, atom, 1 | -1) :: t
  def cycle(s, field, _step) when field in [:enabled, :ignore_suffixes, :ignore_accents],
    do: Map.update!(s, field, &(not &1))

  def cycle(s, :match_on, step),
    do: %{s | match_on: next([:item, :note, :both], s.match_on, step)}

  def cycle(s, :strength, step),
    do: %{s | strength: next([:exact, :partial, :minimal], s.strength, step)}

  def cycle(s, :enclosed_by, step), do: %{s | enclosed_by: next(enclosers(), s.enclosed_by, step)}

  defp next(list, value, step) do
    index = Enum.find_index(list, &(&1 == value)) || 0
    Enum.at(list, Integer.mod(index + step, length(list)))
  end

  @doc "Every choice for Ignore text enclosed by, in the box's order."
  @spec enclosers() :: [atom]
  def enclosers, do: Keyword.keys(@enclosers)

  @doc "How the box shows a choice of marks."
  @spec encloser_label(atom) :: String.t()
  def encloser_label(kind) do
    [{open, close} | _] = Keyword.fetch!(@enclosers, kind)
    open <> " " <> close
  end

  @typedoc """
  Text prepared for matching: its words, plain and reduced to stems, and
  in order with whether each is capitalized (not just starting a sentence).
  """
  @type prepared :: %{
          text: String.t(),
          words: MapSet.t(String.t()),
          stems: MapSet.t(String.t()),
          tokens: [{String.t(), boolean}]
        }

  @doc "Prepares text for matching: drops enclosed text, reads the words."
  @spec prepare(String.t(), t) :: prepared
  def prepare(text, settings) do
    text = text |> drop_enclosed(settings.enclosed_by) |> accents(settings)
    words = words(text)

    %{
      text: text,
      words: MapSet.new(words),
      stems: MapSet.new(words, &stem/1),
      tokens: tokens(text)
    }
  end

  # The words in order; a word starting the text or a sentence is not
  # taken as capitalized ("Call Wohl"), unless a title ends the sentence.
  defp tokens(text) do
    @word
    |> Regex.scan(text, return: :index)
    |> Enum.map_reduce({0, true}, fn [{start, len}], {prev_end, title_before} ->
      raw = binary_part(text, start, len)
      word = normalize(raw)
      gap = binary_part(text, prev_end, start - prev_end)
      sentence_start = prev_end == 0 or (Regex.match?(~r/[.!?]/u, gap) and not title_before)
      {{word, capitalized?(raw) and not sentence_start}, {start + len, word in @titles}}
    end)
    |> elem(0)
  end

  defp capitalized?(word) do
    first = String.first(word)
    first == String.upcase(first) and first != String.downcase(first)
  end

  @doc """
  How well a name or phrase matches prepared text: `:full` when every word
  is there, `:partial` when enough are for the required strength, else
  `:none`. `exact_words` (a text condition's `^`) ignores no suffixes;
  `name` (a category's name or short name) reads proper names.
  """
  @spec level(String.t(), prepared, t, keyword) :: :full | :partial | :none
  def level(phrase, prepared, settings, opts \\ []) do
    case Keyword.get(opts, :name, false) && proper_name(accents(phrase, settings)) do
      {name, rest} ->
        cond do
          not name_found?(name, prepared.tokens) -> :none
          rest == "" -> :full
          true -> words_level(rest, prepared, settings, opts)
        end

      _ ->
        words_level(phrase, prepared, settings, opts)
    end
  end

  defp words_level(phrase, prepared, settings, opts) do
    terms = phrase |> accents(settings) |> words()
    exact = Keyword.get(opts, :exact_words, false) or not settings.ignore_suffixes
    found = Enum.count(terms, &found?(&1, prepared, exact))

    cond do
      terms == [] or String.length(Enum.join(terms)) < 2 -> :none
      found == length(terms) -> :full
      found > 0 and enough?(found, length(terms), settings.strength) -> :partial
      true -> :none
    end
  end

  defp enough?(_found, _total, :exact), do: false
  defp enough?(found, total, :partial), do: 2 * found >= total
  defp enough?(_found, _total, :minimal), do: true

  # A word of three letters or fewer must be there as it is (User's Guide 19-11).
  defp found?(word, prepared, exact) do
    if exact or String.length(word) <= 3,
      do: MapSet.member?(prepared.words, word),
      else: MapSet.member?(prepared.stems, stem(word))
  end

  @doc "Lowercase words of text, as Agenda reads them."
  @spec words(String.t()) :: [String.t()]
  def words(text), do: @word |> Regex.scan(text) |> Enum.map(fn [word] -> normalize(word) end)

  defp normalize(word) do
    word
    |> String.downcase()
    |> String.replace(~r/['’]s$/u, "")
    |> String.trim_trailing("-")
    |> String.trim_trailing("'")
    |> String.trim_trailing("’")
  end

  @doc """
  The proper name in a name: its first run of two or more capitalized
  words, titles left out, and the other words; nil when it has none.
  """
  @spec proper_name(String.t()) :: {[String.t()], String.t()} | nil
  def proper_name(name) do
    words =
      @word
      |> Regex.scan(name)
      |> Enum.map(fn [raw] -> {normalize(raw), capitalized?(raw)} end)
      |> Enum.reject(fn {word, _} -> word in @titles end)

    words
    |> Enum.chunk_by(&elem(&1, 1))
    |> Enum.find(&match?([{_, true}, _ | _], &1))
    |> case do
      nil ->
        nil

      run ->
        rest = Enum.reject(words, &(&1 in run))
        {Enum.map(run, &elem(&1, 0)), Enum.map_join(rest, " ", &elem(&1, 0))}
    end
  end

  # The last name in the text, after a title, one of the first names, or
  # no capitalized word.
  defp name_found?(name, tokens) do
    {first_names, [last]} = Enum.split(name, -1)

    [{nil, false} | tokens]
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.any?(fn [{before, capital}, {word, _}] ->
      word == last and (before in @titles or before in first_names or not capital)
    end)
  end

  @doc "A word without its suffixes (at most two), and a final e (shared, sharing, share)."
  @spec stem(String.t()) :: String.t()
  def stem(word), do: if(String.length(word) <= 3, do: word, else: strip(word, 2))

  defp strip(word, 0), do: drop_e(word)

  defp strip(word, passes) do
    suffix =
      Enum.find(
        @suffixes,
        &(String.ends_with?(word, &1) and String.length(word) - String.length(&1) >= 3)
      )

    case suffix do
      nil ->
        drop_e(word)

      suffix ->
        base = String.slice(word, 0, String.length(word) - String.length(suffix))
        strip(if(suffix in @to_y, do: base <> "y", else: base), passes - 1)
    end
  end

  defp drop_e(word) do
    if String.length(word) > 3 and String.ends_with?(word, "e"),
      do: String.slice(word, 0..-2//1),
      else: word
  end

  defp accents(text, %{ignore_accents: true}),
    do: text |> :unicode.characters_to_nfd_binary() |> String.replace(~r/\p{Mn}/u, "")

  defp accents(text, _settings), do: text

  defp drop_enclosed(text, kind) do
    @enclosers
    |> Keyword.get(kind, [])
    |> Enum.reduce(text, fn {open, close}, text ->
      Regex.replace(
        ~r/#{Regex.escape(open)}[^#{Regex.escape(close)}]*#{Regex.escape(close)}/u,
        text,
        " "
      )
    end)
  end
end
