# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Extras.CalendarFetch do
  @moduledoc """
  Reads a subscribed calendar from the web (imperative shell, SPEC R45):
  downloads it over HTTPS with the system's certificates (OTP's `:httpc`,
  no other dependency), reads its events (`Agendum.Core.Extras.ICal`), and turns
  times given in UTC into local time by the operating system's rules.
  Times in a named zone arrive in UTC already when the calendar defines
  the zone (`Agendum.Core.Extras.ICal.TimeZone`), else as local time (there is no
  time-zone database). Errors come back as a short sentence for the person.
  """

  alias Agendum.Core.Extras.ICal

  @timeout 20_000
  @max_bytes 20_000_000

  @doc "The calendar's events, or why they could not be read."
  @spec read(String.t()) :: {:ok, [ICal.Event.t()]} | {:error, String.t()}
  def read(url) do
    with {:ok, body} <- download(url),
         {:ok, events} <- parse(body) do
      {:ok, Enum.map(events, &localize/1)}
    end
  end

  @doc """
  The calendar read once before it is subscribed to (R45): its own name
  (`X-WR-CALNAME`), for the name offered, and its events.
  """
  @spec probe(String.t()) ::
          {:ok, %{title: String.t() | nil, events: [ICal.Event.t()]}} | {:error, String.t()}
  def probe(url) do
    with {:ok, body} <- download(url),
         {:ok, events} <- parse(body) do
      {:ok, %{title: ICal.name(body), events: Enum.map(events, &localize/1)}}
    end
  end

  @doc """
  Downloads `url` over HTTPS with the system's certificates, as a
  calendar or a feed (`what`, for the messages and the user agent): the
  body, or why not as a short sentence. Also used by `Agendum.Extras.FeedFetch`.
  """
  @spec download(String.t(), String.t(), pos_integer) :: {:ok, binary} | {:error, String.t()}
  def download(url, what \\ "calendar", max_bytes \\ @max_bytes) do
    {:ok, _} = Application.ensure_all_started([:inets, :ssl])

    request =
      {String.to_charlist(url),
       [{~c"user-agent", String.to_charlist("Wol's Agendum (#{what} subscription)")}]}

    http = [
      timeout: @timeout,
      connect_timeout: @timeout,
      autoredirect: true,
      # log_level: TLS alerts must not be printed over the screen
      ssl:
        [verify: :verify_peer, cacerts: :public_key.cacerts_get(), depth: 4, log_level: :none] ++
          hostname_check()
    ]

    # `sync: false, stream: :self`: the answer comes as messages, a part at
    # a time, so it is counted as it arrives and stopped at the limit; read
    # whole first, an endless answer filled the memory until the timeout
    # (docs/SECURITY.md, door 3)
    case :httpc.request(:get, request, http, sync: false, stream: :self, body_format: :binary) do
      {:ok, ref} -> receive_body(ref, what, max_bytes, [], 0, now_ms() + @timeout)
      {:error, reason} -> {:error, "could not connect (#{short(reason)})"}
    end
  rescue
    error -> {:error, "could not read it (#{Exception.message(error)})"}
  end

  # The answer's messages, in order: `stream_start` with the headers, the
  # body's parts, `stream_end`. An answer other than 200 is not streamed:
  # it comes whole, as one message. `acc` holds the parts so far, newest
  # first, and `size` their bytes.
  defp receive_body(ref, what, max_bytes, acc, size, deadline) do
    receive do
      {:http, {^ref, :stream_start, headers}} ->
        if said_length(headers) > max_bytes,
          do: too_large(ref, what),
          else: receive_body(ref, what, max_bytes, acc, size, deadline)

      {:http, {^ref, :stream, part}} ->
        size = size + byte_size(part)

        if size > max_bytes,
          do: too_large(ref, what),
          else: receive_body(ref, what, max_bytes, [part | acc], size, deadline)

      {:http, {^ref, :stream_end, _headers}} ->
        {:ok, acc |> Enum.reverse() |> IO.iodata_to_binary()}

      {:http, {^ref, {{_, 200, _}, _headers, body}}} when byte_size(body) <= max_bytes ->
        {:ok, body}

      {:http, {^ref, {{_, 200, _}, _headers, _body}}} ->
        {:error, "the #{what} is too large"}

      {:http, {^ref, {{_, status, _}, _headers, _body}}} ->
        {:error, status_text(status, what)}

      {:http, {^ref, {:error, reason}}} ->
        {:error, "could not connect (#{short(reason)})"}
    after
      # the whole answer within the timeout, however slowly it trickles in
      max(deadline - now_ms(), 0) ->
        :httpc.cancel_request(ref)
        {:error, "could not connect (timed out)"}
    end
  end

  defp too_large(ref, what) do
    :httpc.cancel_request(ref)
    {:error, "the #{what} is too large"}
  end

  # the length the server says the body has (`Content-Length`), 0 if none;
  # header names come as lower-case charlists
  defp said_length(headers) do
    with {_, value} <- List.keyfind(headers, ~c"content-length", 0),
         {length, _} <- Integer.parse(to_string(value)) do
      length
    else
      _ -> 0
    end
  end

  defp status_text(401, _what), do: "the address needs a password"
  defp status_text(403, _what), do: "the address is not shared"
  defp status_text(404, what), do: "no #{what} at that address"
  defp status_text(status, _what), do: "the server answered #{status}"

  defp now_ms, do: System.monotonic_time(:millisecond)

  defp hostname_check,
    do: [
      customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
    ]

  defp parse(body) do
    case ICal.parse(body) do
      {:ok, events} -> {:ok, events}
      {:error, :not_ical} -> {:error, "that address is not a calendar"}
    end
  end

  defp short({:failed_connect, details}) do
    if inspect(details) =~ ~r/tls_alert|bad_cert/,
      do: "the site's certificate is not valid",
      else: "no answer"
  end

  defp short(:timeout), do: "timed out"
  defp short(reason), do: reason |> inspect() |> String.slice(0, 60)

  @doc "An event with its UTC start and end moved to local time; other times as they are."
  @spec localize(ICal.Event.t()) :: ICal.Event.t()
  def localize(%ICal.Event{} = event),
    do: %{event | start: local(event.start), end: local(event.end)}

  defp local({:utc, at}) do
    local = at |> NaiveDateTime.to_erl() |> :calendar.universal_time_to_local_time()
    {:local, NaiveDateTime.from_erl!(local)}
  end

  defp local(time), do: time
end
