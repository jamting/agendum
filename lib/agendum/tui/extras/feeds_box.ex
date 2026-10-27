defmodule Agendum.TUI.Extras.FeedsBox do
  @moduledoc """
  The Feeds box (File ▸ Transfer ▸ Feeds, R75): the file's feed
  subscriptions, each with its address, how often it is read, how long
  its entries stay, and when it was last read (or why that failed). Like
  the Calendars box (R45).

  A manager, as the Macros manager is (UI guidelines, the owner's answers
  2026-10-27):

    * INS (or CTRL-N) subscribes: the feed's address, then its name (its
      category under Feeds); it is read at once
    * ENTER reads the highlighted feed now, ALT-ENTER every feed
    * F6 its properties: how often it is read, how long entries stay
      (`Agendum.TUI.Extras.SubscriptionPropsBox`)
    * F2 renames it; DEL (F4, CTRL-D) unsubscribes, asking whether to
      discard its items too
    * F7 imports an OPML feed list, F8 exports one: the extra keeps its
      files in and out to itself, so the menus have no hole with the
      Extras off (the owner's choice)
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

    INS subscribes to a feed, by its address. ENTER reads the highlighted
    one now, ALT-ENTER every feed. F6 shows its properties: how often it
    is read, how long its entries stay. F2 renames it, and its category under
    Feeds (only here: the category manager leaves a feed's categories
    alone). DEL unsubscribes. F7 imports an OPML feed list, F8 exports
    one. ESC goes back.
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
      {:alt, :enter} => :read_all,
      {:f, 7} => :import_opml,
      {:f, 8} => :export_opml,
      {:f, 2} => :rename,
      {:f, 6} => :properties,
      # F4 DELETE, as the Macros manager has it
      {:f, 4} => :unsubscribe,
      :delete => :unsubscribe,
      {:ctrl, "d"} => :unsubscribe,
      :esc => :close
    }
  end

  @impl Box
  def commands(_mode) do
    [
      {:read, "Read now", "Read the feed now"},
      {:read_all, "Read all", "Read every feed now"},
      {:subscribe, "Subscribe", "Add a feed by its address"},
      {:rename, "Rename", "Rename the feed and its category"},
      {:properties, "Properties", "How often it is read, and more"},
      {:import_opml, "Import OPML", "Subscribe to a feed list's feeds"},
      {:export_opml, "Export OPML", "Write the feeds as a feed list"},
      {:unsubscribe, "Unsubscribe", "Unsubscribe from the feed"}
    ] ++ Enum.take(Box.list_moves(), 2) ++ [{:close, "Return", "Back to the view"}]
  end

  @impl Box
  def run(state, _mode, :close), do: State.pop(state)

  def run(state, _mode, :subscribe),
    do: Prompts.prompt(state, Messages.text(:address), :feed_url)

  def run(state, _mode, :read_all), do: read_all(state)

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

  # the one place to rename a feed's category (R75a)
  defp feed(state, _mode, :rename, feed, _),
    do: Prompts.prompt(state, Messages.text(:rename), {:rename_feed, feed.id}, feed.name)

  defp feed(state, _mode, :unsubscribe, feed, _), do: unsubscribe(state, feed)

  defp feed(state, _mode, :properties, feed, _),
    do: Agendum.TUI.Extras.SubscriptionPropsBox.open(state, :feed, feed.id)

  # ALT-ENTER: every feed read, quietly unless it brings something, as a
  # scheduled read is
  # (only those not being read already count)
  defp read_all(state) do
    next = Enum.reduce(Database.feeds(state.db), state, &Update.fetch_feed(&2, &1.id, :auto))

    case map_size(next.fetching) - map_size(state.fetching) do
      0 -> State.info(next, Messages.text(:nothing_to_read))
      started -> State.info(next, Messages.text(:reading_all, started))
    end
  end

  defp unsubscribe(state, feed) do
    items =
      Enum.count(feed.entries, fn {_, %{item: id}} -> id && Map.has_key?(state.db.items, id) end)

    Prompts.ask(
      state,
      Messages.text(:unsubscribe, feed.name, items),
      {:unsubscribe_feed, feed.id}
    )
  end

  # --- subscribing (INS): the address, a read, then the name -------------

  @doc """
  The address typed after INS: the feed is read once before it is
  subscribed to (`{:probe_feed, url}`), so its name can be offered (its own
  title) and one that cannot be read is refused (the owner, 2026-10-27).
  The box remembers the address it waits for (`probing`).
  """
  @spec address_typed(State.t(), String.t()) :: State.t()
  def address_typed(state, text) do
    case Agendum.Core.feed_url(String.trim(text)) do
      {:ok, url} -> probe(state, url)
      {:error, :bad_url} -> State.error(state, Messages.text(:bad_url))
    end
  end

  defp probe(state, url) do
    case Enum.find_index(state.modes, &(&1.type == :feeds)) do
      nil ->
        state

      i ->
        %{state | modes: List.update_at(state.modes, i, &%{&1 | probing: url})}
        |> State.info(Messages.text(:probing, url))
        |> State.effect({:probe_feed, url})
    end
  end

  @doc """
  The feed read before subscribing: the name asked, its own title filled
  in (`Agendum.Core.subscription_name/2`), or why it was not subscribed.
  Dropped unless the box is still open and waiting for that address: the
  person may have closed it, or typed another (a key in between, another
  file opened meanwhile).
  """
  @spec probed(State.t(), String.t(), {:ok, map} | {:error, String.t()}) :: State.t()
  def probed(state, url, result) do
    case Enum.find_index(state.modes, &match?(%{type: :feeds, probing: ^url}, &1)) do
      nil ->
        state

      i ->
        state = %{state | modes: List.update_at(state.modes, i, &%{&1 | probing: nil})}
        asked(state, url, result)
    end
  end

  defp asked(state, url, {:ok, read}) do
    name = Agendum.Core.subscription_name(read.title, url)
    Prompts.prompt(state, Messages.text(:name), {:feed_name, url, read.entries}, name)
  end

  defp asked(state, _url, {:error, reason}),
    do: State.error(state, Messages.text(:unreadable, reason))

  @doc """
  The name given: the feed subscribed to and what was read filed at once,
  one change (one undo step), not read a second time.
  """
  @spec name_typed(State.t(), String.t(), list, String.t()) :: State.t()
  def name_typed(state, url, entries, name) do
    case State.command(state, {:subscribe_feed, name, url}) do
      {:ok, state, %{new: id}} ->
        {:ok, state, _} = State.command(state, {:sync_feed, id, entries})
        State.info(state, Messages.text(:subscribed, String.trim(name)))

      {:error, :bad_url} ->
        State.error(state, Messages.text(:bad_url))

      {:error, :no_name} ->
        State.error(state, Messages.text(:no_name))

      {:error, :duplicate} ->
        State.error(state, Messages.text(:duplicate, String.trim(name)))
    end
  end

  @impl Box
  def title(_state, _mode), do: "Feeds"

  @impl Box
  # the list scrolls by whole feeds within the room the screen leaves, its
  # three lines of keys kept below it (`Agendum.TUI.Boxes.Scroll`)
  def content(state, mode, inner, max_rows) do
    rows =
      state
      |> groups(mode)
      |> Enum.map(fn group -> Enum.map(group, &row/1) end)
      |> Scroll.window(mode.cursor, max(max_rows - 2, 4), &row({:normal, &1}))

    # the hint is made from the keys, as the key bar is (rule 6.2)
    rows ++ [[], Box.hint(keys(state, mode), inner)]
  end

  @impl Box
  def keys(_state, _mode),
    do: [
      {"ENTER", "Read now", "read now"},
      {"A-ENTER", "Read all", "ALT-ENTER", "read all"},
      {"INS", "Subscribe", "subscribe"},
      {"F2", "Rename", "rename"},
      {"F6", "Props", "properties"},
      {"F7", "Import", "import OPML"},
      {"F8", "Export", "export OPML"},
      {"DEL", "Unsubscribe", "unsubscribe"},
      {"ESC", "Close"}
    ]

  # the key bar's words (R65b): F2 renames, F4 unsubscribes
  @impl Box
  def labels(_mode),
    do: %{
      rename: "Rename",
      unsubscribe: "Unsubs",
      properties: "Props",
      import_opml: "Import",
      export_opml: "Export"
    }

  @impl Box
  def help,
    do: "Your feeds. ENTER reads one now, ALT-ENTER all; INS adds, DEL removes; F7/F8 OPML."

  defp row({style, text}),
    do: [{if(style == :selected, do: :box_selected, else: :box), " " <> text}]

  # each feed's lines, a group a feed
  defp groups(state, mode) do
    case Database.feeds(state.db) do
      [] ->
        [[{:normal, "No feeds yet · INS subscribes to one, F7 imports a list"}]]

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
