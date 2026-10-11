defmodule Agenda.Core.DateParser do
  @moduledoc """
  Reads dates the way Agenda does, relative to a given `today` (the core
  never reads the clock itself).

  * `parse/2` – a date typed on its own, e.g. in a When column
    ("friday", "next week", "11/20/90", "Thursday at 3:30 pm").
  * `extract/2` – the first date inside free item text
    ("Call Toni on August 7", "Cheryl arrives tomorrow"), SPEC R14.

  Relative dates follow the Agenda 2.0 User's Guide (chapter 7, "How Agenda
  Interprets Relative Dates in Items"): weeks run Monday to Friday (the
  file's `Agenda.Core.DateSettings` can change that, R14e); a bare
  weekday is its next occurrence (today if it is today); "this", "next"
  and "last" put a weekday in the current, following or previous week; and
  "this/next/last week|month|year" is the start of that period. A date
  without a year is put in the future.

  Times of day are read too (`parse_when/3`, `extract_when/3`): clock times
  ("3:30 pm", "@ 3pm", "15:30"; without am/pm between 8:00 am and 7:59
  pm), "noon", "morning" (8:00), "afternoon" (14:00), "evening" and
  "tonight" (17:00), "now", "in 2 hours", "45 mins from now".

  More phrases (R14d): working days ("in five working days", skipping
  Saturday and Sunday), quarters ("this quarter", "end of the quarter",
  "first quarter"), "first Wednesday in November", "the last Friday of
  the month", "the 15th of next month", and a month alone ("next April",
  "end of March"), which means its first day.

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
    * more (R14d): `:nth_quarter` (ordinal), `:nth_weekday` (ordinal or
      the pack's `:last` word, weekday, month, year), `:nth_weekday_relative`
      (ordinal or last, weekday, relative word or none: of this month),
      `:day_of_relative_month` (day as a number or an ordinal, relative
      word or none), `:month_alone` and `:bare_month` (relative word or
      none, month), `:edge_of_month` (edge, relative word or none, month);
      the unit `:working_day` works with `:in_units` and its friends
    * recurring (R14a): `:recurring_weekday` (interval word, weekday),
      `:recurring_unit` (interval word, unit), `:recurring_count` (count,
      unit), `:recurring_day_of_month` (day as a number or an ordinal);
      interval words ("every", "every other", "varannan") are the
      pack's `:intervals`
    * time: `:clock` (hour, minutes, am/pm or none), `:hour_ampm` (hour,
      am/pm), `:at_hour` (hour), `:time_word` (word), `:in_time` (count,
      unit), `:now`
  """

  alias Agenda.Core.{DateLanguage, DateSettings, Recurrence}

  @default [DateLanguage.English]

  # The rules of the given packs as {meaning, whole-word pattern, number of
  # capture groups, pack, pack's position}; `kind` is :date or :time.
  defp compile(languages, kind, in_text) do
    for {pack, position} <- Enum.with_index(languages),
        {meaning, pattern} <- if(kind == :date, do: pack.rules(), else: pack.time_rules()),
        not (in_text and kind == :date and meaning in pack.text_excluded()) do
      groups = length(Regex.scan(~r/(?<!\\)\((?!\?)/, pattern))
      pattern = ascii_digits(pattern)
      {meaning, "(?<![\\p{L}\\p{N}])(?:#{pattern})(?![\\p{L}\\p{N}])", groups, pack, position}
    end
  end

  # With Unicode on, \\d would also match other scripts' digits ("٥"), which
  # are not numbers to us: \\d becomes 0-9, inside a [class] or as one.
  defp ascii_digits(pattern), do: ascii_digits(pattern, false, "")

  defp ascii_digits("", _in_class, acc), do: acc
  defp ascii_digits("\\d" <> rest, true, acc), do: ascii_digits(rest, true, acc <> "0-9")
  defp ascii_digits("\\d" <> rest, false, acc), do: ascii_digits(rest, false, acc <> "[0-9]")

  defp ascii_digits("\\" <> <<c::utf8, rest::binary>>, in_class, acc),
    do: ascii_digits(rest, in_class, acc <> "\\" <> <<c::utf8>>)

  defp ascii_digits("[" <> rest, false, acc), do: ascii_digits(rest, true, acc <> "[")
  defp ascii_digits("]" <> rest, true, acc), do: ascii_digits(rest, false, acc <> "]")

  defp ascii_digits(<<c::utf8, rest::binary>>, in_class, acc),
    do: ascii_digits(rest, in_class, acc <> <<c::utf8>>)

  @typedoc """
  Options: `languages:` the language packs to read (`Agenda.Core.DateLanguage`),
  the main one first (default English). Every pack's phrases count; where
  two match the same words, the earlier pack wins. `settings:` the file's
  `Agenda.Core.DateSettings` (default Agenda's).
  """
  @type opts :: [languages: [DateLanguage.pack()], settings: DateSettings.t() | nil]

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
    case parse_recurring(text, now, opts) do
      {:ok, date, time, _rule} -> {:ok, date, time}
      :error -> :error
    end
  end

  @doc """
  Like `parse_when/3`, also giving the rule of a recurring date ("every
  Monday at 9am"), or nil (R14a).
  """
  @spec parse_recurring(String.t(), NaiveDateTime.t(), opts) ::
          {:ok, Date.t(), Time.t() | nil, Recurrence.t() | nil} | :error
  def parse_recurring(text, %NaiveDateTime{} = now, opts \\ []) do
    text = String.trim(text)

    with {:ok, date, time, rule, spans} <- find_when(text, now, opts, false),
         rest = remove_spans(text, spans),
         true <- Regex.match?(~r/^[\s,.@]*(at)?[\s,.@]*$/iu, rest) do
      {:ok, date, time, rule}
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
    case extract_recurring(text, now, opts) do
      {:ok, date, time, _rule, phrase} -> {:ok, date, time, phrase}
      :none -> :none
    end
  end

  @doc """
  Like `extract_when/3`, also giving the rule of a recurring date ("Staff
  meeting every Friday"), or nil (R14a).
  """
  @spec extract_recurring(String.t(), NaiveDateTime.t(), opts) ::
          {:ok, Date.t(), Time.t() | nil, Recurrence.t() | nil, String.t()} | :none
  def extract_recurring(text, %NaiveDateTime{} = now, opts \\ []) do
    case find_when(text, now, opts, true) do
      {:ok, date, time, rule, spans} ->
        phrase =
          spans
          |> Enum.sort()
          |> Enum.map_join(" ", fn {start, len} -> binary_part(text, start, len) end)
          |> String.downcase()
          |> String.replace(~r/\s+/u, " ")

        {:ok, date, time, rule, phrase}

      :none ->
        :none
    end
  end

  @doc """
  Every date and time in free text, in order, for a date category that
  takes the nth one (Which one, R6b): a date and the time right after (or
  before) it count as one ("Friday at 6pm"); a time alone is today's ("from
  10:00 to 2:30" gives two). Each is the date, the time or nil, and its
  words. Recurrence is not read here.
  """
  @spec extract_all(String.t(), NaiveDateTime.t(), opts) :: [
          {Date.t(), Time.t() | nil, String.t()}
        ]
  def extract_all(text, %NaiveDateTime{} = now, opts \\ []) do
    {languages, s} = {languages(opts), Keyword.get(opts, :settings) || %DateSettings{}}
    today = NaiveDateTime.to_date(now)

    dates =
      text
      |> matches(compile(languages, :date, true), &interpret(&1, &2, &3, today, s))
      |> disjoint()

    times =
      text
      |> matches(compile(languages, :time, true), &interpret_time(&1, &2, &3, now, s))
      |> Enum.reject(fn {start, neg_len, _, _} ->
        Enum.any?(dates, &overlaps?({nil, &1.span}, {start, -neg_len}))
      end)
      |> disjoint()

    (Enum.map(dates, &Map.put(&1, :kind, :date)) ++ Enum.map(times, &Map.put(&1, :kind, :time)))
    |> Enum.sort_by(& &1.span)
    |> pair_up(text)
    |> Enum.map(&occurrence(&1, text, today))
  end

  # Matches that do not overlap, earliest (and longest) first, as
  # %{span: {start, length}, value: value}.
  defp disjoint(matches) do
    matches
    |> Enum.sort_by(fn {start, neg_len, position, _} -> {start, neg_len, position} end)
    |> Enum.reduce({[], 0}, fn {start, neg_len, _, value}, {acc, free_from} ->
      if start >= free_from,
        do: {[%{span: {start, -neg_len}, value: value} | acc], start - neg_len},
        else: {acc, free_from}
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  # A date and a time with only "at", "on", "@", commas or spaces between
  # them belong together.
  defp pair_up([%{kind: a} = x, %{kind: b} = y | rest], text) when a != b do
    {xs, xl} = x.span
    {ys, _} = y.span
    gap = binary_part(text, xs + xl, ys - xs - xl)

    if Regex.match?(~r/^[\s,@]*(?:at|on|kl\.?)?[\s,@]*$/iu, gap),
      do: [[x, y] | pair_up(rest, text)],
      else: [[x] | pair_up([y | rest], text)]
  end

  defp pair_up([x | rest], text), do: [[x] | pair_up(rest, text)]
  defp pair_up([], _text), do: []

  defp occurrence(parts, text, today) do
    date = Enum.find_value(parts, &(&1.kind == :date && date_value(&1.value)))
    time = Enum.find_value(parts, &(&1.kind == :time && &1.value))

    phrase =
      parts
      |> Enum.map_join(" ", fn %{span: {start, len}} -> binary_part(text, start, len) end)
      |> String.downcase()
      |> String.replace(~r/\s+/u, " ")

    case {date, time} do
      {nil, {:time, t}} -> {today, t, phrase}
      {nil, {:datetime, dt}} -> {NaiveDateTime.to_date(dt), NaiveDateTime.to_time(dt), phrase}
      {d, {:time, t}} -> {d, t, phrase}
      {d, _} -> {d, nil, phrase}
    end
  end

  defp date_value({:recurring, date, _rule}), do: date
  defp date_value(%Date{} = date), do: date

  defp languages(opts) do
    case Keyword.get(opts, :languages) do
      nil -> @default
      [] -> @default
      languages -> languages
    end
  end

  # The first date and the first time in `text`, combined.
  defp find_when(text, now, opts, in_text) do
    {languages, s} = {languages(opts), Keyword.get(opts, :settings) || %DateSettings{}}
    today = NaiveDateTime.to_date(now)

    date =
      first(matches(text, compile(languages, :date, in_text), &interpret(&1, &2, &3, today, s)))

    # a time may not reuse the date's words ("at 12/24" is a date)
    time =
      text
      |> matches(compile(languages, :time, in_text), &interpret_time(&1, &2, &3, now, s))
      |> Enum.reject(fn {start, neg_len, _, _} -> overlaps?(date, {start, -neg_len}) end)
      |> first()

    {date, rule} =
      case date do
        {{:recurring, d, rule}, span} -> {{d, span}, rule}
        other -> {other, nil}
      end

    case {date, time} do
      {nil, nil} ->
        :none

      {{d, ds}, nil} ->
        {:ok, d, nil, rule, [ds]}

      {{d, ds}, {{:time, t}, ts}} ->
        {:ok, d, t, rule, [ds, ts]}

      {{d, ds}, {{:datetime, _}, _}} ->
        {:ok, d, nil, rule, [ds]}

      {nil, {{:time, t}, ts}} ->
        {:ok, today, t, nil, [ts]}

      {nil, {{:datetime, dt}, ts}} ->
        {:ok, NaiveDateTime.to_date(dt), NaiveDateTime.to_time(dt), nil, [ts]}
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

        captures = Enum.map(groups, &capture(text, &1))

        case interpreter.(meaning, captures, pack) do
          {:ok, value} -> [{start, -len, position, value}]
          :error -> []
        end
      end)
    end)
  end

  # A captured group, lowercase with single spaces, or nil when it did not match.
  defp capture(_text, {start, _length}) when start < 0, do: nil

  defp capture(text, {start, length}),
    do: text |> binary_part(start, length) |> String.downcase() |> String.replace(~r/\s+/u, " ")

  # --- times --------------------------------------------------------------------

  defp interpret_time(:clock, [h, m | ampm], pack, _now, s),
    do: clock(h, int(m), List.first(ampm), pack, s)

  defp interpret_time(:hour_ampm, [h, ampm], pack, _now, s), do: clock(h, 0, ampm, pack, s)
  defp interpret_time(:at_hour, [h], pack, _now, s), do: clock(h, 0, nil, pack, s)

  # a time, or :morning, :afternoon or :evening as the file sets them (R14e)
  defp interpret_time(:time_word, [word], pack, _now, s) do
    case word(pack, :time_words, word) do
      %Time{} = time -> {:ok, {:time, time}}
      setting -> {:ok, {:time, Map.fetch!(s, setting)}}
    end
  end

  defp interpret_time(:in_time, [n, unit], pack, now, _s) do
    minutes = count(pack, n) * if(word(pack, :time_units, unit) == :hour, do: 60, else: 1)
    {:ok, {:datetime, NaiveDateTime.add(now, minutes * 60)}}
  end

  defp interpret_time(:now, _, _pack, now, _s), do: {:ok, {:datetime, now}}

  # With Agenda's clock, 12-hour times without am/pm fall in the twelve
  # hours from Morning (8:00 am to 7:59 pm by default, R14e); hours over
  # 12, 0 and a leading zero ("08:30") are read as a 24-hour clock. A
  # 24-hour clock reads every hour as written.
  defp clock(h, m, ampm, pack, s) do
    hour = int(h)

    hour =
      cond do
        ampm && hour > 12 -> nil
        ampm && String.starts_with?(ampm, "p") -> rem(hour, 12) + 12
        ampm -> rem(hour, 12)
        pack.clock() == :twenty_four -> hour
        hour == 0 or hour > 12 or String.starts_with?(h, "0") -> hour
        hour < 12 and Time.compare(Time.new!(hour, m, 0), s.morning) == :lt -> hour + 12
        true -> hour
      end

    case hour && Time.new(hour, m, 0) do
      {:ok, time} -> {:ok, {:time, time}}
      _ -> :error
    end
  end

  # --- interpreting matches ---------------------------------------------------

  defp interpret(:iso, [y, m, d], _pack, _today, _s), do: build(int(y), int(m), int(d))

  defp interpret(:numeric, [a, b | y], pack, today, _s) do
    {m, d} = if pack.numeric_order() == :day_month, do: {b, a}, else: {a, b}

    case List.first(y) do
      nil -> future(int(m), int(d), today)
      y -> build(year(y), int(m), int(d))
    end
  end

  defp interpret(:month_day, [m, d, y], pack, today, _s),
    do: month_date(word(pack, :months, m), int(d), y, today)

  defp interpret(:day_month, [d, m, y], pack, today, _s),
    do: month_date(word(pack, :months, m), int(d), y, today)

  defp interpret(:ordinal_of_month, [o, m, y], pack, today, _s),
    do: month_date(word(pack, :months, m), word(pack, :ordinals, o), y, today)

  defp interpret({:offset, days}, _, _pack, today, _s), do: {:ok, Date.add(today, days)}

  defp interpret(:offset_word, [word], pack, today, _s),
    do: {:ok, Date.add(today, word(pack, :offsets, word))}

  defp interpret(:in_units, [n, unit], pack, today, s),
    do: shift(today, count(pack, n), word(pack, :units, unit), s)

  defp interpret(:units_from_now, [n, unit], pack, today, s),
    do: shift(today, count(pack, n), word(pack, :units, unit), s)

  defp interpret(:units_ago, [n, unit], pack, today, s),
    do: shift(today, -count(pack, n), word(pack, :units, unit), s)

  defp interpret(:edge_of_period, [edge, which, period], pack, today, s) do
    period = word(pack, :periods, period)
    start = period_start(period, relative(pack, which), today, s)
    {:ok, if(word(pack, :edges, edge) == :end, do: period_end(period, start, s), else: start)}
  end

  defp interpret(:relative_period, [which, period], pack, today, s),
    do: {:ok, period_start(word(pack, :periods, period), relative(pack, which), today, s)}

  defp interpret(:relative_weekday, [which, day], pack, today, s) do
    start = period_start(:week, relative(pack, which), today, s)
    {:ok, Date.add(start, Integer.mod(word(pack, :weekdays, day) - s.week_start, 7))}
  end

  defp interpret(meaning, [day], pack, today, _s) when meaning in [:weekday, :weekday_abbr] do
    days = Integer.mod(word(pack, :weekdays, day) - Date.day_of_week(today), 7)
    {:ok, Date.add(today, days)}
  end

  # --- more phrases (R14d) ---

  defp interpret(:nth_quarter, [o], pack, today, s) do
    case word(pack, :ordinals, o) do
      n when n in 1..4 ->
        start = today.year |> Date.new!(s.quarter_start, 1) |> Date.shift(month: 3 * (n - 1))
        ended? = Date.compare(period_end(:quarter, start, s), today) == :lt
        {:ok, if(ended?, do: Date.shift(start, year: 1), else: start)}

      _ ->
        :error
    end
  end

  # "first Wednesday in November": this year's, unless it has passed
  defp interpret(:nth_weekday, [nth, day, m, nil], pack, today, _s) do
    {nth, weekday, month} = {nth(pack, nth), word(pack, :weekdays, day), word(pack, :months, m)}

    with {:ok, date} <- nth_weekday(today.year, month, nth, weekday) do
      if Date.compare(date, today) == :lt,
        do: nth_weekday(today.year + 1, month, nth, weekday),
        else: {:ok, date}
    end
  end

  defp interpret(:nth_weekday, [nth, day, m, y], pack, _today, _s),
    do: nth_weekday(year(y), word(pack, :months, m), nth(pack, nth), word(pack, :weekdays, day))

  defp interpret(:nth_weekday_relative, [nth, day, which], pack, today, s) do
    start = period_start(:month, relative(pack, which), today, s)
    nth_weekday(start.year, start.month, nth(pack, nth), word(pack, :weekdays, day))
  end

  defp interpret(:day_of_relative_month, [d, which], pack, today, s) do
    start = period_start(:month, relative(pack, which), today, s)
    build(start.year, start.month, day_number(pack, d))
  end

  defp interpret(meaning, [which, m], pack, today, s)
       when meaning in [:month_alone, :bare_month] do
    month = word(pack, :months, m)
    year = month_year(month, which && relative(pack, which), today)
    {:ok, DateSettings.month_alone_day(s, year, month)}
  end

  defp interpret(:edge_of_month, [edge, which, m], pack, today, _s) do
    month = word(pack, :months, m)
    start = Date.new!(month_year(month, which && relative(pack, which), today), month, 1)
    {:ok, if(word(pack, :edges, edge) == :end, do: Date.end_of_month(start), else: start)}
  end

  # --- recurring dates (R14a): a first date and a rule ---

  defp interpret(:recurring_weekday, [every, day], pack, today, _s) do
    weekday = word(pack, :weekdays, day)
    date = Date.add(today, Integer.mod(weekday - Date.day_of_week(today), 7))
    rule = %Recurrence{every: word(pack, :intervals, every), unit: :week, weekday: weekday}
    {:ok, {:recurring, date, rule}}
  end

  defp interpret(:recurring_unit, [every, unit], pack, today, _s),
    do: recurring(word(pack, :intervals, every), word(pack, :units, unit), today)

  defp interpret(:recurring_count, [n, unit], pack, today, _s),
    do: recurring(count(pack, n), word(pack, :units, unit), today)

  defp interpret(:recurring_day_of_month, [day], pack, today, _s) do
    day =
      case Integer.parse(day) do
        {n, ""} -> n
        _ -> word(pack, :ordinals, day)
      end

    if day in 1..31,
      do:
        {:ok,
         {:recurring, Recurrence.first_of_month_day(day, today),
          %Recurrence{unit: :month, day: day}}},
      else: :error
  end

  # The most recent such weekday before today ("i fredags").
  defp interpret(:past_weekday, [day], pack, today, _s) do
    days = Integer.mod(Date.day_of_week(today) - word(pack, :weekdays, day) - 1, 7) + 1
    {:ok, Date.add(today, -days)}
  end

  # --- helpers ----------------------------------------------------------------

  # Every `n` units, starting today.
  defp recurring(_n, :working_day, _today), do: :error
  defp recurring(n, :quarter, today), do: recurring(3 * n, :month, today)

  defp recurring(n, unit, today) do
    rule =
      case unit do
        :month -> %Recurrence{every: n, unit: :month, day: today.day}
        unit -> %Recurrence{every: n, unit: unit}
      end

    {:ok, {:recurring, today, rule}}
  end

  defp word(pack, kind, word), do: pack.words() |> Map.fetch!(kind) |> Map.fetch!(word)

  defp relative(_pack, nil), do: 0
  defp relative(pack, which), do: word(pack, :relative, which)

  # The first day of this period (offset 0), the next (1) or the last (-1),
  # with weeks, quarters and years starting as the file sets them (R14e).
  defp period_start(:week, offset, today, s) do
    back = Integer.mod(Date.day_of_week(today) - s.week_start, 7)
    Date.add(today, 7 * offset - back)
  end

  defp period_start(:month, offset, today, _s),
    do: today |> Date.beginning_of_month() |> Date.shift(month: offset)

  defp period_start(:quarter, offset, today, s),
    do:
      today
      |> Date.beginning_of_month()
      |> Date.shift(month: 3 * offset - Integer.mod(today.month - s.quarter_start, 3))

  defp period_start(:year, offset, today, s),
    do:
      today
      |> Date.beginning_of_month()
      |> Date.shift(month: 12 * offset - Integer.mod(today.month - s.year_start, 12))

  # The last day of the period starting at `start` (a week ends on its
  # last day, Friday by default).
  defp period_end(:week, start, s), do: Date.add(start, Integer.mod(s.week_end - s.week_start, 7))
  defp period_end(:month, start, _s), do: Date.end_of_month(start)
  defp period_end(:quarter, start, _s), do: start |> Date.shift(month: 3) |> Date.add(-1)
  defp period_end(:year, start, _s), do: start |> Date.shift(year: 1) |> Date.add(-1)

  # The year of a month named without one: "this April" is this year's,
  # "next April" the first after this month, "last April" the last before
  # it, and "April" alone this year's unless the month is over.
  defp month_year(month, nil, today),
    do: if(month >= today.month, do: today.year, else: today.year + 1)

  defp month_year(_month, 0, today), do: today.year

  defp month_year(month, offset, today) when offset > 0,
    do: if(month > today.month, do: today.year, else: today.year + 1)

  defp month_year(month, _offset, today),
    do: if(month < today.month, do: today.year, else: today.year - 1)

  # The nth (or the last) such weekday of a month, if there is one.
  defp nth_weekday(year, month, :last, weekday) do
    last = Date.new!(year, month, 1) |> Date.end_of_month()
    {:ok, Date.add(last, -Integer.mod(Date.day_of_week(last) - weekday, 7))}
  end

  defp nth_weekday(year, month, nth, weekday) do
    first = Date.new!(year, month, 1)
    date = Date.add(first, Integer.mod(weekday - Date.day_of_week(first), 7) + 7 * (nth - 1))
    if date.month == month, do: {:ok, date}, else: :error
  end

  defp nth(pack, word) do
    if Map.has_key?(Map.get(pack.words(), :last, %{}), word),
      do: :last,
      else: word(pack, :ordinals, word)
  end

  # "15", "15th", "15:e" or "fifteenth"
  defp day_number(pack, d) do
    case Integer.parse(d) do
      {n, _suffix} -> n
      :error -> word(pack, :ordinals, d)
    end
  end

  defp shift(today, n, :day, _s), do: {:ok, Date.add(today, n)}
  defp shift(today, n, :week, _s), do: {:ok, Date.add(today, 7 * n)}
  defp shift(today, n, :month, _s), do: {:ok, Date.shift(today, month: n)}
  defp shift(today, n, :quarter, _s), do: {:ok, Date.shift(today, month: 3 * n)}
  defp shift(today, n, :year, _s), do: {:ok, Date.shift(today, year: n)}
  defp shift(today, n, :working_day, s), do: {:ok, working_days(today, n, s)}

  # `n` working days on (or back, when negative): days inside the week.
  defp working_days(date, 0, _s), do: date

  defp working_days(date, n, s) do
    step = if n > 0, do: 1, else: -1
    date = Date.add(date, step)

    if DateSettings.working_day?(s, Date.day_of_week(date)),
      do: working_days(date, n - step, s),
      else: working_days(date, n, s)
  end

  defp month_date(m, d, nil, today), do: future(m, d, today)
  defp month_date(m, d, y, _today), do: build(year(y), m, d)

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
