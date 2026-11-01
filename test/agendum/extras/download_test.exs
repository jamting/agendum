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

  # A server that answers any number of requests, each by its path:
  # `answer` gets the path and the server's own address, and gives the
  # whole answer to send.
  defp serve_paths(answer) do
    {:ok, listen} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(listen)
    base = "http://127.0.0.1:#{port}"

    spawn_link(fn ->
      loop = fn again ->
        with {:ok, socket} <- :gen_tcp.accept(listen),
             {:ok, request} <- :gen_tcp.recv(socket, 0, 5_000) do
          [_get, path | _] = String.split(request, " ")
          :gen_tcp.send(socket, answer.(path, base))
          :gen_tcp.close(socket)
          again.(again)
        end
      end

      loop.(loop)
    end)

    base
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

  describe "redirects" do
    test "are followed, to a relative address too" do
      base =
        serve_paths(fn
          "/old", _base ->
            head("301 Moved", [{"Location", "/new"}, {"Content-Length", 0}]) <> "\r\n"

          "/new", _base ->
            head("200 OK", [{"Content-Length", 2}]) <> "\r\nok"
        end)

      assert CalendarFetch.download(base <> "/old", "feed", 1_000) == {:ok, "ok"}
    end

    test "that go round in a circle stop after a few" do
      base =
        serve_paths(fn path, base ->
          head("302 Found", [{"Location", base <> path}, {"Content-Length", 0}]) <> "\r\n"
        end)

      assert CalendarFetch.download(base <> "/loop", "feed", 1_000) ==
               {:error, "the feed is redirected too many times"}
    end

    test "to plain http from https are refused (the owner, 2026-11-01)" do
      from = "https://owl.example/feed.xml"

      assert CalendarFetch.redirect_target(from, "http://owl.example/feed.xml") ==
               {:error, :unencrypted}

      assert CalendarFetch.redirect_target(from, "HTTP://elsewhere.example/") ==
               {:error, :unencrypted}

      # https to https, http to https and http to http are fine: an http
      # address the person typed is their choice
      assert CalendarFetch.redirect_target(from, "/new.xml") ==
               {:ok, "https://owl.example/new.xml"}

      assert CalendarFetch.redirect_target("http://owl.example/f", "https://owl.example/f") ==
               {:ok, "https://owl.example/f"}

      assert CalendarFetch.redirect_target("http://owl.example/f", "http://owl.example/g") ==
               {:ok, "http://owl.example/g"}
    end

    test "to an address not on the web are refused" do
      for location <- ["file:///etc/passwd", "ftp://owl.example/f", "javascript:alert(1)"],
          do:
            assert(
              CalendarFetch.redirect_target("https://owl.example/f", location) ==
                {:error, :not_web}
            )
    end
  end

  test "a missing page says so" do
    url =
      serve(fn socket ->
        :gen_tcp.send(socket, head("404 Not Found", [{"Content-Length", 0}]) <> "\r\n")
      end)

    assert CalendarFetch.download(url, "feed", 1_000) == {:error, "no feed at that address"}
  end
end
