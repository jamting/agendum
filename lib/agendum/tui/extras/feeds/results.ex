# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Extras.Feeds.Results do
  @moduledoc """
  The shell's answers for the feeds extra (R75): a feed read, a feed read
  once before subscribing, a feed list (OPML) read, a link opened in the
  browser. Kept beside the extra (the owner's modularity, 2026-10-27), so
  `Agendum.TUI.Update.Results` holds only the clone's answers. Pure.
  """

  alias Agendum.TUI.{State, Update}
  alias Agendum.TUI.Extras.Feeds.Messages
  alias Agendum.TUI.Extras.Reads

  @doc """
  After the shell read the feed `feed_id` at `url`: its entries are filed
  into the file (R75), or why not.
  """
  @spec feed_read(State.t(), pos_integer, String.t(), {:ok, list} | {:error, String.t()}) ::
          State.t()
  def feed_read(state, feed_id, url, result) do
    feed = state.db.feeds[feed_id]
    into = fn state, kind -> into(state, feed, kind, result) end
    Reads.file(state, feed_id, url, feed, into, command(feed_id, result))
  end

  defp command(id, {:ok, entries}), do: {:sync_feed, id, entries}
  defp command(id, {:error, message}), do: {:feed_failed, id, message}

  defp into(state, feed, kind, {:ok, entries}) do
    {:ok, state, %{result: counts}} = State.command(state, {:sync_feed, feed.id, entries})
    parts = Reads.counted(counts, added: "new", updated: "changed", faded: "faded")

    cond do
      parts != "" -> State.info(state, Messages.text(:read, feed.name, parts))
      kind == :manual -> State.info(state, Messages.text(:nothing_new, feed.name))
      true -> state
    end
  end

  defp into(state, feed, kind, {:error, message}) do
    state = State.run(state, {:feed_failed, feed.id, message})

    if kind == :manual,
      do: State.error(state, Messages.text(:failed, feed.name, message)),
      else: state
  end

  @doc "A feed read once before subscribing (R75): its name asked, with its title."
  @spec feed_probed(State.t(), String.t(), term) :: State.t()
  def feed_probed(state, url, result), do: Agendum.TUI.Extras.FeedsBox.probed(state, url, result)

  @doc "After the browser was asked to open a link (R75)."
  @spec url_opened(State.t(), String.t(), :ok | {:error, term}) :: State.t()
  def url_opened(state, url, :ok), do: State.info(state, "Opened #{url}")

  def url_opened(state, _url, {:error, reason}),
    do: State.error(state, "Could not open it: #{reason}")

  @doc "A feed list read for OPML import (R75): each feed not in the file yet is subscribed."
  @spec opml_read(State.t(), String.t(), {:ok, String.t()} | {:error, term}) :: State.t()
  def opml_read(state, path, {:ok, text}) do
    case State.command(state, {:import_opml, text}) do
      {:ok, state, %{result: []}} ->
        State.info(state, Messages.text(:no_new_feeds, Path.basename(path)))

      {:ok, state, %{result: ids}} ->
        state = Enum.reduce(ids, state, &Update.fetch_feed(&2, &1, :auto))
        State.info(state, Messages.text(:opml_subscribed, Path.basename(path), length(ids)))

      {:error, :not_opml} ->
        State.error(state, Messages.text(:not_opml, Path.basename(path)))
    end
  end

  def opml_read(state, _path, {:error, :enoent}),
    do: State.error(state, Agendum.TUI.Messages.text(:file_not_found))

  def opml_read(state, _path, {:error, _reason}),
    do: State.error(state, Agendum.TUI.Messages.text(:cannot_open))
end
