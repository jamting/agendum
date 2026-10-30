# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Extras.ICal.TimeZone do
  @moduledoc """
  A calendar's own time zones (VTIMEZONE, RFC 5545 3.6.5), so that a time
  given in a named zone (`DTSTART;TZID=America/New_York:…`) can be turned
  into UTC without a time-zone database (SPEC R45, ADR 0021).

  A zone is a list of observances, its STANDARD and DAYLIGHT parts: each
  says from which local time (its DTSTART, repeated by a yearly RRULE or
  listed in RDATEs) the zone's offset from UTC changes from TZOFFSETFROM
  to TZOFFSETTO. The offset in force at a time is that of the most recent
  change before it. Pure.

  Only what calendars write is read: yearly rules on a month with an nth
  weekday (`BYDAY=2SU`, `BYDAY=-1SU`) or a day of the month, ending with
  UNTIL or COUNT. An hour that a change skips or repeats is read by the
  offset of the change that comes first in local time.
  """

  @typedoc "A yearly rule: the month, and an nth weekday or a day of the month."
  @type rule :: %{
          month: 1..12 | nil,
          weekday: {integer, 1..7} | nil,
          monthday: integer | nil,
          until: Date.t() | nil,
          count: pos_integer | nil
        }

  @typedoc "One STANDARD or DAYLIGHT part: when it starts, and the offsets in seconds."
  @type observance :: %{
          onset: NaiveDateTime.t(),
          from: integer,
          to: integer,
          rule: rule | nil,
          rdates: [NaiveDateTime.t()]
        }

  @type t :: [observance]

  # a content line as `Agendum.Core.Extras.ICal` splits it: {NAME, params, value}
  @type line :: {String.t(), %{String.t() => String.t()}, String.t()}

  @weekdays %{"MO" => 1, "TU" => 2, "WE" => 3, "TH" => 4, "FR" => 5, "SA" => 6, "SU" => 7}

  @doc """
  The zones the calendar defines, by TZID. A zone that cannot be read is
  left out, so its times stay local, as they were before zones were read.
  """
  @spec zones([line]) :: %{String.t() => t}
  def zones(lines), do: collect(lines, %{})

  defp collect([], zones), do: zones

  defp collect([{"BEGIN", _, v} | rest], zones) do
    if String.upcase(v) == "VTIMEZONE" do
      {body, rest} = Enum.split_while(rest, &(not ends?(&1, "VTIMEZONE")))

      case zone(body) do
        {tzid, [_ | _] = observances} when is_binary(tzid) ->
          collect(rest, Map.put(zones, tzid, observances))

        _ ->
          collect(rest, zones)
      end
    else
      collect(rest, zones)
    end
  end

  defp collect([_ | rest], zones), do: collect(rest, zones)

  defp ends?({"END", _, v}, name), do: String.upcase(v) == name
  defp ends?(_line, _name), do: false

  # {tzid, observances}: the TZID line, and each STANDARD or DAYLIGHT part
  defp zone(body) do
    tzid = Enum.find_value(body, fn {name, _, v} -> if name == "TZID", do: v end)
    {tzid, observances(body, [])}
  end

  defp observances([], acc), do: Enum.reverse(acc)

  defp observances([{"BEGIN", _, v} | rest], acc) do
    kind = String.upcase(v)

    if kind in ["STANDARD", "DAYLIGHT"] do
      {props, rest} = Enum.split_while(rest, &(not ends?(&1, kind)))

      case observance(props) do
        nil -> observances(rest, acc)
        o -> observances(rest, [o | acc])
      end
    else
      observances(rest, acc)
    end
  end

  defp observances([_ | rest], acc), do: observances(rest, acc)

  defp observance(props) do
    # a property's value, the first of its kind
    value = fn name -> Enum.find_value(props, fn {n, _, v} -> if n == name, do: v end) end

    # `with` goes on while each step matches; any other result (nil, :error)
    # falls out of it, and the part is not read
    with {:ok, onset} <- local_time(value.("DTSTART")),
         {:ok, from} <- offset(value.("TZOFFSETFROM")),
         {:ok, to} <- offset(value.("TZOFFSETTO")) do
      %{onset: onset, from: from, to: to, rule: rule(value.("RRULE")), rdates: rdates(props)}
    else
      _ -> nil
    end
  end

  # "+0100", "-0500" or "+053000" → seconds east of UTC
  defp offset(nil), do: :error

  defp offset(text) do
    case Regex.run(~r/^([+-])(\d\d)(\d\d)(\d\d)?$/, String.trim(text)) do
      [_, sign, h, m | s] ->
        seconds = String.to_integer(h) * 3600 + String.to_integer(m) * 60 + seconds(s)
        {:ok, if(sign == "-", do: -seconds, else: seconds)}

      nil ->
        :error
    end
  end

  defp seconds([s]), do: String.to_integer(s)
  defp seconds([]), do: 0

  # "20070311T020000" → a NaiveDateTime; a time zone's times are its own local times
  defp local_time(nil), do: :error

  defp local_time(text) do
    case Regex.run(~r/^(\d{4})(\d\d)(\d\d)T(\d\d)(\d\d)(\d\d)/, text) do
      [_ | parts] ->
        [y, mo, d, h, mi, s] = Enum.map(parts, &String.to_integer/1)
        NaiveDateTime.new(y, mo, d, h, mi, min(s, 59))

      nil ->
        :error
    end
  end

  # RDATE lines, each one or more times separated by commas
  defp rdates(props) do
    for {"RDATE", _, v} <- props,
        text <- String.split(v, ","),
        {:ok, at} <- [local_time(text)],
        do: at
  end

  # FREQ=YEARLY;BYMONTH=3;BYDAY=2SU → a rule; nil for any other kind of rule
  defp rule(nil), do: nil

  defp rule(text) do
    parts =
      Map.new(String.split(text, ";", trim: true), fn part ->
        case String.split(part, "=", parts: 2) do
          [k, v] -> {String.upcase(k), String.upcase(v)}
          [k] -> {String.upcase(k), ""}
        end
      end)

    if parts["FREQ"] == "YEARLY" do
      %{
        month: int(parts["BYMONTH"]),
        weekday: weekday(parts["BYDAY"]),
        monthday: int(parts["BYMONTHDAY"]),
        until: until(parts["UNTIL"]),
        count: int(parts["COUNT"])
      }
    end
  end

  # "2SU" → {2, 7}, "-1SU" → {-1, 7}; a bare "SU" (every Sunday) is not read
  defp weekday(nil), do: nil

  defp weekday(text) do
    case Regex.run(~r/^([+-]?\d+)([A-Z]{2})$/, text) do
      [_, n, day] when is_map_key(@weekdays, day) -> {String.to_integer(n), @weekdays[day]}
      _ -> nil
    end
  end

  defp until(nil), do: nil

  defp until(text) do
    case local_time(text) do
      {:ok, at} -> NaiveDateTime.to_date(at)
      :error -> nil
    end
  end

  defp int(nil), do: nil

  defp int(text) do
    case Integer.parse(text) do
      {n, ""} -> n
      _ -> nil
    end
  end

  @doc "A local time in the zone, as UTC."
  @spec to_utc(t, NaiveDateTime.t()) :: NaiveDateTime.t()
  def to_utc(zone, at), do: NaiveDateTime.add(at, -offset_at(zone, at))

  # the offset of the latest change at or before `at`; before the first
  # change, the offset that change started from
  defp offset_at(zone, at) do
    changes = for o <- zone, onset <- onsets(o, at), do: {onset, o}

    case changes do
      [] -> Enum.min_by(zone, & &1.onset, NaiveDateTime).from
      _ -> changes |> Enum.max_by(&elem(&1, 0), NaiveDateTime) |> elem(1) |> Map.fetch!(:to)
    end
  end

  # the latest time this observance began at or before `at`, as a list of 0 or 1
  defp onsets(o, at) do
    [o.onset | o.rdates]
    |> Enum.concat(yearly(o, at.year))
    |> Enum.concat(yearly(o, at.year - 1))
    |> Enum.filter(&(NaiveDateTime.compare(&1, at) != :gt))
    |> Enum.max(NaiveDateTime, fn -> nil end)
    |> List.wrap()
  end

  # the rule's change in `year`, if it has one then
  defp yearly(%{rule: nil}, _year), do: []

  defp yearly(%{rule: rule, onset: start}, year) do
    date = day_in(year, rule.month || start.month, rule, start.day)

    cond do
      date == nil -> []
      year < start.year -> []
      rule.until && Date.compare(date, rule.until) == :gt -> []
      rule.count && year >= start.year + rule.count -> []
      true -> [NaiveDateTime.new!(date, NaiveDateTime.to_time(start))]
    end
  end

  defp day_in(year, month, %{weekday: {n, weekday}}, _day),
    do: nth_weekday(year, month, n, weekday)

  defp day_in(year, month, %{monthday: day}, _day) when is_integer(day),
    do: valid_date(year, month, day)

  defp day_in(year, month, _rule, day), do: valid_date(year, month, day)

  defp valid_date(year, month, day) do
    case Date.new(year, month, day) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  # The nth `weekday` (1 Monday … 7 Sunday) of the month; counted from the
  # end when n is negative (-1 the last). nil if the month has none.
  defp nth_weekday(year, month, n, weekday) do
    with %Date{} = first <- valid_date(year, month, 1) do
      date =
        if n > 0 do
          # days from the 1st to the first such weekday, then whole weeks
          Date.add(first, Integer.mod(weekday - Date.day_of_week(first), 7) + 7 * (n - 1))
        else
          last = Date.end_of_month(first)
          Date.add(last, -Integer.mod(Date.day_of_week(last) - weekday, 7) - 7 * (-n - 1))
        end

      if date.month == month, do: date
    end
  end
end
