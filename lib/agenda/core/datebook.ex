defmodule Agenda.Core.Datebook do
  @moduledoc """
  The settings of a datebook view (SPEC R47; User's Guide chapter 10): a
  view like a page of an appointment book, whose sections are time slots
  instead of categories. Pure.

    * `date_category`: the date category whose dates place items (When)
    * `end_category`: an optional date category for when items end; an
      item then shows in every slot from its start to its end
    * `section_category`: the category heading every section; only its
      items show (by default the date category: every dated item)
    * `period`: `:day`, `:week` (default), `:month` or `:quarter`
    * `interval`: what one slot covers: 15, 30 or 60 minutes for a day
      (default 60), `:day` or `:week` for a month (default `:week`),
      `:day`, `:week` or `:month` for a quarter (default `:week`)
    * `start_time`, `end_time`: the hours of a day (default the file's
      Morning and Evening, R14e)
    * `start_day`, `end_day`: the days of a week, 1 = Monday (default the
      file's beginning and end of week)
    * `base`: the date the period is based on, typed text read every time
      the view is shown ("today", "next week", "2026-11-05")

  The slots are worked out from the settings and the clock each time
  (`slots/3`); nothing about them is stored.
  """

  alias Agenda.Core.{Context, DateParser, DateSettings, MonthCalendar}

  defmodule Slot do
    @moduledoc """
    One section of a datebook view. `:time` slots run from `from` up to
    `to` (`NaiveDateTime`s, `to` not included); the others cover the dates
    `from` to `to` (`Date`s, both included): `:untimed` is a day view's own
    day, for items without a time; `:day`, `:week` and `:month` are those.
    """
    @type t :: %__MODULE__{
            kind: :time | :untimed | :day | :week | :month,
            from: Date.t() | NaiveDateTime.t(),
            to: Date.t() | NaiveDateTime.t()
          }
    defstruct [:kind, :from, :to]
  end

  @type period :: :day | :week | :month | :quarter
  @type interval :: 15 | 30 | 60 | :day | :week | :month
  @type t :: %__MODULE__{
          date_category: pos_integer | nil,
          end_category: pos_integer | nil,
          section_category: pos_integer | nil,
          period: period,
          interval: interval | nil,
          start_time: Time.t() | nil,
          end_time: Time.t() | nil,
          start_day: 1..7 | nil,
          end_day: 1..7 | nil,
          base: String.t()
        }
  defstruct date_category: nil,
            end_category: nil,
            section_category: nil,
            period: :week,
            interval: nil,
            start_time: nil,
            end_time: nil,
            start_day: nil,
            end_day: nil,
            base: "today"

  @intervals %{day: [15, 30, 60], week: [], month: [:day, :week], quarter: [:day, :week, :month]}
  @defaults %{day: 60, week: :day, month: :week, quarter: :week}

  @doc "The periods, in Agenda's order."
  def periods, do: [:day, :week, :month, :quarter]

  @doc "The intervals a period offers (none for a week: a day each)."
  @spec intervals(period) :: [interval]
  def intervals(period), do: @intervals[period]

  @doc "What one slot covers: the setting, or the period's default."
  @spec interval(t) :: interval
  def interval(%__MODULE__{period: period, interval: interval}) do
    if interval in @intervals[period], do: interval, else: @defaults[period]
  end

  @doc "The hours of a day view: the settings, or the file's Morning and Evening."
  @spec hours(t, DateSettings.t()) :: {Time.t(), Time.t()}
  def hours(d, settings), do: {d.start_time || settings.morning, d.end_time || settings.evening}

  @doc "The days of a week view (1 = Monday): the settings, or the file's week."
  @spec days(t, DateSettings.t()) :: {1..7, 1..7}
  def days(d, settings), do: {d.start_day || settings.week_start, d.end_day || settings.week_end}

  @doc "The base date, read against the clock; today when it cannot be read."
  @spec base_date(t, DateSettings.t(), Context.clock()) :: Date.t()
  def base_date(d, settings, clock) do
    today = Context.today(clock)

    case DateParser.parse(d.base, today, Context.parser_opts(clock, settings)) do
      {:ok, date} -> date
      :error -> today
    end
  end

  @doc "The slots of the period the base date falls in, in order."
  @spec slots(t, DateSettings.t(), Context.clock()) :: [Slot.t()]
  def slots(d, settings, clock) do
    base = base_date(d, settings, clock)

    case d.period do
      :day ->
        day_slots(d, settings, base)

      :week ->
        week_slots(d, settings, base)

      :month ->
        span_slots(interval(d), Date.beginning_of_month(base), Date.end_of_month(base), settings)

      :quarter ->
        quarter_slots(d, settings, base)
    end
  end

  defp day_slots(d, settings, day) do
    {start, stop} = hours(d, settings)
    minutes = interval(d)

    times =
      start
      |> Stream.iterate(&Time.add(&1, minutes * 60))
      |> Stream.take_while(&(Time.compare(&1, stop) != :gt))
      # a time past midnight wraps around: stop there
      |> Stream.with_index()
      |> Stream.take_while(fn {t, i} -> i == 0 or Time.compare(t, start) == :gt end)
      |> Enum.map(fn {t, _} ->
        from = NaiveDateTime.new!(day, t)
        %Slot{kind: :time, from: from, to: NaiveDateTime.add(from, minutes * 60)}
      end)

    [%Slot{kind: :untimed, from: day, to: day} | times]
  end

  defp week_slots(d, settings, base) do
    {first, last} = days(d, settings)
    start = Date.add(base, -Integer.mod(Date.day_of_week(base) - first, 7))
    span = Integer.mod(last - first, 7)
    for day <- Date.range(start, Date.add(start, span)), do: %Slot{kind: :day, from: day, to: day}
  end

  defp quarter_slots(d, settings, base) do
    month = Date.beginning_of_month(base)

    first =
      MonthCalendar.move(month, :month, -Integer.mod(base.month - settings.quarter_start, 3))

    last = first |> MonthCalendar.move(:month, 2) |> Date.end_of_month()
    span_slots(interval(d), first, last, settings)
  end

  # the days, weeks (of the file's week, overlapping) or months from `first` to `last`
  defp span_slots(:day, first, last, _settings),
    do: for(day <- Date.range(first, last), do: %Slot{kind: :day, from: day, to: day})

  defp span_slots(:week, first, last, settings) do
    start = Date.add(first, -Integer.mod(Date.day_of_week(first) - settings.week_start, 7))
    span = Integer.mod(settings.week_end - settings.week_start, 7)

    start
    |> Stream.iterate(&Date.add(&1, 7))
    |> Enum.take_while(&(Date.compare(&1, last) != :gt))
    |> Enum.map(&%Slot{kind: :week, from: &1, to: Date.add(&1, span)})
  end

  defp span_slots(:month, first, last, _settings) do
    first
    |> Stream.iterate(&MonthCalendar.move(&1, :month, 1))
    |> Enum.take_while(&(Date.compare(&1, last) != :gt))
    |> Enum.map(&%Slot{kind: :month, from: &1, to: Date.end_of_month(&1)})
  end

  @doc """
  Whether an item starting at `start` (`{date, time or nil}`) and ending at
  `stop` (the same, or nil for no end) shows in a slot: its span overlaps
  the slot. Items without a time show only in day-long slots, or a day
  view's `:untimed` slot; items with one, in the slot of their time.
  """
  @spec in_slot?(Slot.t(), {Date.t(), Time.t() | nil}, {Date.t(), Time.t() | nil} | nil) ::
          boolean
  def in_slot?(%Slot{kind: :untimed, from: day}, {date, nil}, stop),
    do: Date.compare(date, day) != :gt and Date.compare(end_date(date, stop), day) != :lt

  def in_slot?(%Slot{kind: :untimed}, _start, _stop), do: false
  def in_slot?(%Slot{kind: :time}, {_date, nil}, _stop), do: false

  def in_slot?(%Slot{kind: :time, from: from, to: to}, {date, time}, stop) do
    start = NaiveDateTime.new!(date, time)
    finish = end_at(start, stop)
    NaiveDateTime.compare(start, to) == :lt and NaiveDateTime.compare(finish, from) != :lt
  end

  def in_slot?(%Slot{from: from, to: to}, {date, _time}, stop),
    do: Date.compare(date, to) != :gt and Date.compare(end_date(date, stop), from) != :lt

  defp end_date(date, nil), do: date
  defp end_date(date, {stop, _}), do: if(Date.compare(stop, date) == :lt, do: date, else: stop)

  # an end without a time lasts the whole day; an end before the start is none
  defp end_at(start, nil), do: start

  defp end_at(start, {date, time}) do
    finish = NaiveDateTime.new!(date, time || ~T[23:59:59])
    if NaiveDateTime.compare(finish, start) == :lt, do: start, else: finish
  end

  @doc """
  The options for `Agenda.Core.add_item/4` that file an item typed into a
  slot: under the Section category, dated at the slot's start (with its
  time, for a time slot), as if typed in a date column (R6a).
  """
  @spec entry(t, Slot.t()) :: keyword
  def entry(d, %Slot{kind: :time, from: from}),
    do: [
      section: d.section_category,
      date: {d.date_category, NaiveDateTime.to_date(from), NaiveDateTime.to_time(from)}
    ]

  def entry(d, %Slot{from: from}),
    do: [section: d.section_category, date: {d.date_category, from, nil}]
end
