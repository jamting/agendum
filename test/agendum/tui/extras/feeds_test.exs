# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Extras.FeedsTest do
  @moduledoc "File ▸ Transfer ▸ Feeds, the News view and CTRL-V (R75)."
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.TUI.{Layout, State}

  setup do
    Process.delete(:effects_seen)
    %{state: start(Core.new_file(), extras: true)}
  end

  defp open(state), do: press(state, [{:f, 10}, "f", "t", "f"])
  defp type(state, text), do: press(state, String.graphemes(text) ++ [:enter])
  defp effect(kind), do: Enum.find(effects(), &(elem(&1, 0) == kind))

  # INS, the address; the shell's read answered with the feed's title and
  # `entries`; ENTER takes the name offered
  defp subscribed(state, entries \\ []) do
    state = state |> open() |> press(:insert) |> type("https://owl.example/rss")
    read = {:ok, %{title: "Owl's Gazette", entries: entries}}

    state
    |> Agendum.TUI.Extras.Feeds.Results.feed_probed("https://owl.example/rss", read)
    |> press(:enter)
  end

  @entries [
    %{
      id: "1",
      title: "Heffalump sighted",
      link: "https://owl.example/heffalump",
      summary: "Piglet says so.",
      published: ~N[2026-10-07 07:00:00]
    }
  ]

  test "the box lists no feeds at first", %{state: state} do
    assert screen(open(state)) =~ "No feeds yet"
  end

  test "INS: the address, a read, then the name offered from the feed's title", %{state: state} do
    state = state |> open() |> press(:insert) |> type("https://owl.example/rss")
    assert {:probe_feed, "https://owl.example/rss"} = effect(:probe_feed)
    assert state.db.feeds == %{}

    read = {:ok, %{title: "Owl's Gazette", entries: @entries}}
    asked = Agendum.TUI.Extras.Feeds.Results.feed_probed(state, "https://owl.example/rss", read)
    assert panel(asked) =~ "Name of the feed"
    assert panel(asked) =~ "Owl's Gazette"

    # one ENTER subscribes and files what was read, one undo step, not
    # read a second time
    Process.delete(:effects_seen)
    state = press(asked, :enter)
    assert [%{name: "Owl's Gazette"}] = Core.Database.feeds(state.db)
    assert screen(state) =~ "Subscribed to Owl's Gazette"
    assert effect(:fetch_feed) == nil
    assert "Heffalump sighted" in (state.db.items |> Map.values() |> Enum.map(& &1.text))
    assert Agendum.TUI.History.undo(state).db.feeds == %{}
  end

  test "a feed that cannot be read is not subscribed", %{state: state} do
    state = state |> open() |> press(:insert) |> type("https://owl.example/rss")

    state =
      Agendum.TUI.Extras.Feeds.Results.feed_probed(
        state,
        "https://owl.example/rss",
        {:error, "no answer"}
      )

    assert screen(state) =~ "Not subscribed: no answer"
    assert state.db.feeds == %{}
  end

  test "a read for an address no longer waited for is dropped", %{state: state} do
    state = state |> open() |> press(:insert) |> type("https://owl.example/rss") |> press(:esc)
    read = {:ok, %{title: "Owl's Gazette", entries: []}}
    after_ = Agendum.TUI.Extras.Feeds.Results.feed_probed(state, "https://owl.example/rss", read)
    assert after_.modes == state.modes
  end

  test "the entries read come in as items, in the News view", %{state: state} do
    state = subscribed(state, @entries)
    state = state |> press(:esc) |> press(:esc)
    news = Enum.find(Core.Database.views(state.db), &(&1.name == "News"))
    state = State.switch_view(state, news.id)
    assert screen(state) =~ "Heffalump sighted"
  end

  test "a failed read says why, from the box", %{state: state} do
    state = subscribed(state) |> press(:enter)
    {:fetch_feed, id, _} = effect(:fetch_feed)

    state =
      Agendum.TUI.Extras.Feeds.Results.feed_read(
        state,
        id,
        "https://owl.example/rss",
        {:error, "the server answered 503"}
      )

    assert screen(state) =~ "Owl's Gazette: the server answered 503"
    assert screen(state) =~ "failed: the server answered 503"
  end

  test "F6's properties change how often and how long", %{state: state} do
    state = subscribed(state)
    assert screen(state) =~ "every hour · entries kept 30 days"

    state =
      state
      |> press({:f, 6})
      |> to_setting("Read every")
      |> press(" ")
      |> to_setting("Keep")
      |> press(" ")
      |> press(:enter)

    assert screen(state) =~ "every 6 hours · entries kept 90 days"
  end

  test "DEL unsubscribes, asking about its items", %{state: state} do
    state = subscribed(state) |> press(:delete)
    assert screen(state) =~ "Unsubscribe from Owl's Gazette. Discard its 0 items too?"
    state = press(state, "y")
    assert state.db.feeds == %{}
  end

  test "F8 writes the feeds as OPML; F7 reads a list", %{state: state} do
    state = subscribed(state) |> press({:f, 8}) |> press(:enter)
    assert {:write_text, path, opml} = effect(:write_text)
    assert String.ends_with?(path, "feeds.opml")
    assert opml =~ ~s(xmlUrl="https://owl.example/rss")

    state = state |> press({:f, 7}) |> type("/tmp/list.opml")
    assert {:read_opml, "/tmp/list.opml"} = effect(:read_opml)

    list =
      ~s(<opml><body><outline text="Rabbit" xmlUrl="https://rabbit.example/feed"/></body></opml>)

    state = Agendum.TUI.Extras.Feeds.Results.opml_read(state, "/tmp/list.opml", {:ok, list})
    assert screen(state) =~ "Subscribed to 1 feed from list.opml"
    assert length(Core.Database.feeds(state.db)) == 2
  end

  test "CTRL-V opens the highlighted item's link in the browser", %{state: state} do
    {:ok, db, feed} = Core.subscribe_feed(state.db, "Owl's Gazette", "https://owl.example/rss")
    {:ok, db, _} = Core.sync_feed(db, feed, @entries, ~D[2026-10-08])
    news = Enum.find(Core.Database.views(db), &(&1.name == "News"))

    state =
      %{start(db, extras: true) | view_id: news.id}
      |> Layout.settle()
      |> press([:down, {:ctrl, "v"}])

    assert {:open_url, "https://owl.example/heffalump"} = effect(:open_url)

    assert screen(
             Agendum.TUI.Extras.Feeds.Results.url_opened(
               state,
               "https://owl.example/heffalump",
               :ok
             )
           ) =~
             "Opened"
  end

  test "CTRL-V on an item without a link says so", %{state: state} do
    state = state |> press(["H", "i", :enter]) |> press({:ctrl, "v"})
    assert screen(state) =~ "The item has no web address"
  end

  # many feeds (the owner's file has 243): the box scrolls by whole feeds,
  # the highlighted one always shown, and says how many are out of sight
  test "a long list scrolls, keeping the highlighted feed in the box", %{state: state} do
    db =
      Enum.reduce(1..40, state.db, fn n, db ->
        {:ok, db, _} = Core.subscribe_feed(db, "Feed #{n}", "https://f#{n}.example/rss")
        db
      end)

    box = open(%{state | db: db})
    lines = box |> screen() |> String.split("\n")
    assert length(lines) == box.height
    assert screen(box) =~ "Feed 1 "
    assert screen(box) =~ ~r/▼ \d+ more below/
    refute screen(box) =~ "Feed 40"
    assert screen(box) =~ "INS subscribe"

    down = press(box, List.duplicate(:down, 39))
    assert screen(down) =~ "Feed 40"
    assert screen(down) =~ ~r/▲ \d+ more above/
    refute screen(down) =~ "more below"
    assert screen(down) =~ "INS subscribe"
  end
end
