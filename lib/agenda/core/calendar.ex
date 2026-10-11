defmodule Agenda.Core.Calendar do
  @moduledoc """
  A calendar subscription (SPEC R45): an iCalendar file on the web whose
  events become items in a category of their own.

    * `url`: where it is read from (`webcal://` is read as `https://`)
    * `category_id`: the category its items are assigned to
    * `ahead_days`: how far ahead events are imported, from today (90)
    * `refresh_minutes`: how often it is read again while Agenda runs (60),
      or `nil` for only on request
    * `events`: what each event (by its UID) looked like when last read,
      and its item: `%{item: id, summary, description, date, time,
      recurrence}`; a refresh changes only what the calendar changed
    * `refreshed_at`, `error`: when it was last read, and why that failed

  The helpers here are pure: when a calendar is due, its settings, and the
  date of an event's next occurrence. `Agenda.Core.CalendarSync` applies a
  refresh to the file.
  """

  alias Agenda.Core.ICal.Event
  alias Agenda.Core.Recurrence

  @type snapshot :: %{
          item: pos_integer,
          summary: String.t(),
          description: String.t(),
          date: Date.t() | nil,
          time: Time.t() | nil,
          recurrence: Recurrence.t() | nil
        }
  @type t :: %__MODULE__{
          id: pos_integer | nil,
          name: String.t(),
          url: String.t(),
          category_id: pos_integer,
          ahead_days: pos_integer,
          refresh_minutes: pos_integer | nil,
          events: %{optional(String.t()) => snapshot},
          refreshed_at: NaiveDateTime.t() | nil,
          error: String.t() | nil
        }
  defstruct [
    :id,
    :name,
    :url,
    :category_id,
    ahead_days: 90,
    refresh_minutes: 60,
    events: %{},
    refreshed_at: nil,
    error: nil
  ]

  @refresh [nil, 60, 360, 1440]
  @ahead [30, 90, 180, 365]
  @weekdays %{"MO" => 1, "TU" => 2, "WE" => 3, "TH" => 4, "FR" => 5, "SA" => 6, "SU" => 7}

  @doc "The choices for how often to refresh (minutes; nil: only on request)."
  def refresh_choices, do: @refresh

  @doc "The choices for how far ahead to import (days)."
  def ahead_choices, do: @ahead

  @doc "A web address as Agenda reads it: https for webcal; :error unless http(s)."
  @spec normalize_url(String.t()) :: {:ok, String.t()} | :error
  def normalize_url(url) do
    url = String.trim(url)

    cond do
      String.starts_with?(String.downcase(url), "webcal://") ->
        {:ok, "https://" <> String.slice(url, 9..-1//1)}

      Regex.match?(~r{^https?://\S+$}i, url) ->
        {:ok, url}

      true ->
        :error
    end
  end

  @doc "Whether the calendar should be read again at `now`."
  @spec due?(t, NaiveDateTime.t()) :: boolean
  def due?(%__MODULE__{refresh_minutes: nil}, _now), do: false
  def due?(%__MODULE__{refreshed_at: nil}, _now), do: true

  def due?(%__MODULE__{refreshed_at: at, refresh_minutes: minutes}, now),
    do: NaiveDateTime.diff(now, at, :second) >= minutes * 60

  @doc "The next (1) or previous (-1) choice for a setting."
  @spec cycle(t, :refresh_minutes | :ahead_days, 1 | -1) :: t
  def cycle(cal, :refresh_minutes, step),
    do: %{cal | refresh_minutes: next(@refresh, cal.refresh_minutes, step)}

  def cycle(cal, :ahead_days, step), do: %{cal | ahead_days: next(@ahead, cal.ahead_days, step)}

  defp next(list, value, step) do
    index = Enum.find_index(list, &(&1 == value)) || 0
    Enum.at(list, Integer.mod(index + step, length(list)))
  end

  @doc """
  An event's date and time as an item gets them, on or after `today`:
  `{date, time, recurrence}`, where a repeating event has its next date and,
  when Agenda can repeat it the same way, its rule. `:ended` for a series
  with no date left.
  """
  @spec occurrence(Event.t(), Date.t()) ::
          {Date.t(), Time.t() | nil, Recurrence.t() | nil} | :ended
  def occurrence(%Event{start: start, rrule: rule}, today) do
    {first, time} = start_of(start)

    case rule do
      nil ->
        {first, time, nil}

      %{freq: nil} ->
        {first, time, nil}

      rule ->
        case next_date(rule, first, today) do
          nil -> :ended
          date -> {date, time, recurrence(rule, first)}
        end
    end
  end

  defp start_of({:date, date}), do: {date, nil}

  defp start_of({_, %NaiveDateTime{} = at}),
    do: {NaiveDateTime.to_date(at), NaiveDateTime.to_time(at) |> Time.truncate(:second)}

  # Agenda's own rule, when it repeats the event exactly (R14a).
  defp recurrence(%{other: [_ | _]}, _first), do: nil

  defp recurrence(%{freq: :daily, byday: [], bymonthday: []} = r, _),
    do: %Recurrence{every: r.interval, unit: :day}

  defp recurrence(%{freq: :weekly, bymonthday: []} = r, first) do
    case r.byday do
      [] -> %Recurrence{every: r.interval, unit: :week, weekday: Date.day_of_week(first)}
      [day] -> if w = @weekdays[day], do: %Recurrence{every: r.interval, unit: :week, weekday: w}
      _ -> nil
    end
  end

  defp recurrence(%{freq: :monthly, byday: []} = r, first) do
    case r.bymonthday do
      [] -> %Recurrence{every: r.interval, unit: :month, day: first.day}
      [day] when day in 1..31 -> %Recurrence{every: r.interval, unit: :month, day: day}
      _ -> nil
    end
  end

  defp recurrence(%{freq: :yearly, byday: [], bymonthday: []} = r, _),
    do: %Recurrence{every: r.interval, unit: :year}

  defp recurrence(_rule, _first), do: nil

  # The first occurrence on or after `today`, counting occurrences from the
  # start for COUNT and stopping at UNTIL; nil when the series has ended.
  # Weekly rules on several days are walked day by day; other rules step by
  # their interval (BYDAY in monthly and yearly rules is not read).
  @max_steps 10_000

  defp next_date(rule, first, today) do
    first
    |> occurrences(rule)
    |> Stream.take(@max_steps)
    |> Stream.with_index(1)
    |> Enum.find_value(fn {date, n} ->
      cond do
        rule.until && Date.compare(date, rule.until) == :gt -> :stop
        rule.count && n > rule.count -> :stop
        Date.compare(date, today) != :lt -> date
        true -> nil
      end
    end)
    |> case do
      :stop -> nil
      date -> date
    end
  end

  defp occurrences(first, %{freq: :weekly, byday: [_, _ | _] = days, interval: n} = rule) do
    monday = Date.add(first, 1 - Date.day_of_week(first))

    # days it does not know ("1MO" is for monthly rules) are left out; with
    # none left, it repeats weekly from the start, as with no days
    case days |> Enum.map(&@weekdays[&1]) |> Enum.reject(&is_nil/1) do
      [] ->
        occurrences(first, %{rule | byday: []})

      wanted ->
        first
        |> Stream.iterate(&Date.add(&1, 1))
        |> Stream.filter(fn date ->
          Date.day_of_week(date) in wanted and rem(div(Date.diff(date, monday), 7), n) == 0
        end)
    end
  end

  defp occurrences(first, rule) do
    case recurrence(%{rule | other: []}, first) || fallback(rule, first) do
      nil -> [first]
      rec -> Stream.iterate(start_for(rec, first), &Recurrence.next(rec, &1))
    end
  end

  defp fallback(%{freq: freq, interval: n}, first) do
    case freq do
      :daily -> %Recurrence{every: n, unit: :day}
      :weekly -> %Recurrence{every: n, unit: :week}
      :monthly -> %Recurrence{every: n, unit: :month, day: first.day}
      :yearly -> %Recurrence{every: n, unit: :year}
      _ -> nil
    end
  end

  # a weekly rule on another weekday than the start's begins on that day
  defp start_for(%Recurrence{unit: :week, weekday: w}, first) when is_integer(w),
    do: Date.add(first, Integer.mod(w - Date.day_of_week(first), 7))

  defp start_for(_rec, first), do: first
end
