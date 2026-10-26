defmodule Agendum.Core.Extras.ICal do
  @moduledoc """
  Reads the events of an iCalendar file (RFC 5545, `.ics`), for calendar
  subscriptions (SPEC R45). Only what Agendum uses: each VEVENT's UID,
  SUMMARY, DESCRIPTION, DTSTART, DTEND (or DURATION), RRULE and STATUS;
  the calendar's own time zones (VTIMEZONE, `Agendum.Core.Extras.ICal.TimeZone`);
  other components (VTODO) and alarms inside events are skipped.

  A start is `{:date, Date}` (an all-day event), `{:utc, NaiveDateTime}`
  (a time ending in Z, or one with a TZID the calendar defines, turned
  into UTC by that zone's rules) or `{:local, NaiveDateTime}` (a floating
  time, or one in a zone the calendar does not define, taken as the
  reader's local time: there is no time-zone database). An end has the same forms; an all-day event's
  end is the day after its last (RFC 5545 3.6.1), and an end that cannot
  be read or comes before the start is nil. Pure.
  """

  defmodule Event do
    @moduledoc "One calendar event, as read."
    @type start :: {:date, Date.t()} | {:utc, NaiveDateTime.t()} | {:local, NaiveDateTime.t()}
    @type t :: %__MODULE__{
            uid: String.t(),
            summary: String.t(),
            description: String.t() | nil,
            start: start,
            end: start | nil,
            rrule: map | nil,
            status: :cancelled | :tentative | :confirmed | nil
          }
    defstruct [:uid, :start, end: nil, summary: "", description: nil, rrule: nil, status: nil]
  end

  alias Agendum.Core.Extras.ICal.TimeZone

  @doc "The calendar's events, in file order; `{:error, :not_ical}` for anything else."
  @spec parse(String.t()) :: {:ok, [Event.t()]} | {:error, :not_ical}
  def parse(text) do
    lines = text |> String.replace("\r\n", "\n") |> String.replace("\r", "\n") |> unfold()

    if Enum.any?(lines, &(String.upcase(&1) == "BEGIN:VCALENDAR")) do
      lines = Enum.map(lines, &content_line/1)
      # the zones first: a VTIMEZONE may come after the events that use it
      {:ok, events(lines, [], nil, 0, TimeZone.zones(lines))}
    else
      {:error, :not_ical}
    end
  end

  # A line starting with a space or tab continues the one before (RFC 5545 3.1).
  defp unfold(text) do
    text
    |> String.split("\n")
    |> Enum.reduce([], fn
      <<c, rest::binary>>, [last | done] when c in [?\s, ?\t] -> [last <> rest | done]
      "", acc -> acc
      line, acc -> [line | acc]
    end)
    |> Enum.reverse()
  end

  # NAME;PARAM=value;…:value
  defp content_line(line) do
    {head, value} =
      case split_unquoted(line, ?:) do
        {head, value} -> {head, value}
        nil -> {line, ""}
      end

    [name | params] = String.split(head, ";")

    params =
      Map.new(params, fn param ->
        case String.split(param, "=", parts: 2) do
          [k, v] -> {String.upcase(k), String.trim(v, "\"")}
          [k] -> {String.upcase(k), ""}
        end
      end)

    {String.upcase(name), params, value}
  end

  # the first `char` outside double quotes
  defp split_unquoted(line, char), do: split_unquoted(line, char, false, "")

  defp split_unquoted("", _char, _quoted, _acc), do: nil

  defp split_unquoted(<<?", rest::binary>>, char, quoted, acc),
    do: split_unquoted(rest, char, not quoted, acc <> "\"")

  defp split_unquoted(<<c, rest::binary>>, c, false, acc), do: {acc, rest}

  defp split_unquoted(<<c::utf8, rest::binary>>, char, quoted, acc),
    do: split_unquoted(rest, char, quoted, acc <> <<c::utf8>>)

  # a byte that is no UTF-8 (a Latin-1 export's "ü") is kept as it is, so
  # one odd line does not make the whole calendar unreadable
  defp split_unquoted(<<c, rest::binary>>, char, quoted, acc),
    do: split_unquoted(rest, char, quoted, acc <> <<c>>)

  # Walks the lines: `event` is the VEVENT being read (its properties, first
  # of each kind), `depth` how deep inside it a nested component is;
  # `zones` the calendar's time zones, by TZID.
  defp events([], acc, _event, _depth, _zones), do: Enum.reverse(acc)

  defp events([{"BEGIN", _, v} | rest], acc, nil, 0, zones) do
    if String.upcase(v) == "VEVENT",
      do: events(rest, acc, %{}, 0, zones),
      else: events(rest, acc, nil, 0, zones)
  end

  defp events([{"BEGIN", _, _} | rest], acc, event, depth, zones) when event != nil,
    do: events(rest, acc, event, depth + 1, zones)

  defp events([{"END", _, _} | rest], acc, event, depth, zones) when event != nil and depth > 0,
    do: events(rest, acc, event, depth - 1, zones)

  defp events([{"END", _, v} | rest], acc, event, 0, zones) when event != nil do
    if String.upcase(v) == "VEVENT" do
      case build(event, zones) do
        nil -> events(rest, acc, nil, 0, zones)
        e -> events(rest, [e | acc], nil, 0, zones)
      end
    else
      events(rest, acc, event, 0, zones)
    end
  end

  defp events([{name, params, value} | rest], acc, event, 0, zones) when event != nil,
    do: events(rest, acc, Map.put_new(event, name, {params, value}), 0, zones)

  defp events([_ | rest], acc, event, depth, zones), do: events(rest, acc, event, depth, zones)

  defp build(props, zones) do
    with {params, value} <- props["DTSTART"],
         {:ok, start} <- start(params, value, zones) do
      summary = text(props["SUMMARY"]) || ""

      %Event{
        uid: text(props["UID"]) || made_up_uid(summary, value),
        summary: summary,
        description: text(props["DESCRIPTION"]),
        start: start,
        end: ending(props, start, zones),
        rrule: with({_, rule} <- props["RRULE"], do: rrule(rule)),
        status: status(text(props["STATUS"]))
      }
    else
      _ -> nil
    end
  end

  # DTEND, else DTSTART plus DURATION; nil when neither is readable, or
  # when it is of another kind than the start or before it
  defp ending(props, start, zones) do
    finish =
      case {props["DTEND"], props["DURATION"]} do
        {{params, value}, _} ->
          case start(params, value, zones) do
            {:ok, at} -> at
            _ -> nil
          end

        {nil, {_, value}} ->
          add_duration(start, duration(value))

        _ ->
          nil
      end

    if after?(finish, start), do: finish
  end

  defp after?({kind, a}, {kind, b}), do: compare(a, b) != :lt
  defp after?(_finish, _start), do: false

  defp compare(%Date{} = a, b), do: Date.compare(a, b)
  defp compare(a, b), do: NaiveDateTime.compare(a, b)

  # an ISO 8601 duration ("PT1H30M", "P2D", "P1W") in seconds; nil if unreadable or negative
  defp duration(value) do
    case Regex.run(~r/^\+?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/, value) do
      [_ | parts] when parts != [] ->
        [w, d, h, m, sec] = parts |> Enum.concat(List.duplicate("", 5)) |> Enum.take(5)
        n = fn text -> if text == "", do: 0, else: String.to_integer(text) end
        ((n.(w) * 7 + n.(d)) * 24 + n.(h)) * 3600 + n.(m) * 60 + n.(sec)

      _ ->
        nil
    end
  end

  defp add_duration(_start, nil), do: nil
  defp add_duration({:date, date}, seconds), do: {:date, Date.add(date, div(seconds, 86_400))}
  defp add_duration({kind, at}, seconds), do: {kind, NaiveDateTime.add(at, seconds)}

  defp made_up_uid(summary, start),
    do: "agenda-" <> (:erlang.phash2({summary, start}) |> Integer.to_string(16))

  defp text(nil), do: nil

  defp text({_params, value}) do
    value
    |> String.replace(~r/\\[nN]/, "\n")
    |> String.replace(~r/\\([,;\\])/, "\\1")
  end

  defp status(nil), do: nil

  defp status(s),
    do:
      %{"CANCELLED" => :cancelled, "TENTATIVE" => :tentative, "CONFIRMED" => :confirmed}[
        String.upcase(s)
      ]

  defp start(params, value, zones) do
    cond do
      params["VALUE"] == "DATE" or String.length(value) == 8 -> date(value)
      String.ends_with?(value, "Z") -> with {:ok, t} <- datetime(value), do: {:ok, {:utc, t}}
      true -> with {:ok, t} <- datetime(value), do: {:ok, zoned(t, zones[params["TZID"]])}
    end
  end

  # a time in a zone the calendar defines becomes UTC; any other stays local
  defp zoned(at, nil), do: {:local, at}
  defp zoned(at, zone), do: {:utc, TimeZone.to_utc(zone, at)}

  defp date(<<y::binary-4, m::binary-2, d::binary-2>>) do
    with {y, ""} <- Integer.parse(y),
         {m, ""} <- Integer.parse(m),
         {d, ""} <- Integer.parse(d),
         {:ok, date} <- Date.new(y, m, d),
         do: {:ok, {:date, date}}
  end

  defp date(_), do: :error

  defp datetime(<<day::binary-8, "T", h::binary-2, mi::binary-2, s::binary-2, _::binary>>) do
    with {:ok, {:date, date}} <- date(day),
         {h, ""} <- Integer.parse(h),
         {mi, ""} <- Integer.parse(mi),
         {s, ""} <- Integer.parse(s),
         {:ok, time} <- Time.new(h, mi, min(s, 59)),
         do: {:ok, NaiveDateTime.new!(date, time)}
  end

  defp datetime(_), do: :error

  @freqs %{"DAILY" => :daily, "WEEKLY" => :weekly, "MONTHLY" => :monthly, "YEARLY" => :yearly}
  @known ~w(FREQ INTERVAL BYDAY BYMONTHDAY COUNT UNTIL WKST)

  # FREQ=WEEKLY;INTERVAL=2;BYDAY=MO;… → a map; parts we do not read are
  # listed in `other`, so the caller knows the rule is not fully understood.
  defp rrule(rule) do
    parts =
      rule
      |> String.split(";", trim: true)
      |> Map.new(fn part ->
        case String.split(part, "=", parts: 2) do
          [k, v] -> {String.upcase(k), v}
          [k] -> {String.upcase(k), ""}
        end
      end)

    %{
      freq: @freqs[String.upcase(parts["FREQ"] || "")],
      # a broken calendar's 0 or below would divide by nothing: every time
      interval: positive(int(parts["INTERVAL"])),
      byday: list(parts["BYDAY"]),
      bymonthday: parts["BYMONTHDAY"] |> list() |> Enum.map(&int/1) |> Enum.reject(&is_nil/1),
      count: int(parts["COUNT"]),
      until: until(parts["UNTIL"]),
      other: parts |> Map.keys() |> Enum.reject(&(&1 in @known)) |> Enum.sort()
    }
  end

  defp positive(n) when is_integer(n) and n > 0, do: n
  defp positive(_n), do: 1

  defp list(nil), do: []
  defp list(v), do: v |> String.upcase() |> String.split(",", trim: true)

  defp int(nil), do: nil

  defp int(v) do
    case Integer.parse(v) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp until(nil), do: nil

  defp until(v) do
    case date(String.slice(v, 0, 8)) do
      {:ok, {:date, d}} -> d
      _ -> nil
    end
  end
end
