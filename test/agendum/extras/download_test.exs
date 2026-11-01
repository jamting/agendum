# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Extras.DownloadTest do
  @moduledoc """
  Downloading a feed or a calendar (`Agendum.Extras.CalendarFetch.download/3`)
  from a small HTTP server of the test's own: the size limit holds while
  the answer comes in, not after it is all in memory (docs/SECURITY.md,
  door 3).
  """
  use ExUnit.Case, async: true

  alias Agendum.Extras.CalendarFetch

  # A server on a free port that answers every request with `reply`, a
  # function given the socket. `:gen_tcp` is OTP's plain TCP: no HTTP
  # library, the answer is written by hand.
  defp serve(reply) do
    {:ok, listen} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(listen)

    spawn_link(fn ->
      {:ok, socket} = :gen_tcp.accept(listen)
      {:ok, _request} = :gen_tcp.recv(socket, 0, 5_000)
      reply.(socket)
    end)

    "http://127.0.0.1:#{port}/feed.xml"
  end

  defp head(status, headers) do
    lines = Enum.map_join(headers, "", fn {k, v} -> "#{k}: #{v}\r\n" end)
    "HTTP/1.1 #{status}\r\n#{lines}"
  end

  test "an ordinary answer is read whole" do
    url =
      serve(fn socket ->
        :gen_tcp.send(socket, head("200 OK", [{"Content-Length", 5}]) <> "\r\nhello")
      end)

    assert CalendarFetch.download(url, "feed", 1_000) == {:ok, "hello"}
  end

  test "an endless answer is stopped at the limit, not read until the timeout" do
    url =
      serve(fn socket ->
        # chunked: no length said, and the chunks never end
        :gen_tcp.send(socket, head("200 OK", [{"Transfer-Encoding", "chunked"}]) <> "\r\n")
        chunk = String.duplicate("x", 4_096)

        # a function cannot name itself, so it is handed itself to call
        # again; it ends only when the reader hangs up
        endless = fn again ->
          case :gen_tcp.send(socket, "1000\r\n#{chunk}\r\n") do
            :ok -> again.(again)
            {:error, _closed} -> :ok
          end
        end

        endless.(endless)
      end)

    {micros, result} = :timer.tc(fn -> CalendarFetch.download(url, "feed", 100_000) end)
    assert result == {:error, "the feed is too large"}
    assert micros < 5_000_000
  end

  test "an answer that says it is too large is refused before it is read" do
    url =
      serve(fn socket ->
        :gen_tcp.send(socket, head("200 OK", [{"Content-Length", 50_000_000}]) <> "\r\nxx")
        Process.sleep(:infinity)
      end)

    {micros, result} = :timer.tc(fn -> CalendarFetch.download(url, "feed", 1_000) end)
    assert result == {:error, "the feed is too large"}
    assert micros < 5_000_000
  end

  test "a missing page says so" do
    url =
      serve(fn socket ->
        :gen_tcp.send(socket, head("404 Not Found", [{"Content-Length", 0}]) <> "\r\n")
      end)

    assert CalendarFetch.download(url, "feed", 1_000) == {:error, "no feed at that address"}
  end
end
