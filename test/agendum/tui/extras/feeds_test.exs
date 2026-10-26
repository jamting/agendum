defmodule Agendum.TUI.Extras.FeedsTest do
  @moduledoc "File ▸ Transfer ▸ Feeds, the News view and CTRL-V (R75)."
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.TUI.{Layout, State, Update}

  setup do
    Process.delete(:effects_seen)
    %{state: start(Core.new_file(), extras: true)}
  end

  defp open(state), do: press(state, [{:f, 10}, "f", "t", "f"])
  defp type(state, text), do: press(state, String.graphemes(text) ++ [:enter])
  defp effect(kind), do: Enum.find(effects(), &(elem(&1, 0) == kind))

  defp subscribed(state) do
    state |> open() |> press(:insert) |> type("https://owl.example/rss") |> type("Owl's Gazette")
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

  test "INS subscribes: the address, a name, and it is read at once", %{state: state} do
    state = subscribed(state)
    assert screen(state) =~ "Owl's Gazette"
    assert screen(state) =~ "reading…"
    assert {:fetch_feed, id, "https://owl.example/rss"} = effect(:fetch_feed)
    assert state.db.feeds[id].name == "Owl's Gazette"
  end

  test "the entries read come in as items, in the News view", %{state: state} do
    state = subscribed(state)
    {:fetch_feed, id, _} = effect(:fetch_feed)
    state = Update.Results.feed_read(state, id, {:ok, @entries})

    assert screen(state) =~ "Owl's Gazette: 1 new"
    state = state |> press(:esc) |> press(:esc)
    news = Enum.find(Core.Database.views(state.db), &(&1.name == "News"))
    state = State.switch_view(state, news.id)
    assert screen(state) =~ "Heffalump sighted"
  end

  test "a failed read says why, from the box", %{state: state} do
    state = subscribed(state)
    {:fetch_feed, id, _} = effect(:fetch_feed)
    state = Update.Results.feed_read(state, id, {:error, "the server answered 503"})
    assert screen(state) =~ "Owl's Gazette: the server answered 503"
    assert screen(state) =~ "failed: the server answered 503"
  end

  test "F and K change how often and how long", %{state: state} do
    state = subscribed(state)
    assert screen(state) =~ "every hour · entries kept 30 days"
    state = press(state, ["f", "k"])
    assert screen(state) =~ "every 6 hours · entries kept 90 days"
  end

  test "DEL unsubscribes, asking about its items", %{state: state} do
    state = subscribed(state) |> press(:delete)
    assert screen(state) =~ "Unsubscribe from Owl's Gazette. Discard its 0 items too?"
    state = press(state, "y")
    assert state.db.feeds == %{}
  end

  test "E writes the feeds as OPML; I reads a list", %{state: state} do
    state = subscribed(state) |> press("e") |> press(:enter)
    assert {:write_text, path, opml} = effect(:write_text)
    assert String.ends_with?(path, "feeds.opml")
    assert opml =~ ~s(xmlUrl="https://owl.example/rss")

    state = state |> press("i") |> type("/tmp/list.opml")
    assert {:read_opml, "/tmp/list.opml"} = effect(:read_opml)

    list =
      ~s(<opml><body><outline text="Rabbit" xmlUrl="https://rabbit.example/feed"/></body></opml>)

    state = Update.Results.opml_read(state, "/tmp/list.opml", {:ok, list})
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

    assert screen(Update.Results.url_opened(state, "https://owl.example/heffalump", :ok)) =~
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
