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

  Times of day are recognised so they do not get in the way ("Tuesday at
  3:00"), but ignored: items carry dates only. Recurring dates ("every
  Monday"), working days, quarters and "first Wednesday in November" are
  not supported yet.
  """

  @weekdays [
    {"monday", 1},
    {"mon", 1},
    {"tuesday", 2},
    {"tues", 2},
    {"tue", 2},
    {"wednesday", 3},
    {"wed", 3},
    {"thursday", 4},
    {"thurs", 4},
    {"thur", 4},
    {"thu", 4},
    {"friday", 5},
    {"fri", 5},
    {"saturday", 6},
    {"sat", 6},
    {"sunday", 7},
    {"sun", 7}
  ]

  @full_weekdays ~w(monday tuesday wednesday thursday friday saturday sunday)

  @months [
    {"january", 1},
    {"jan", 1},
    {"february", 2},
    {"feb", 2},
    {"march", 3},
    {"mar", 3},
    {"april", 4},
    {"apr", 4},
    {"may", 5},
    {"june", 6},
    {"jun", 6},
    {"july", 7},
    {"jul", 7},
    {"august", 8},
    {"aug", 8},
    {"september", 9},
    {"sept", 9},
    {"sep", 9},
    {"october", 10},
    {"oct", 10},
    {"november", 11},
    {"nov", 11},
    {"december", 12},
    {"dec", 12}
  ]

  @numbers %{
    "a" => 1,
    "an" => 1,
    "one" => 1,
    "two" => 2,
    "three" => 3,
    "four" => 4,
    "five" => 5,
    "six" => 6,
    "seven" => 7,
    "eight" => 8,
    "nine" => 9,
    "ten" => 10,
    "eleven" => 11,
    "twelve" => 12
  }

  @ordinals ~w(first second third fourth fifth sixth seventh eighth ninth tenth eleventh twelfth
               thirteenth fourteenth fifteenth sixteenth seventeenth eighteenth nineteenth twentieth
               twenty-first twenty-second twenty-third twenty-fourth twenty-fifth twenty-sixth
               twenty-seventh twenty-eighth twenty-ninth thirtieth thirty-first)

  # Regex alternations, longest first so that "monday" is tried before "mon".
  alt = fn words ->
    words |> Enum.sort_by(&(-String.length(&1))) |> Enum.map_join("|", &Regex.escape/1)
  end

  @w_all alt.(Enum.map(@weekdays, &elem(&1, 0)))
  @w_full alt.(@full_weekdays)
  @w_abbr alt.(Enum.map(@weekdays, &elem(&1, 0)) -- @full_weekdays)
  @m alt.(Enum.map(@months, &elem(&1, 0)))
  @n "\\d+|" <> alt.(Map.keys(@numbers))
  @ord alt.(@ordinals)
  @unit "days?|weeks?|months?"
  @time "\\d{1,2}(?::\\d{2})?\\s*(?:a\\.?m\\.?|p\\.?m\\.?)?|noon|midnight|morning|afternoon|evening|tonight|tonite"

  # {name, pattern}; each pattern is matched as whole words, ignoring case.
  @rules [
    {:iso, "(\\d{4})-(\\d{1,2})-(\\d{1,2})"},
    {:numeric, "(\\d{1,2})/(\\d{1,2})(?:/(\\d{4}|\\d{2}))?"},
    {:month_day, "(#{@m})\\.?\\s+(\\d{1,2})(?:st|nd|rd|th)?(?:,?\\s+(\\d{4}))?"},
    {:day_month,
     "(?:the\\s+)?(\\d{1,2})(?:st|nd|rd|th)?\\s+(?:of\\s+)?(#{@m})\\.?(?:,?\\s+(\\d{4}))?"},
    {:ordinal_of_month, "(?:the\\s+)?(#{@ord})\\s+of\\s+(#{@m})\\.?(?:,?\\s+(\\d{4}))?"},
    {:day_after_tomorrow, "(?:the\\s+)?day\\s+after\\s+tomorrow"},
    {:day_before_yesterday, "(?:the\\s+)?day\\s+before\\s+yesterday"},
    {:fortnight, "in\\s+a\\s+fortnight"},
    {:in_units, "in\\s+(#{@n})\\s+(#{@unit})"},
    {:units_from_now, "(#{@n})\\s+(#{@unit})\\s+from\\s+(?:today|now)"},
    {:units_ago, "(#{@n})\\s+(#{@unit})\\s+ago"},
    {:edge_of_period,
     "(beginning|beg|end)\\s+of\\s+(?:the\\s+)?(this\\s+|next\\s+|nxt\\s+|last\\s+)?(week|month)"},
    {:relative_period, "(this|next|nxt|last)\\s+(week|month|year)"},
    {:relative_weekday, "(this|next|nxt|last)\\s+(#{@w_all})"},
    {:simple, "(today|tomorrow|tmorrow|yesterday|ystday)"},
    {:weekday, "(#{@w_full})"},
    {:weekday_after_word, "(?:on|by|until|till)\\s+(#{@w_abbr})\\.?"},
    {:weekday_abbr, "(#{@w_abbr})"}
  ]

  # {name, whole-word pattern, number of capture groups}
  @compiled (for {name, pattern} <- @rules do
               groups = length(Regex.scan(~r/(?<!\\)\((?!\?)/, pattern))
               {name, "(?<![\\p{L}\\p{N}])(?:#{pattern})(?![\\p{L}\\p{N}])", groups}
             end)

  # Bare abbreviations ("sat", "sun", "wed") are too common as words to be
  # read as dates in free text; they count only when typed on their own.
  @text_rules Enum.reject(@compiled, fn {name, _, _} -> name == :weekday_abbr end)

  @time_rest "^\\s*(?:at\\s+|@\\s*)?(?:#{@time})?\\s*\\.?\\s*$"

  @doc """
  Parses a date typed on its own, such as an entry in a date column.
  A trailing time ("at 3:30 pm") is accepted and ignored.
  """
  @spec parse(String.t(), Date.t()) :: {:ok, Date.t()} | :error
  def parse(text, %Date{} = today) do
    text = String.trim(text)

    case first_match(text, today, @compiled) do
      {:ok, date, 0, length} ->
        rest = binary_part(text, length, byte_size(text) - length)
        if Regex.match?(Regex.compile!(@time_rest, "iu"), rest), do: {:ok, date}, else: :error

      _ ->
        :error
    end
  end

  @doc """
  Finds the first date in free text. Returns the date and the words it was
  read from (used to notice when an edit changes the date phrase).
  """
  @spec extract(String.t(), Date.t()) :: {:ok, Date.t(), String.t()} | :none
  def extract(text, %Date{} = today) do
    case first_match(text, today, @text_rules) do
      {:ok, date, start, length} ->
        phrase =
          text |> binary_part(start, length) |> String.downcase() |> String.replace(~r/\s+/u, " ")

        {:ok, date, phrase}

      :none ->
        :none
    end
  end

  # The earliest valid match of any rule (the longest one when two start
  # at the same place), as {:ok, date, byte_start, byte_length}.
  defp first_match(text, today, rules) do
    rules
    |> Enum.flat_map(fn {name, pattern, group_count} ->
      regex = Regex.compile!(pattern, "iu")

      regex
      |> Regex.scan(text, return: :index)
      |> Enum.flat_map(fn [{start, len} | groups] ->
        # unmatched optional groups at the end are left out by Regex.scan
        groups = groups ++ List.duplicate({-1, 0}, group_count - length(groups))

        captures =
          Enum.map(groups, fn {s, l} ->
            if s < 0, do: nil, else: String.downcase(binary_part(text, s, l))
          end)

        case interpret(name, captures, today) do
          {:ok, date} -> [{start, -len, date}]
          :error -> []
        end
      end)
    end)
    |> Enum.min(fn -> nil end)
    |> case do
      nil -> :none
      {start, neg_len, date} -> {:ok, date, start, -neg_len}
    end
  end

  # --- interpreting matches ---------------------------------------------------

  defp interpret(:iso, [y, m, d], _today), do: build(int(y), int(m), int(d))

  defp interpret(:numeric, [m, d, nil], today), do: future(int(m), int(d), today)
  defp interpret(:numeric, [m, d, y], _today), do: build(year(y), int(m), int(d))

  defp interpret(:month_day, [m, d, y], today), do: month_date(month(m), int(d), y, today)
  defp interpret(:day_month, [d, m, y], today), do: month_date(month(m), int(d), y, today)

  defp interpret(:ordinal_of_month, [o, m, y], today),
    do: month_date(month(m), Enum.find_index(@ordinals, &(&1 == o)) + 1, y, today)

  defp interpret(:day_after_tomorrow, _, today), do: {:ok, Date.add(today, 2)}
  defp interpret(:day_before_yesterday, _, today), do: {:ok, Date.add(today, -2)}
  defp interpret(:fortnight, _, today), do: {:ok, Date.add(today, 14)}

  defp interpret(:in_units, [n, unit], today), do: shift(today, count(n), unit)
  defp interpret(:units_from_now, [n, unit], today), do: shift(today, count(n), unit)
  defp interpret(:units_ago, [n, unit], today), do: shift(today, -count(n), unit)

  defp interpret(:edge_of_period, [edge, which, period], today) do
    start = period_start(period, which |> to_string() |> String.trim() |> relative(), today)

    case {edge, period} do
      {"end", "week"} -> {:ok, Date.add(start, 4)}
      {"end", "month"} -> {:ok, Date.end_of_month(start)}
      _ -> {:ok, start}
    end
  end

  defp interpret(:relative_period, [which, period], today),
    do: {:ok, period_start(period, relative(which), today)}

  defp interpret(:relative_weekday, [which, day], today) do
    monday = Date.beginning_of_week(today)
    {:ok, Date.add(monday, 7 * relative(which) + weekday(day) - 1)}
  end

  defp interpret(:simple, [word], today) do
    case word do
      "today" -> {:ok, today}
      w when w in ["tomorrow", "tmorrow"] -> {:ok, Date.add(today, 1)}
      _ -> {:ok, Date.add(today, -1)}
    end
  end

  defp interpret(name, [day], today)
       when name in [:weekday, :weekday_after_word, :weekday_abbr] do
    {:ok, Date.add(today, Integer.mod(weekday(day) - Date.day_of_week(today), 7))}
  end

  # --- helpers ----------------------------------------------------------------

  defp relative(""), do: 0
  defp relative("this"), do: 0
  defp relative(w) when w in ["next", "nxt"], do: 1
  defp relative("last"), do: -1

  defp period_start("week", offset, today),
    do: today |> Date.beginning_of_week() |> Date.add(7 * offset)

  defp period_start("month", offset, today),
    do: today |> Date.beginning_of_month() |> Date.shift(month: offset)

  defp period_start("year", offset, today), do: Date.new!(today.year + offset, 1, 1)

  defp shift(today, n, unit) do
    cond do
      String.starts_with?(unit, "day") -> {:ok, Date.add(today, n)}
      String.starts_with?(unit, "week") -> {:ok, Date.add(today, 7 * n)}
      true -> {:ok, Date.shift(today, month: n)}
    end
  end

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

  defp count(n), do: Map.get_lazy(@numbers, n, fn -> int(n) end)
  defp int(s), do: String.to_integer(s)
  defp month(m), do: Enum.find_value(@months, fn {name, n} -> if name == m, do: n end)
  defp weekday(d), do: Enum.find_value(@weekdays, fn {name, n} -> if name == d, do: n end)

  @doc "Formats a date the way columns display it."
  @spec format(Date.t() | nil) :: String.t()
  def format(nil), do: ""
  def format(%Date{} = date), do: Date.to_iso8601(date)
end
