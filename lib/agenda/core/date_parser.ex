defmodule Agenda.Core.DateParser do
  @moduledoc """
  Reads dates the way Agenda does, relative to a given `today` (the core
  never reads the clock itself).

  * `parse/2` – a date typed on its own, e.g. in a When column
    ("friday", "next week", "11/20/90", "Thursday at 3:30 pm").
  * `extract/2` – the first date inside free item text
    ("Call Toni on August 7", "Cheryl arrives tomorrow"), SPEC R14.

  Relative dates follow the Agenda 2.0 User's Guide (chapter 7, "How Agenda
  Interprets Relative Dates in Items"): weeks run Monday to Friday; a bare
  weekday is its next occurrence (today if it is today); "this", "next"
  and "last" put a weekday in the current, following or previous week; and
  "this/next/last week|month|year" is the start of that period. A date
  without a year is put in the future.

  Times of day are read too (`parse_when/3`, `extract_when/3`): clock times
  ("3:30 pm", "@ 3pm", "15:30"; without am/pm between 8:00 am and 7:59
  pm), "noon", "morning" (8:00), "afternoon" (14:00), "evening" and
  "tonight" (17:00), "now", "in 2 hours", "45 mins from now". Recurring
  dates ("every Monday"), working days, quarters and "first Wednesday in
  November" are not supported yet.

  The words and phrases come from language packs (`Agenda.Core.DateLanguage`,
  English by default, SPEC R14c); this module does the date arithmetic. A
  pack's rules name what they mean, with capture groups in this order:

    * date: `:iso` (year, month, day), `:numeric` (two numbers in the
      pack's `numeric_order`, optional year), `:month_day` (month, day,
      year), `:day_month` (day, month, year), `:ordinal_of_month` (ordinal,
      month, year), `{:offset, days}` (none), `:offset_word` (word),
      `:in_units`, `:units_from_now`, `:units_ago` (count, unit),
      `:edge_of_period` (edge, relative word or none, period),
      `:relative_period` (relative word, period), `:relative_weekday`
      (relative word, weekday), `:weekday` and `:weekday_abbr` (weekday:
      its next occurrence), `:past_weekday` (weekday: its last occurrence
      before today)
    * time: `:clock` (hour, minutes, am/pm or none), `:hour_ampm` (hour,
      am/pm), `:at_hour` (hour), `:time_word` (word), `:in_time` (count,
      unit), `:now`
  """

  alias Agenda.Core.DateLanguage

  @default [DateLanguage.English]

  # The rules of the given packs as {meaning, whole-word pattern, number of
  # capture groups, pack, pack's position}; `kind` is :date or :time.
  defp compile(languages, kind, in_text) do
    for {pack, position} <- Enum.with_index(languages),
        {meaning, pattern} <- if(kind == :date, do: pack.rules(), else: pack.time_rules()),
        not (in_text and kind == :date and meaning in pack.text_excluded()) do
      groups = length(Regex.scan(~r/(?<!\\)\((?!\?)/, pattern))
      {meaning, "(?<![\\p{L}\\p{N}])(?:#{pattern})(?![\\p{L}\\p{N}])", groups, pack, position}
    end
  end

  @typedoc """
  Options: `languages:` the language packs to read (`Agenda.Core.DateLanguage`),
  the main one first (default English). Every pack's phrases count; where
  two match the same words, the earlier pack wins.
  """
  @type opts :: [languages: [DateLanguage.pack()]]

  @doc """
  Parses a date typed on its own, such as an entry in a date column.
  A time, if any, is accepted and dropped (see `parse_when/3`).
  """
  @spec parse(String.t(), Date.t(), opts) :: {:ok, Date.t()} | :error
  def parse(text, %Date{} = today, opts \\ []) do
    case parse_when(text, NaiveDateTime.new!(today, ~T[00:00:00]), opts) do
      {:ok, date, _time} -> {:ok, date}
      :error -> :error
    end
  end

  @doc """
  Parses a date and/or time typed on its own ("friday", "Thursday at 3:30
  pm", "3pm", "in 2 hours"), relative to `now`. A time alone means today;
  a time without am/pm falls between 8:00 am and 7:59 pm (User's Guide
  6-12). Returns the date and the time of day, or `nil` when none was given.
  """
  @spec parse_when(String.t(), NaiveDateTime.t(), opts) ::
          {:ok, Date.t(), Time.t() | nil} | :error
  def parse_when(text, %NaiveDateTime{} = now, opts \\ []) do
    text = String.trim(text)
    languages = languages(opts)

    with {:ok, date, time, spans} <- find_when(text, now, languages, false),
         rest = remove_spans(text, spans),
         true <- Regex.match?(~r/^[\s,.@]*(at)?[\s,.@]*$/iu, rest) do
      {:ok, date, time}
    else
      _ -> :error
    end
  end

  @doc """
  Finds the first date in free text. Returns the date and the words it was
  read from (used to notice when an edit changes the date phrase). See
  `extract_when/3` for the time of day as well.
  """
  @spec extract(String.t(), Date.t(), opts) :: {:ok, Date.t(), String.t()} | :none
  def extract(text, %Date{} = today, opts \\ []) do
    case extract_when(text, NaiveDateTime.new!(today, ~T[00:00:00]), opts) do
      {:ok, date, _time, phrase} -> {:ok, date, phrase}
      :none -> :none
    end
  end

  @doc """
  Finds the first date and the first time of day in free text ("Call
  Marketing this Tuesday at 3:00"), relative to `now`. A time with no date
  means today; a relative time ("in 2 hours") gives both. Returns the
  date, the time (or `nil`) and the words they were read from.
  """
  @spec extract_when(String.t(), NaiveDateTime.t(), opts) ::
          {:ok, Date.t(), Time.t() | nil, String.t()} | :none
  def extract_when(text, %NaiveDateTime{} = now, opts \\ []) do
    case find_when(text, now, languages(opts), true) do
      {:ok, date, time, spans} ->
        phrase =
          spans
          |> Enum.sort()
          |> Enum.map_join(" ", fn {start, len} -> binary_part(text, start, len) end)
          |> String.downcase()
          |> String.replace(~r/\s+/u, " ")

        {:ok, date, time, phrase}

      :none ->
        :none
    end
  end

  defp languages(opts) do
    case Keyword.get(opts, :languages) do
      nil -> @default
      [] -> @default
      languages -> languages
    end
  end

  # The first date and the first time in `text`, combined.
  defp find_when(text, now, languages, in_text) do
    today = NaiveDateTime.to_date(now)
    date = first(matches(text, compile(languages, :date, in_text), &interpret(&1, &2, &3, today)))

    # a time may not reuse the date's words ("at 12/24" is a date)
    time =
      text
      |> matches(compile(languages, :time, in_text), &interpret_time(&1, &2, &3, now))
      |> Enum.reject(fn {start, neg_len, _, _} -> overlaps?(date, {start, -neg_len}) end)
      |> first()

    case {date, time} do
      {nil, nil} ->
        :none

      {{d, ds}, nil} ->
        {:ok, d, nil, [ds]}

      {{d, ds}, {{:time, t}, ts}} ->
        {:ok, d, t, [ds, ts]}

      {{d, ds}, {{:datetime, _}, _}} ->
        {:ok, d, nil, [ds]}

      {nil, {{:time, t}, ts}} ->
        {:ok, today, t, [ts]}

      {nil, {{:datetime, dt}, ts}} ->
        {:ok, NaiveDateTime.to_date(dt), NaiveDateTime.to_time(dt), [ts]}
    end
  end

  defp overlaps?(nil, _span), do: false
  defp overlaps?({_, {ds, dl}}, {ts, tl}), do: ts < ds + dl and ds < ts + tl

  # The earliest match; of those, the longest; of those, the main language's.
  defp first([]), do: nil

  defp first(list),
    do:
      list
      |> Enum.min_by(fn {start, neg_len, position, _} -> {start, neg_len, position} end)
      |> then(fn {start, neg_len, _, value} -> {value, {start, -neg_len}} end)

  defp remove_spans(text, spans) do
    spans
    |> Enum.sort(:desc)
    |> Enum.reduce(text, fn {start, len}, acc ->
      binary_part(acc, 0, start) <> binary_part(acc, start + len, byte_size(acc) - start - len)
    end)
  end

  # Every valid match of the rules, as {byte_start, -byte_length, pack
  # position, value}.
  defp matches(text, rules, interpreter) do
    Enum.flat_map(rules, fn {meaning, pattern, group_count, pack, position} ->
      pattern
      |> Regex.compile!("iu")
      |> Regex.scan(text, return: :index)
      |> Enum.flat_map(fn [{start, len} | groups] ->
        # unmatched optional groups at the end are left out by Regex.scan
        groups = groups ++ List.duplicate({-1, 0}, group_count - length(groups))

        captures =
          Enum.map(groups, fn {s, l} ->
            if s < 0,
              do: nil,
              else:
                text |> binary_part(s, l) |> String.downcase() |> String.replace(~r/\s+/u, " ")
          end)

        case interpreter.(meaning, captures, pack) do
          {:ok, value} -> [{start, -len, position, value}]
          :error -> []
        end
      end)
    end)
  end

  # --- times --------------------------------------------------------------------

  defp interpret_time(:clock, [h, m | ampm], pack, _now),
    do: clock(h, int(m), List.first(ampm), pack)

  defp interpret_time(:hour_ampm, [h, ampm], pack, _now), do: clock(h, 0, ampm, pack)
  defp interpret_time(:at_hour, [h], pack, _now), do: clock(h, 0, nil, pack)

  defp interpret_time(:time_word, [word], pack, _now),
    do: {:ok, {:time, word(pack, :time_words, word)}}

  defp interpret_time(:in_time, [n, unit], pack, now) do
    minutes = count(pack, n) * if(word(pack, :time_units, unit) == :hour, do: 60, else: 1)
    {:ok, {:datetime, NaiveDateTime.add(now, minutes * 60)}}
  end

  defp interpret_time(:now, _, _pack, now), do: {:ok, {:datetime, now}}

  # With Agenda's clock, 12-hour times without am/pm fall between 8:00 am
  # and 7:59 pm; hours over 12, 0 and a leading zero ("08:30") are read as
  # a 24-hour clock. A 24-hour clock reads every hour as written.
  defp clock(h, m, ampm, pack) do
    hour = int(h)

    hour =
      cond do
        ampm && hour > 12 -> nil
        ampm && String.starts_with?(ampm, "p") -> rem(hour, 12) + 12
        ampm -> rem(hour, 12)
        pack.clock() == :twenty_four -> hour
        hour == 0 or hour > 12 or String.starts_with?(h, "0") -> hour
        hour < 8 -> hour + 12
        true -> hour
      end

    case hour && Time.new(hour, m, 0) do
      {:ok, time} -> {:ok, {:time, time}}
      _ -> :error
    end
  end

  # --- interpreting matches ---------------------------------------------------

  defp interpret(:iso, [y, m, d], _pack, _today), do: build(int(y), int(m), int(d))

  defp interpret(:numeric, [a, b | y], pack, today) do
    {m, d} = if pack.numeric_order() == :day_month, do: {b, a}, else: {a, b}

    case List.first(y) do
      nil -> future(int(m), int(d), today)
      y -> build(year(y), int(m), int(d))
    end
  end

  defp interpret(:month_day, [m, d, y], pack, today),
    do: month_date(word(pack, :months, m), int(d), y, today)

  defp interpret(:day_month, [d, m, y], pack, today),
    do: month_date(word(pack, :months, m), int(d), y, today)

  defp interpret(:ordinal_of_month, [o, m, y], pack, today),
    do: month_date(word(pack, :months, m), word(pack, :ordinals, o), y, today)

  defp interpret({:offset, days}, _, _pack, today), do: {:ok, Date.add(today, days)}

  defp interpret(:offset_word, [word], pack, today),
    do: {:ok, Date.add(today, word(pack, :offsets, word))}

  defp interpret(:in_units, [n, unit], pack, today),
    do: shift(today, count(pack, n), word(pack, :units, unit))

  defp interpret(:units_from_now, [n, unit], pack, today),
    do: shift(today, count(pack, n), word(pack, :units, unit))

  defp interpret(:units_ago, [n, unit], pack, today),
    do: shift(today, -count(pack, n), word(pack, :units, unit))

  defp interpret(:edge_of_period, [edge, which, period], pack, today) do
    period = word(pack, :periods, period)
    start = period_start(period, relative(pack, which), today)

    case {word(pack, :edges, edge), period} do
      {:end, :week} -> {:ok, Date.add(start, 4)}
      {:end, :month} -> {:ok, Date.end_of_month(start)}
      _ -> {:ok, start}
    end
  end

  defp interpret(:relative_period, [which, period], pack, today),
    do: {:ok, period_start(word(pack, :periods, period), relative(pack, which), today)}

  defp interpret(:relative_weekday, [which, day], pack, today) do
    monday = Date.beginning_of_week(today)
    {:ok, Date.add(monday, 7 * relative(pack, which) + word(pack, :weekdays, day) - 1)}
  end

  defp interpret(meaning, [day], pack, today) when meaning in [:weekday, :weekday_abbr] do
    days = Integer.mod(word(pack, :weekdays, day) - Date.day_of_week(today), 7)
    {:ok, Date.add(today, days)}
  end

  # The most recent such weekday before today ("i fredags").
  defp interpret(:past_weekday, [day], pack, today) do
    days = Integer.mod(Date.day_of_week(today) - word(pack, :weekdays, day) - 1, 7) + 1
    {:ok, Date.add(today, -days)}
  end

  # --- helpers ----------------------------------------------------------------

  defp word(pack, kind, word), do: pack.words() |> Map.fetch!(kind) |> Map.fetch!(word)

  defp relative(_pack, nil), do: 0
  defp relative(pack, which), do: word(pack, :relative, which)

  defp period_start(:week, offset, today),
    do: today |> Date.beginning_of_week() |> Date.add(7 * offset)

  defp period_start(:month, offset, today),
    do: today |> Date.beginning_of_month() |> Date.shift(month: offset)

  defp period_start(:year, offset, today), do: Date.new!(today.year + offset, 1, 1)

  defp shift(today, n, :day), do: {:ok, Date.add(today, n)}
  defp shift(today, n, :week), do: {:ok, Date.add(today, 7 * n)}
  defp shift(today, n, :month), do: {:ok, Date.shift(today, month: n)}

  defp month_date(m, d, nil, today), do: future(m, d, today)
  defp month_date(m, d, y, _today), do: build(int(y), m, d)

  # A date without a year: this year's, unless that has passed.
  defp future(m, d, today) do
    with {:ok, date} <- build(today.year, m, d) do
      if Date.compare(date, today) == :lt, do: build(today.year + 1, m, d), else: {:ok, date}
    end
  end

  defp build(y, m, d) do
    case Date.new(y, m, d) do
      {:ok, date} -> {:ok, date}
      {:error, _} -> :error
    end
  end

  defp year(y) when byte_size(y) == 2, do: 1900 + int(y) + if(int(y) < 50, do: 100, else: 0)
  defp year(y), do: int(y)

  defp count(pack, n), do: Map.get_lazy(pack.words().numbers, n, fn -> int(n) end)
  defp int(s), do: String.to_integer(s)

  @doc """
  Formats a date as ISO 8601, the form offered for editing (always readable
  by `parse/2`). Displayed dates follow the file's `Agenda.Core.DateFormat`.
  """
  @spec format(Date.t() | nil) :: String.t()
  def format(nil), do: ""
  def format(%Date{} = date), do: Date.to_iso8601(date)
end
