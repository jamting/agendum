defmodule Agenda.Core.DateParser do
  @moduledoc """
  Parses the date expressions users type into date columns, relative to a
  given `today` (the core never reads the clock itself).

  Supported: `2026-10-08`, `10/8/26`, `10/8/2026`, `today`, `tomorrow`,
  `yesterday`, weekday names (`tue`, `tuesday`, `next tuesday`: the next such
  day after today), `next week`, `in 3 days`, `in 2 weeks`.
  """

  @weekdays %{
    "mon" => 1,
    "monday" => 1,
    "tue" => 2,
    "tues" => 2,
    "tuesday" => 2,
    "wed" => 3,
    "wednesday" => 3,
    "thu" => 4,
    "thur" => 4,
    "thurs" => 4,
    "thursday" => 4,
    "fri" => 5,
    "friday" => 5,
    "sat" => 6,
    "saturday" => 6,
    "sun" => 7,
    "sunday" => 7
  }

  @spec parse(String.t(), Date.t()) :: {:ok, Date.t()} | :error
  def parse(text, %Date{} = today) do
    text |> String.trim() |> String.downcase() |> do_parse(today)
  end

  defp do_parse("today", today), do: {:ok, today}
  defp do_parse("tomorrow", today), do: {:ok, Date.add(today, 1)}
  defp do_parse("yesterday", today), do: {:ok, Date.add(today, -1)}
  defp do_parse("next week", today), do: {:ok, Date.add(today, 7)}
  defp do_parse("next " <> day, today) when is_map_key(@weekdays, day), do: do_parse(day, today)

  defp do_parse(day, today) when is_map_key(@weekdays, day) do
    delta = Integer.mod(@weekdays[day] - Date.day_of_week(today), 7)
    {:ok, Date.add(today, if(delta == 0, do: 7, else: delta))}
  end

  defp do_parse(text, today) do
    cond do
      m = Regex.run(~r/^in (\d+) (day|days|week|weeks)$/, text) ->
        [_, n, unit] = m
        days = String.to_integer(n) * if(String.starts_with?(unit, "week"), do: 7, else: 1)
        {:ok, Date.add(today, days)}

      m = Regex.run(~r/^(\d{4})-(\d{1,2})-(\d{1,2})$/, text) ->
        [_, y, mo, d] = m
        build(y, mo, d)

      m = Regex.run(~r/^(\d{1,2})\/(\d{1,2})\/(\d{2}|\d{4})$/, text) ->
        [_, mo, d, y] = m
        y = if String.length(y) == 2, do: "20" <> y, else: y
        build(y, mo, d)

      true ->
        :error
    end
  end

  defp build(y, m, d) do
    case Date.new(String.to_integer(y), String.to_integer(m), String.to_integer(d)) do
      {:ok, date} -> {:ok, date}
      {:error, _} -> :error
    end
  end

  @doc "Formats a date the way columns display it."
  @spec format(Date.t() | nil) :: String.t()
  def format(nil), do: ""
  def format(%Date{} = date), do: Date.to_iso8601(date)
end
