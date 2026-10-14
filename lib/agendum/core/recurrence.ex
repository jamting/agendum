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
