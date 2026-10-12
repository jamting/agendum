defmodule Agenda.Core.MonthCalendar do
  @moduledoc """
  The month shown by the pop-up calendar (SPEC R46; User's Guide 6-14 to
  6-17), and the moves of its highlight. Pure.

  A month is six weeks of seven days, starting on the file's beginning of
  week (R14e); days outside the month are nil. Moves keep to Agenda's
  calendar, 1 January 1 AD to 31 December 5000, and a month or year move
  keeps the day where the new month has it (31 January plus a month is 28
  February).
  """

  @first ~D[0001-01-01]
  @last ~D[5000-12-31]

  @type move :: :day | :week | :month | :year | :first | :last

  @doc "The weeks of `date`'s month, each seven days from `week_start` (1 = Monday)."
  @spec weeks(Date.t(), 1..7) :: [[Date.t() | nil]]
  def weeks(date, week_start) do
    first = Date.beginning_of_month(date)
    lead = Integer.mod(Date.day_of_week(first) - week_start, 7)
    days = List.duplicate(nil, lead) ++ Enum.to_list(Date.range(first, Date.end_of_month(date)))
    days = days ++ List.duplicate(nil, 42 - length(days))
    Enum.chunk_every(days, 7)
  end

  @doc """
  Moves the highlight: `n` days, weeks, months or years (negative: back), or
  to the first or last day of the month (`n` ignored).
  """
  @spec move(Date.t(), move, integer) :: Date.t()
  def move(date, :day, n), do: clamp(Date.add(date, n))
  def move(date, :week, n), do: clamp(Date.add(date, 7 * n))
  def move(date, :first, _n), do: Date.beginning_of_month(date)
  def move(date, :last, _n), do: Date.end_of_month(date)
  def move(date, :month, n), do: shift(date, div(n, 12), rem(n, 12))
  def move(date, :year, n), do: shift(date, n, 0)

  # years and months, clamping the day to the new month's length
  defp shift(date, years, months) do
    total = (date.year + years) * 12 + date.month - 1 + months
    {year, month} = {div(total, 12), rem(total, 12) + 1}

    if year < 1 or year > 5000 do
      if year < 1, do: @first, else: @last
    else
      day = min(date.day, Calendar.ISO.days_in_month(year, month))
      clamp(Date.new!(year, month, day))
    end
  end

  defp clamp(date) do
    cond do
      Date.compare(date, @first) == :lt -> @first
      Date.compare(date, @last) == :gt -> @last
      true -> date
    end
  end
end
