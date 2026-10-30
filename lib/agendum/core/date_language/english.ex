# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.DateLanguage.English do
  @moduledoc """
  English dates and times, as Agenda 2.0 reads them (SPEC R14, R14a, R14b;
  User's Guide chapters 6 and 7): "friday", "next week", "11/20/90", "the
  5th of November", "in 2 days", "Thursday at 3:30 pm", "tonight", and
  recurring dates: "every Monday", "every other week", "the 15th of every
  month", "every quarter"; and (R14d) "in five working days", "this
  quarter", "first Wednesday in November", "the 15th of next month",
  "next April", "end of March", "Nov/12/90".

  A month named alone counts in item text only after "next", "last",
  "this", "in", "by", "until" or "during", and "May" only after "next" or
  "last", so that "you may" stays text.
  """

  @behaviour Agendum.Core.DateLanguage
  alias Agendum.Core.Recurrence
  import Agendum.Core.DateLanguage, only: [alt: 1, alt: 2]

  @weekdays %{
    "monday" => 1,
    "mon" => 1,
    "tuesday" => 2,
    "tues" => 2,
    "tue" => 2,
    "wednesday" => 3,
    "wed" => 3,
    "thursday" => 4,
    "thurs" => 4,
    "thur" => 4,
    "thu" => 4,
    "friday" => 5,
    "fri" => 5,
    "saturday" => 6,
    "sat" => 6,
    "sunday" => 7,
    "sun" => 7
  }
  @full_weekdays ~w(monday tuesday wednesday thursday friday saturday sunday)

  @months %{
    "january" => 1,
    "jan" => 1,
    "february" => 2,
    "feb" => 2,
    "march" => 3,
    "mar" => 3,
    "april" => 4,
    "apr" => 4,
    "may" => 5,
    "june" => 6,
    "jun" => 6,
    "july" => 7,
    "jul" => 7,
    "august" => 8,
    "aug" => 8,
    "september" => 9,
    "sept" => 9,
    "sep" => 9,
    "october" => 10,
    "oct" => 10,
    "november" => 11,
    "nov" => 11,
    "december" => 12,
    "dec" => 12
  }

  @full_months ~w(january february march april may june july august september october
                  november december)

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
               thirteenth fourteenth fifteenth sixteenth seventeenth eighteenth nineteenth
               twentieth twenty-first twenty-second twenty-third twenty-fourth twenty-fifth
               twenty-sixth twenty-seventh twenty-eighth twenty-ninth thirtieth thirty-first)

  @words %{
    weekdays: @weekdays,
    months: @months,
    numbers: @numbers,
    ordinals: @ordinals |> Enum.with_index(1) |> Map.new(),
    relative: %{"this" => 0, "next" => 1, "nxt" => 1, "last" => -1},
    last: %{"last" => :last},
    periods: %{"week" => :week, "month" => :month, "quarter" => :quarter, "year" => :year},
    units: %{
      "day" => :day,
      "days" => :day,
      "working day" => :working_day,
      "working days" => :working_day,
      "week" => :week,
      "weeks" => :week,
      "month" => :month,
      "months" => :month,
      "quarter" => :quarter,
      "quarters" => :quarter,
      "year" => :year,
      "years" => :year
    },
    intervals: %{"each" => 1, "every" => 1, "evry" => 1, "every other" => 2, "each other" => 2},
    edges: %{"beginning" => :start, "beg" => :start, "end" => :end},
    offsets: %{"today" => 0, "tomorrow" => 1, "tmorrow" => 1, "yesterday" => -1, "ystday" => -1},
    time_words: %{
      "noon" => ~T[12:00:00],
      "midnight" => ~T[00:00:00],
      "morning" => :morning,
      "afternoon" => :afternoon,
      "evening" => :evening,
      "tonight" => :evening,
      "tonite" => :evening
    },
    time_units: %{
      "minute" => :minute,
      "minutes" => :minute,
      "min" => :minute,
      "mins" => :minute,
      "hour" => :hour,
      "hours" => :hour,
      "hr" => :hour,
      "hrs" => :hour
    }
  }

  @impl true
  def name, do: "english"

  @impl true
  def words, do: @words

  @impl true
  def numeric_order, do: :month_day

  @impl true
  def clock, do: :agenda

  @impl true
  def text_excluded, do: [:weekday_abbr, :bare_month]

  @impl true
  def rules do
    m = alt(__MODULE__, :months)
    n = "\\d+|" <> alt(__MODULE__, :numbers)
    unit = alt(__MODULE__, :units)
    w_all = alt(__MODULE__, :weekdays)
    w_full = alt(@full_weekdays)
    w_abbr = alt(Map.keys(@weekdays) -- @full_weekdays)

    every = alt(__MODULE__, :intervals)
    ordinals = alt(__MODULE__, :ordinals)
    nth = ordinals <> "|last"
    which = "this|next|nxt|last"
    period = alt(__MODULE__, :periods)
    edge = alt(__MODULE__, :edges)
    full = alt(@full_months)
    not_may = alt(@full_months -- ["may"])

    [
      {:recurring_weekday, "(#{every})\\s+(#{w_all})"},
      {:recurring_count, "(?:each|every|evry)\\s+(#{n})\\s+(#{unit})"},
      {:recurring_unit, "(#{every})\\s+(#{unit})"},
      {:recurring_day_of_month,
       "(?:the\\s+)?(\\d{1,2})(?:st|nd|rd|th)?\\s+of\\s+(?:each|every|evry)\\s+month"},
      {:recurring_day_of_month,
       "(?:the\\s+)?(#{ordinals})\\s+of\\s+(?:each|every|evry)\\s+month"},
      {:iso, "(\\d{4})-(\\d{1,2})-(\\d{1,2})"},
      {:numeric, "(\\d{1,2})/(\\d{1,2})(?:/(\\d{4}|\\d{2}))?"},
      {:month_day, "(#{m})/(\\d{1,2})(?:/(\\d{4}|\\d{2}))?"},
      {:month_day, "(#{m})\\.?\\s+(\\d{1,2})(?:st|nd|rd|th)?(?:,?\\s+(\\d{4}))?"},
      {:day_month,
       "(?:the\\s+)?(\\d{1,2})(?:st|nd|rd|th)?\\s+(?:of\\s+)?(#{m})\\.?(?:,?\\s+(\\d{4}))?"},
      {:ordinal_of_month,
       "(?:the\\s+)?(#{alt(__MODULE__, :ordinals)})\\s+of\\s+(#{m})\\.?(?:,?\\s+(\\d{4}))?"},
      {:nth_weekday_relative,
       "(?:the\\s+)?(#{nth})\\s+(#{w_all})\\s+(?:in|of)\\s+(?:the\\s+)?(?:(#{which})\\s+)?month"},
      {:nth_weekday,
       "(?:the\\s+)?(#{nth})\\s+(#{w_all})\\s+(?:in|of)\\s+(#{m})\\.?(?:,?\\s+(\\d{4}))?"},
      {:day_of_relative_month,
       "(?:the\\s+)?(\\d{1,2}(?:st|nd|rd|th)?|#{ordinals})\\s+of\\s+(?:the\\s+)?(?:(#{which})\\s+)?month"},
      {:nth_quarter, "(?:the\\s+)?(#{ordinals})\\s+quarter"},
      {:edge_of_month, "(#{edge})\\s+of\\s+(?:(#{which})\\s+)?(#{full})"},
      {:month_alone, "(next|nxt|last)\\s+(#{full})"},
      {:month_alone, "(?:(?:in|by|until|till|during)\\s+)?(this)\\s+(#{not_may})"},
      {:month_alone, "(?:in|by|until|till|during)\\s+(?:(#{which})\\s+)?(#{not_may})"},
      {:bare_month, "(?:(#{which})\\s+)?(#{full})"},
      {{:offset, 2}, "(?:the\\s+)?day\\s+after\\s+tomorrow"},
      {{:offset, -2}, "(?:the\\s+)?day\\s+before\\s+yesterday"},
      {{:offset, 14}, "in\\s+a\\s+fortnight"},
      {:in_units, "in\\s+(#{n})\\s+(#{unit})"},
      {:units_from_now, "(#{n})\\s+(#{unit})\\s+from\\s+(?:today|now)"},
      {:units_ago, "(#{n})\\s+(#{unit})\\s+ago"},
      {:edge_of_period, "(#{edge})\\s+of\\s+(?:the\\s+)?(?:(#{which})\\s+)?(#{period})"},
      {:relative_period, "(#{which})\\s+(#{period})"},
      {:relative_weekday, "(this|next|nxt|last)\\s+(#{w_all})"},
      {:offset_word, "(#{alt(__MODULE__, :offsets)})"},
      {:weekday, "(#{w_full})"},
      {:weekday, "(?:on|by|until|till)\\s+(#{w_abbr})\\.?"},
      {:weekday_abbr, "(#{w_abbr})"}
    ]
  end

  @impl true
  def time_rules do
    n = "\\d+|" <> alt(__MODULE__, :numbers)
    time_unit = alt(__MODULE__, :time_units)

    [
      {:clock,
       "(?:(?:at|@)\\s*)?(?<![:\\d])(\\d{1,2}):(\\d{2})(?!:\\d)\\s*(a\\.?m\\.?|p\\.?m\\.?)?"},
      {:hour_ampm, "(?:(?:at|@)\\s*)?(\\d{1,2})\\s*(a\\.?m\\.?|p\\.?m\\.?)"},
      {:at_hour, "(?:at|@)\\s*(\\d{1,2})"},
      {:time_word, "(#{alt(__MODULE__, :time_words)})"},
      {:in_time, "in\\s+(#{n})\\s+(#{time_unit})"},
      {:in_time, "(#{n})\\s+(#{time_unit})\\s+from\\s+now"},
      {:now, "(now)"}
    ]
  end

  # --- a recurring date offered for editing (R14a) ---------------------------

  @weekday_names ~w(Monday Tuesday Wednesday Thursday Friday Saturday Sunday)

  # Only what `rules/0` reads back: "every other" is its one interval word
  # past "every", so "every 3rd Monday" has no English words (nil)
  @impl true
  def recurrence_phrase(%Recurrence{unit: :week, weekday: day, every: n}) when day != nil,
    do: if(n in [1, 2], do: interval(n) <> " " <> Enum.at(@weekday_names, day - 1))

  def recurrence_phrase(%Recurrence{unit: :month, every: 1, day: day}) when day != nil,
    do: "the #{ordinal(day)} of every month"

  def recurrence_phrase(%Recurrence{unit: unit, every: 1}), do: "every #{unit}"
  def recurrence_phrase(%Recurrence{unit: unit, every: n}), do: "every #{n} #{unit}s"

  defp interval(1), do: "every"
  defp interval(2), do: "every other"

  defp ordinal(n) when rem(n, 100) in 11..13, do: "#{n}th"
  defp ordinal(n) when rem(n, 10) == 1, do: "#{n}st"
  defp ordinal(n) when rem(n, 10) == 2, do: "#{n}nd"
  defp ordinal(n) when rem(n, 10) == 3, do: "#{n}rd"
  defp ordinal(n), do: "#{n}th"

  # "strtng" is Agenda's own, as its ALT-F2 offers it (checked 2026-10-23)
  @impl true
  def starting, do: ["starting", "strtng"]

  # with am or pm, so an hour from 1 to 7 is not read as afternoon
  @impl true
  def time_phrase(%Time{hour: hour, minute: minute}) do
    clock = rem(hour + 11, 12) + 1
    half = if hour < 12, do: "am", else: "pm"
    "at #{clock}:#{String.pad_leading(Integer.to_string(minute), 2, "0")}#{half}"
  end
end
