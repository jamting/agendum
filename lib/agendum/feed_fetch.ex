defmodule Agendum.FeedFetch do
  @moduledoc """
  Reads a subscribed feed from the web (imperative shell, R75): downloads
  it as a calendar is downloaded (`Agendum.CalendarFetch.download/2`,
  OTP's `:httpc`, no other dependency) and reads its entries with the
  core's parser (`Agendum.Core.parse_feed/1`). Errors come back as a short
  sentence for the person.

  Also opens a link in the person's browser (`open_url/1`).
  """

  alias Agendum.Core.FeedParser

  @doc "The feed's entries, or why they could not be read."
  @spec read(String.t()) :: {:ok, [FeedParser.entry()]} | {:error, String.t()}
  def read(url) do
    with {:ok, body} <- Agendum.CalendarFetch.download(url, "feed") do
      case Agendum.Core.parse_feed(body) do
        {:ok, feed} -> {:ok, feed.entries}
        {:error, :not_a_feed} -> {:error, "that address is not an RSS or Atom feed"}
      end
    end
  end

  @doc """
  Opens a web address in the browser: `open` on a Mac, `xdg-open`
  elsewhere. Only `http` and `https` addresses: a feed's link is data, and
  never runs a program or opens a file.
  """
  @spec open_url(String.t()) :: :ok | {:error, String.t()}
  def open_url(url) do
    opener = if match?({:unix, :darwin}, :os.type()), do: "open", else: "xdg-open"

    cond do
      not Regex.match?(~r{\Ahttps?://[^\s]+\z}i, url) ->
        {:error, "only web addresses are opened"}

      System.find_executable(opener) == nil ->
        {:error, "#{opener} is not installed"}

      true ->
        case System.cmd(opener, [url], stderr_to_stdout: true) do
          {_, 0} -> :ok
          {out, _} -> {:error, "#{opener} failed: #{String.trim(out)}"}
        end
    end
  rescue
    error -> {:error, Exception.message(error)}
  end
end
