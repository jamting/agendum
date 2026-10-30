# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.DateSettings do
  @moduledoc """
  How a file reads dates (SPEC R14e; Agenda's Global Date Settings, User's
  Guide 7-15 to 7-16):

    * `week_start`, `week_end`: the first and last day of the week (1 =
      Monday … 7 = Sunday); "this week" and "next week" start on the
      first, "end of week" is the last, and working days are the days
      from the first to the last
    * `quarter_start`: the month the first quarter starts in
    * `year_start`: the month the year starts in ("this year", "end of the
      year")
    * `month_alone`: the day a month named alone means ("next April"):
      `:first`, `:last` or a day number (the month's last day if it is
      shorter)
    * `morning`, `afternoon`, `evening`: the times of those words;
      `morning` also starts the twelve hours that times without am/pm
      fall in

  Number order (11/5 or 5/11) is the reader's, set by the date language
  (ADR 0009), not the file's. Quarters and years start on the 1st. Pure.
  """

  @type month_alone :: :first | :last | 2..31
  @type t :: %__MODULE__{
          week_start: 1..7,
          week_end: 1..7,
          quarter_start: 1..12,
          year_start: 1..12,
          month_alone: month_alone,
          morning: Time.t(),
          afternoon: Time.t(),
          evening: Time.t()
        }
  defstruct week_start: 1,
            week_end: 5,
            quarter_start: 1,
            year_start: 1,
            month_alone: :first,
            morning: ~T[08:00:00],
            afternoon: ~T[14:00:00],
            evening: ~T[17:00:00]

  @month_alone [:first, :last | Enum.to_list(2..31)]

  @doc "The setting with the next (step 1) or previous (step -1) choice."
  @spec cycle(t, atom, 1 | -1) :: t
  def cycle(s, field, step) when field in [:week_start, :week_end],
    do: Map.update!(s, field, &(Integer.mod(&1 - 1 + step, 7) + 1))

  def cycle(s, field, step) when field in [:quarter_start, :year_start],
    do: Map.update!(s, field, &(Integer.mod(&1 - 1 + step, 12) + 1))

  def cycle(s, :month_alone, step) do
    index = Enum.find_index(@month_alone, &(&1 == s.month_alone)) || 0
    %{s | month_alone: Enum.at(@month_alone, Integer.mod(index + step, length(@month_alone)))}
  end

  def cycle(s, field, step) when field in [:morning, :afternoon, :evening],
    do: Map.update!(s, field, &Time.add(&1, step * 30 * 60))

  @doc "The day a month named alone means in `year`."
  @spec month_alone_day(t, integer, 1..12) :: Date.t()
  def month_alone_day(s, year, month) do
    first = Date.new!(year, month, 1)

    case s.month_alone do
      :first -> first
      :last -> Date.end_of_month(first)
      day -> Date.new!(year, month, min(day, Date.days_in_month(first)))
    end
  end

  @doc "Whether a day of the week (1–7) is a working day: inside the week."
  @spec working_day?(t, 1..7) :: boolean
  def working_day?(s, weekday),
    do: Integer.mod(weekday - s.week_start, 7) <= Integer.mod(s.week_end - s.week_start, 7)
end
