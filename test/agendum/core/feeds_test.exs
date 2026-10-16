defmodule Agendum.Core.FeedsTest do
  @moduledoc "Feed subscriptions: subscribing, syncing, fading, OPML (R75)."
  use ExUnit.Case, async: true

  import Agendum.Fixtures
  alias Agendum.Core
  alias Agendum.Core.{Database, Invariants, JSONFile}

  @today ~D[2026-10-17]

  setup do
    {:ok, db, feed} =
      Core.subscribe_feed(Core.new_file(), "Owl's Gazette", "feed://owl.example/rss")

    %{db: db, feed: feed}
  end

  defp entry(id, title, published, extra \\ %{}) do
    Map.merge(
      %{
        id: id,
        title: title,
        link: "https://owl.example/#{id}",
        summary: "About #{title}.",
        published: published
      },
      extra
    )
  end

  defp sync(db, feed, entries, today \\ @today) do
    {:ok, db, counts} = Core.sync_feed(db, feed, entries, today)
    {db, counts}
  end

  defp item_titled(db, title), do: Enum.find(Database.items(db), &(&1.text == title))

  test "subscribing makes Feeds ▸ name and the News view", %{db: db, feed: feed} do
    cat = db.feeds[feed].category_id
    assert db.categories[cat].name == "Owl's Gazette"
    assert db.categories[db.categories[cat].parent_id].name == "Feeds"
    assert db.feeds[feed].url == "https://owl.example/rss"

    news = Enum.find(Database.views(db), &(&1.name == "News"))
    assert Enum.map(news.sections, & &1.category_id) == [cat]
    assert news.hide_done
    assert [%{order: :desc}] = news.sort

    # a second feed: a section of its own in the same view
    {:ok, db, second} = Core.subscribe_feed(db, "Rabbit's List", "https://rabbit.example/feed")
    news = Enum.find(Database.views(db), &(&1.name == "News"))
    assert length(news.sections) == 2
    assert Enum.count(Database.views(db), &(&1.name == "News")) == 1
    assert db.categories[db.feeds[second].category_id].parent_id == db.categories[cat].parent_id
  end

  test "bad subscriptions are refused", %{db: db} do
    assert {:error, :bad_url} = Core.subscribe_feed(db, "x", "ftp://nope")
    assert {:error, :no_name} = Core.subscribe_feed(db, " ", "https://ok.example")
  end

  test "a new entry becomes an item: title, note, Entry date, no When", ctx do
    entries = [entry("a", "Heffalump on Tuesday", ~N[2026-10-16 07:00:00])]
    {db, counts} = sync(ctx.db, ctx.feed, entries)
    assert counts == %{added: 1, updated: 0, faded: 0}

    item = item_titled(db, "Heffalump on Tuesday")
    assert item.note == "About Heffalump on Tuesday.\n\nhttps://owl.example/a"
    assert item.entry == ~D[2026-10-16]
    # "Tuesday" in a headline is not a When date
    assert item.when == nil
    assert Database.member?(db, item.id, db.feeds[ctx.feed].category_id)
    assert Invariants.violations(db) == []
  end

  test "a second read changes nothing, or what the feed changed", ctx do
    {db, _} = sync(ctx.db, ctx.feed, [entry("a", "Old title", ~N[2026-10-16 07:00:00])])
    {db, counts} = sync(db, ctx.feed, [entry("a", "Old title", ~N[2026-10-16 07:00:00])])
    assert counts == %{added: 0, updated: 0, faded: 0}

    {db, counts} = sync(db, ctx.feed, [entry("a", "New title", ~N[2026-10-16 07:00:00])])
    assert counts.updated == 1
    assert item_titled(db, "New title")
  end

  test "the person's edits stay when the feed changes", ctx do
    {db, _} = sync(ctx.db, ctx.feed, [entry("a", "Feed's title", ~N[2026-10-16 07:00:00])])
    id = item_titled(db, "Feed's title").id
    db = Core.edit_item(db, id, "My title", @today)
    {db, _} = sync(db, ctx.feed, [entry("a", "Feed's new title", ~N[2026-10-16 07:00:00])])
    assert db.items[id].text == "My title"
  end

  test "old entries are not added; entries fade after the keep days", ctx do
    entries = [
      entry("old", "Last month", ~N[2026-09-01 07:00:00]),
      entry("new", "This week", ~N[2026-10-16 07:00:00])
    ]

    {db, counts} = sync(ctx.db, ctx.feed, entries)
    assert counts.added == 1
    refute item_titled(db, "Last month")

    # 31 days later, This week is past the 30 days: it fades
    {db, counts} = sync(db, ctx.feed, entries, ~D[2026-11-17])
    assert counts.faded == 1
    refute item_titled(db, "This week")

    # and does not come back while the feed still has it
    {db, counts} = sync(db, ctx.feed, entries, ~D[2026-11-17])
    assert counts == %{added: 0, updated: 0, faded: 0}
    assert Invariants.violations(db) == []
  end

  describe "kept entries do not fade" do
    setup ctx do
      entries = [entry("a", "Keep me", ~N[2026-10-16 07:00:00])]
      {db, _} = sync(ctx.db, ctx.feed, entries)
      %{db: db, entries: entries, id: item_titled(db, "Keep me").id}
    end

    defp later(ctx, db), do: elem(sync(db, ctx.feed, ctx.entries, ~D[2026-12-01]), 0)

    test "with a Zettel id (the owner, 2026-10-17)", ctx do
      {:ok, db, _} = Core.attach_zettels(ctx.db, [ctx.id])
      assert Map.has_key?(later(ctx, db).items, ctx.id)
    end

    test "with a note of the person's own", ctx do
      db = Core.set_note(ctx.db, ctx.id, "Read this again", @today)
      assert Map.has_key?(later(ctx, db).items, ctx.id)
    end

    test "with a category given by hand", ctx do
      {:ok, db, cat} = Core.add_category(ctx.db, ctx.db.main_id, "Interesting")
      db = Core.assign(db, ctx.id, cat)
      assert Map.has_key?(later(ctx, db).items, ctx.id)
    end

    test "but done does not keep it: done only dismisses", ctx do
      db = Core.toggle_done(ctx.db, ctx.id, @today)
      refute Map.has_key?(later(ctx, db).items, ctx.id)
    end

    test "nor does a category from text matching", ctx do
      # a Keep category made before the entry comes in: text matching files it there
      {:ok, db, feed} =
        Core.subscribe_feed(
          with_categories(Core.new_file(), [{"Keep", [], []}]),
          "G",
          "https://g.example"
        )

      {db, _} = sync(db, feed, ctx.entries)
      id = item_titled(db, "Keep me").id
      assert Database.member?(db, id, cat(db, "Keep"))
      {db, _} = sync(db, feed, ctx.entries, ~D[2026-12-01])
      refute Map.has_key?(db.items, id)
    end
  end

  test "an item the person discarded is not brought back", ctx do
    entries = [entry("a", "Not for me", ~N[2026-10-16 07:00:00])]
    {db, _} = sync(ctx.db, ctx.feed, entries)
    db = Core.discard_item(db, item_titled(db, "Not for me").id)
    {db, counts} = sync(db, ctx.feed, entries)
    assert counts.added == 0
    refute item_titled(db, "Not for me")
  end

  test "keep days can be for ever", ctx do
    db =
      ctx.db
      |> Core.cycle_feed_setting(ctx.feed, :keep_days, 1)
      |> Core.cycle_feed_setting(ctx.feed, :keep_days, 1)
      |> Core.cycle_feed_setting(ctx.feed, :keep_days, 1)

    assert db.feeds[ctx.feed].keep_days == nil
    {db, counts} = sync(db, ctx.feed, [entry("a", "Ancient", ~N[2020-01-01 00:00:00])])
    assert counts.added == 1
    assert item_titled(db, "Ancient")
  end

  test "unsubscribing, with or without its items", ctx do
    {db, _} = sync(ctx.db, ctx.feed, [entry("a", "Gone with it", ~N[2026-10-16 07:00:00])])
    assert item_titled(Core.unsubscribe_feed(db, ctx.feed, false), "Gone with it")
    refute item_titled(Core.unsubscribe_feed(db, ctx.feed, true), "Gone with it")
  end

  test "discarding the feed's category ends the subscription", ctx do
    {:ok, db} = Core.discard_category(ctx.db, ctx.db.feeds[ctx.feed].category_id)
    assert db.feeds == %{}
    assert Invariants.violations(db) == []
  end

  test "feeds are due as calendars are", ctx do
    assert [_] = Core.feeds_due(ctx.db, ~N[2026-10-17 10:00:00])
    {db, _} = sync(ctx.db, ctx.feed, [], ~N[2026-10-17 10:00:00])
    assert Core.feeds_due(db, ~N[2026-10-17 10:30:00]) == []
    assert [_] = Core.feeds_due(db, ~N[2026-10-17 11:00:00])
  end

  test "a feed and its entries go through JSON and back", ctx do
    {db, _} = sync(ctx.db, ctx.feed, [entry("a", "Round trip", ~N[2026-10-16 07:00:00])])
    db = Core.feed_failed(db, ctx.feed, "timeout", ~N[2026-10-17 10:00:00])
    assert {:ok, ^db} = db |> JSONFile.encode() |> JSONFile.decode()
  end

  describe "OPML" do
    test "the feeds out, and in again into another file", %{db: db} do
      opml = Core.export_opml(db)
      assert opml =~ ~s(xmlUrl="https://owl.example/rss")
      assert opml =~ ~s(text="Owl&#39;s Gazette") or opml =~ ~s(text="Owl's Gazette")

      {:ok, other, [id]} = Core.import_opml(Core.new_file(), opml)
      assert other.feeds[id].url == "https://owl.example/rss"
      assert other.feeds[id].name == "Owl's Gazette"
    end

    test "folders are read through, and feeds the file has are skipped", %{db: db} do
      opml = """
      <opml version="1.0"><body>
        <outline text="News">
          <outline text="Gazette" xmlUrl="https://owl.example/rss"/>
          <outline title="Rabbit" text="r" type="rss" xmlUrl="https://rabbit.example/feed"/>
        </outline>
      </body></opml>
      """

      {:ok, db, [id]} = Core.import_opml(db, opml)
      assert db.feeds[id].name == "Rabbit"
      assert length(Database.feeds(db)) == 2
    end

    test "not OPML", %{db: db} do
      assert Core.import_opml(db, "<rss/>") == {:error, :not_opml}
    end
  end
end
