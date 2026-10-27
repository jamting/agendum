defmodule Agendum.TUI.Extras.FeedsBox do
  @moduledoc """
  The Feeds box (File ▸ Transfer ▸ Feeds, R75): the file's feed
  subscriptions, each with its address, how often it is read, how long
  its entries stay, and when it was last read (or why that failed). Like
  the Calendars box (R45).

    * INS (or CTRL-N) subscribes: the feed's address, then its name (its
      category under Feeds); it is read at once
    * ENTER (or R) reads the highlighted feed now
    * F changes how often it is read, K how long its entries stay
    * DEL unsubscribes, asking whether to discard its items too
    * I imports an OPML feed list, E exports one
    * ESC closes the box

  Reading happens in the shell (`{:fetch_feed, id, url}`); the result
  comes back through `Agendum.TUI.Update.Results.feed_read/4`. Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :none

  alias Agendum.Core.{Database, DateFormat}
  alias Agendum.TUI.{Boxes.Box, Boxes.Scroll, Extras.CalendarsBox, Terminal.Draw, State, Update}
  alias Agendum.TUI.Update.Prompts
  alias Agendum.TUI.Extras.Feeds.Messages

  def open(state), do: State.push(state, %Agendum.TUI.Modes.Feeds{cursor: 0})

  @doc "The feed the highlight is on, if any."
  def current(state, mode), do: state.db |> Database.feeds() |> Enum.at(mode.cursor)

  @impl Box
  def handle(state, _mode, _key), do: state

  @impl Box
  def about(_state, _mode) do
    """
    RSS and Atom feeds the file subscribes to: their entries become items
    under Feeds, newest first in the News view. Nothing asks to be read:
    an entry left alone fades away after the feed's days, unless you keep
    it (a Zettel id, a note of your own, or a category you gave it). F4
    Done dismisses one; CTRL-V opens its link in the browser.

    INS subscribes to a feed, by its address. ENTER (or R) reads the
    highlighted one now; F changes how often it is read, K how long its
    entries stay. F2 renames it, and its category under Feeds (only here:
    the category manager leaves a feed's categories alone). DEL
    unsubscribes. I imports an OPML feed list, E exports one. ESC goes back.
    """
  end

  # R65
  @impl Box
  def keymap(_mode) do
    %{
      :up => :up,
      :down => :down,
      :insert => :subscribe,
      {:ctrl, "n"} => :subscribe,
      :enter => :read,
      {:char, "r"} => :read,
      {:char, "R"} => :read,
      {:char, "f"} => :how_often,
      {:char, "F"} => :how_often,
      {:char, "k"} => :keep,
      {:char, "K"} => :keep,
      {:char, "i"} => :import_opml,
      {:char, "I"} => :import_opml,
      {:char, "e"} => :export_opml,
      {:char, "E"} => :export_opml,
      {:f, 2} => :rename,
      :delete => :unsubscribe,
      {:ctrl, "d"} => :unsubscribe,
      :esc => :close
    }
  end

  @impl Box
  def commands(_mode) do
    [
      {:read, "Read now", "Read the feed now"},
      {:subscribe, "Subscribe", "Add a feed by its address"},
      {:how_often, "How often", "Change how often it is read"},
      {:keep, "Keep", "Change how long entries stay"},
      {:rename, "Rename", "Rename the feed and its category"},
      {:import_opml, "Import OPML", "Subscribe to a feed list's feeds"},
      {:export_opml, "Export OPML", "Write the feeds as a feed list"},
      {:unsubscribe, "Unsubscribe", "Unsubscribe from the feed"}
    ] ++ Enum.take(Box.list_moves(), 2) ++ [{:close, "Return", "Back to the view"}]
  end

  @impl Box
  def run(state, _mode, :close), do: State.pop(state)

  def run(state, _mode, :subscribe),
    do: Prompts.prompt(state, Messages.text(:address), :feed_url)

  def run(state, _mode, :import_opml),
    do: Prompts.prompt(state, Messages.text(:import_opml), :import_opml)

  def run(state, _mode, :export_opml),
    do: Prompts.prompt(state, Messages.text(:export_opml), :export_opml, "feeds.opml")

  def run(state, mode, id) do
    count = length(Database.feeds(state.db))
    mode = %{mode | cursor: mode.cursor |> min(count - 1) |> max(0)}
    state = State.put_mode(state, mode)
    feed(state, mode, id, current(state, mode), count)
  end

  defp feed(state, mode, id, _feed, count) when id in [:up, :down],
    do: Box.list_move(state, mode, max(count, 1), id)

  defp feed(state, _mode, _id, nil, _count), do: state
  defp feed(state, _mode, :read, feed, _), do: Update.fetch_feed(state, feed.id, :manual)
  defp feed(state, _mode, :how_often, feed, _), do: setting(state, feed, :refresh_minutes)
  defp feed(state, _mode, :keep, feed, _), do: setting(state, feed, :keep_days)

  # the one place to rename a feed's category (R75a)
  defp feed(state, _mode, :rename, feed, _),
    do: Prompts.prompt(state, Messages.text(:rename), {:rename_feed, feed.id}, feed.name)

  defp feed(state, _mode, :unsubscribe, feed, _), do: unsubscribe(state, feed)

  defp setting(state, feed, setting),
    do: State.run(state, {:cycle_feed_setting, feed.id, setting, 1})

  defp unsubscribe(state, feed) do
    items =
      Enum.count(feed.entries, fn {_, %{item: id}} -> id && Map.has_key?(state.db.items, id) end)

    Prompts.ask(
      state,
      Messages.text(:unsubscribe, feed.name, items),
      {:unsubscribe_feed, feed.id}
    )
  end

  @impl Box
  def title(_state, _mode), do: "Feeds"

  @impl Box
  # the list scrolls by whole feeds within the room the screen leaves, its
  # three lines of keys kept below it (`Agendum.TUI.Boxes.Scroll`)
  def content(state, mode, _inner, max_rows) do
    rows =
      state
      |> groups(mode)
      |> Enum.map(fn group -> Enum.map(group, &row/1) end)
      |> Scroll.window(mode.cursor, max(max_rows - 3, 4), &row({:normal, &1}))

    rows ++
      [
        [],
        [{:box, " INS subscribe · ENTER read now · DEL unsubscribe"}],
        [{:box, " F how often · K how long kept · F2 rename · I/E OPML"}]
      ]
  end

  @impl Box
  def keys(_state, _mode),
    do: [
      {"INS", "Subscribe", "Subscribe to a feed"},
      {"ENTER", "Read now"},
      {"F", "How often", "How often to read it"},
      {"K", "Keep", "How long entries stay"},
      {"F2", "Rename", "Rename the feed and its category"},
      {"I/E", "OPML", "Import or export a feed list"},
      {"DEL", "Unsubscribe"},
      {"ESC", "Close"}
    ]

  @impl Box
  def help,
    do:
      "Your feeds. ENTER reads now, F how often, K how long kept; INS adds, DEL removes, I/E OPML."

  defp row({style, text}),
    do: [{if(style == :selected, do: :box_selected, else: :box), " " <> text}]

  # each feed's lines, a group a feed
  defp groups(state, mode) do
    case Database.feeds(state.db) do
      [] ->
        [[{:normal, "No feeds yet · INS subscribes to one, I imports a list"}]]

      feeds ->
        feeds
        |> Enum.with_index()
        |> Enum.map(fn {feed, i} ->
          head = Draw.pad(feed.name, 24) <> " " <> status(state, feed)
          style = if i == mode.cursor, do: :selected, else: :normal

          [
            {style, head},
            {:normal, "   " <> feed.url},
            {:normal,
             "   " <> CalendarsBox.refresh(feed.refresh_minutes) <> " · " <> keep(feed.keep_days)}
          ] ++ if(feed.error, do: [{:normal, "   failed: " <> feed.error}], else: [])
        end)
    end
  end

  defp status(state, feed) do
    cond do
      Map.has_key?(state.fetching, feed.id) -> "reading…"
      feed.refreshed_at == nil -> "not read yet"
      true -> "read " <> DateFormat.datetime(feed.refreshed_at, state.db.date_format)
    end
  end

  @doc "How long a feed's entries stay, in words."
  def keep(nil), do: "entries kept for ever"
  def keep(days), do: "entries kept #{days} days"
end
