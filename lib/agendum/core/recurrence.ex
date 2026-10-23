defmodule Agendum.Core.Recurrence do
  @moduledoc """
  The rule of a recurring When date (SPEC R14a; User's Guide 7-11 to 7-12):
  "every Monday", "every other week", "the 30th of every month", "every
  quarter". An item keeps its rule next to its When date, the *base date*;
  when it is marked done, a copy gets `next/2` of that date.

    * `unit`: `:day`, `:week`, `:month` or `:year`, every `every` of them
    * `weekday`: for weeks named by a day (1 = Monday … 7 = Sunday)
    * `day`: for months, the day of the month (kept, so the 30th stays the
      30th after a shorter month)

  The rule is data, not words, so it does not depend on the language it was
  typed in. Pure.
  """

  @type t :: %__MODULE__{
          every: pos_integer,
          unit: :day | :week | :month | :year,
          weekday: 1..7 | nil,
          day: 1..31 | nil
        }
  defstruct every: 1, unit: :day, weekday: nil, day: nil

  @weekdays ~w(Monday Tuesday Wednesday Thursday Friday Saturday Sunday)

  @doc "The next date after the base date."
  @spec next(t, Date.t()) :: Date.t()
  def next(%__MODULE__{unit: :day, every: n}, base), do: Date.add(base, n)
  def next(%__MODULE__{unit: :week, every: n}, base), do: Date.add(base, 7 * n)
  def next(%__MODULE__{unit: :year, every: n}, base), do: Date.shift(base, year: n)

  def next(%__MODULE__{unit: :month, every: n, day: day}, base) do
    first = base |> Date.beginning_of_month() |> Date.shift(month: n)
    %{first | day: min(day || base.day, Date.days_in_month(first))}
  end

  @doc """
  The dates in `from`..`to` (both included) on which an item with this rule
  and `base` date recurs, none before the base date (R14a; as Agenda 2.0
  shows them in datebooks and date filters). Each is counted from the base
  date, not from the one before it, so a month keeps its day however far
  away: the 30th of every month falls on the 28th in February and on the
  30th again in March, and every year from the 29th of February comes back
  to the 29th in a leap year.
  """
  @spec occurrences(t, Date.t(), Date.t(), Date.t()) :: [Date.t()]
  def occurrences(%__MODULE__{} = rule, base, from, to) do
    # `Stream.iterate/2` counts 0, 1, 2 … lazily; `take_while` stops at the
    # first occurrence past `to`, so only the dates needed are worked out
    rule
    |> first_index(base, from)
    |> Stream.iterate(&(&1 + 1))
    |> Stream.map(&nth(rule, base, &1))
    |> Stream.take_while(&(Date.compare(&1, to) != :gt))
    |> Enum.filter(&(Date.compare(&1, from) != :lt))
  end

  @doc """
  Whether the rule recurs in `from`..`to`; either end may be nil, open as
  a date filter's can be ("from 2026-10-20 on").
  """
  @spec occurs?(t, Date.t(), Date.t() | nil, Date.t() | nil) :: boolean
  # open at the end: there is always a later occurrence
  def occurs?(_rule, _base, _from, nil), do: true
  def occurs?(_rule, base, nil, to), do: Date.compare(base, to) != :gt
  def occurs?(rule, base, from, to), do: occurrences(rule, base, from, to) != []

  @doc "The first occurrence on or after `date` (the base date when `date` is before it)."
  @spec first(t, Date.t(), Date.t()) :: Date.t()
  def first(%__MODULE__{} = rule, base, date) do
    rule
    |> first_index(base, date)
    |> Stream.iterate(&(&1 + 1))
    |> Stream.map(&nth(rule, base, &1))
    |> Enum.find(&(Date.compare(&1, date) != :lt))
  end

  # The `k`th occurrence, the base date the 0th, counted from the base date
  defp nth(%__MODULE__{unit: :day, every: n}, base, k), do: Date.add(base, k * n)
  defp nth(%__MODULE__{unit: :week, every: n}, base, k), do: Date.add(base, 7 * k * n)
  defp nth(%__MODULE__{unit: :year, every: n}, base, k), do: Date.shift(base, year: k * n)

  defp nth(%__MODULE__{unit: :month, every: n, day: day}, base, k) do
    first = base |> Date.beginning_of_month() |> Date.shift(month: k * n)
    %{first | day: min(day || base.day, Date.days_in_month(first))}
  end

  # An index at or just before the first occurrence on or after `date`,
  # worked out by arithmetic, so a range years from the base date does not
  # step through every occurrence before it. Never below 0: nothing comes
  # before the base date.
  defp first_index(rule, base, date) do
    case Date.compare(date, base) do
      :gt -> max(span(rule, base, date) - 1, 0)
      _ -> 0
    end
  end

  # how many whole rule periods lie between the base date and `date`
  defp span(%__MODULE__{unit: :day, every: n}, base, date), do: div(Date.diff(date, base), n)

  defp span(%__MODULE__{unit: :week, every: n}, base, date),
    do: div(Date.diff(date, base), 7 * n)

  defp span(%__MODULE__{unit: :month, every: n}, base, date),
    do: div((date.year - base.year) * 12 + date.month - base.month, n)

  defp span(%__MODULE__{unit: :year, every: n}, base, date), do: div(date.year - base.year, n)

  @doc "The first date of a monthly rule on `day`, today or later."
  @spec first_of_month_day(pos_integer, Date.t()) :: Date.t()
  def first_of_month_day(day, today) do
    this = %{today | day: min(day, Date.days_in_month(today))}

    if Date.compare(this, today) == :lt,
      do: next(%__MODULE__{unit: :month, day: day}, this),
      else: this
  end

  @doc "The rule in words, as Item Properties shows it."
  @spec describe(t) :: String.t()
  def describe(%__MODULE__{unit: :month, every: 1, day: day}) when day != nil,
    do: "the #{ordinal(day)} of every month"

  def describe(%__MODULE__{unit: :week, every: n, weekday: day}) when day != nil do
    name = Enum.at(@weekdays, day - 1)
    if n == 1, do: "every " <> name, else: "every #{ordinal(n)} " <> name
  end

  def describe(%__MODULE__{unit: unit, every: 1}), do: "every #{unit}"
  def describe(%__MODULE__{unit: unit, every: n}), do: "every #{n} #{unit}s"

  defp ordinal(n) when rem(n, 100) in 11..13, do: "#{n}th"
  defp ordinal(n) when rem(n, 10) == 1, do: "#{n}st"
  defp ordinal(n) when rem(n, 10) == 2, do: "#{n}nd"
  defp ordinal(n) when rem(n, 10) == 3, do: "#{n}rd"
  defp ordinal(n), do: "#{n}th"
end
