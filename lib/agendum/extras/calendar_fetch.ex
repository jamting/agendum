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
  @spec download(String.t(), String.t()) :: {:ok, binary} | {:error, String.t()}
  def download(url, what \\ "calendar") do
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

    case :httpc.request(:get, request, http, body_format: :binary) do
      {:ok, {{_, 200, _}, _headers, body}} when byte_size(body) <= @max_bytes -> {:ok, body}
      {:ok, {{_, 200, _}, _, _}} -> {:error, "the #{what} is too large"}
      {:ok, {{_, 401, _}, _, _}} -> {:error, "the address needs a password"}
      {:ok, {{_, 403, _}, _, _}} -> {:error, "the address is not shared"}
      {:ok, {{_, 404, _}, _, _}} -> {:error, "no #{what} at that address"}
      {:ok, {{_, status, _}, _, _}} -> {:error, "the server answered #{status}"}
      {:error, reason} -> {:error, "could not connect (#{short(reason)})"}
    end
  rescue
    error -> {:error, "could not read it (#{Exception.message(error)})"}
  end

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
