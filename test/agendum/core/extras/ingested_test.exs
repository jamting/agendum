defmodule Agendum.Core.Extras.IngestedTest do
  @moduledoc """
  Ingested categories (R75a; meeting 2026-10-26-5, § 6; ADR 0048): the
  categories a feed or a calendar files into, and the Feeds parent, are the
  extra's: the person reads them (sections, filters, conditions) but cannot
  change or fill them by hand. Which they are is worked out from the
  subscriptions, so unsubscribing hands a category back.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.Database

  @now ~N[2026-10-26 18:00:00]

  setup do
    db = Core.new_file()
    {:ok, db, feed} = Core.subscribe_feed(db, "Heffalump News", "https://heffalump.example/rss")
    {:ok, db, cal} = Core.subscribe_calendar(db, "Work Calendar", "webcal://work.example/c.ics")
    [mine] = Database.find_categories(db, "Initial Section")
    {db, item} = Core.add_item(db, "Ask Owl", @now, section: mine)
    feed_cat = db.feeds[feed].category_id

    %{
      db: db,
      feed: feed,
      cal: cal,
      mine: mine,
      item: item,
      feed_cat: feed_cat,
      feeds_parent: db.categories[feed_cat].parent_id,
      cal_cat: db.calendars[cal].category_id
    }
  end

  defp run(db, command), do: Core.run(db, command, @now)

  test "the feeds' and calendars' categories, and the Feeds parent, are ingested", ctx do
    ingested = Core.ingested_categories(ctx.db)
    assert MapSet.equal?(ingested, MapSet.new([ctx.feed_cat, ctx.feeds_parent, ctx.cal_cat]))
    refute Core.ingested?(ctx.db, ctx.mine)
  end

  test "the person cannot change them",
       %{db: db, feed_cat: f, feeds_parent: p, cal_cat: c} = ctx do
    for command <- [
          {:rename_category, f, "Mine now"},
          {:rename_category, p, "News feeds"},
          {:discard_category, c},
          {:set_category_note, f, "my note"},
          {:set_also_match, f, "heffalumps"},
          {:toggle_match_name, f},
          {:make_exclusive, p, :keep_first},
          {:add_category, p, "Home made", []},
          {:add_category, f, "Child", []},
          {:move_category, ctx.mine, p, nil, :remove_moved},
          {:cycle_condition, f, ctx.mine}
        ] do
      assert run(db, command) == {:error, :ingested}, inspect(command)
    end
  end

  test "nor file items into them by hand or by an action", %{db: db, feed_cat: f} = ctx do
    assert run(db, {:assign, ctx.item, f}) == {:error, :ingested}
    assert run(db, {:toggle_assignment, ctx.item, f}) == {:error, :ingested}
    assert run(db, {:set_action, ctx.mine, f, :assign}) == {:error, :ingested}
    assert run(db, {:toggle_also_assign, ctx.mine, f}) == {:error, :ingested}
    assert run(db, {:add_item, "Typed in News", [section: f]}) == {:error, :ingested}
  end

  test "but reads them: a condition on one's own category, a section", %{db: db} = ctx do
    assert {:ok, _, _} = run(db, {:cycle_condition, ctx.mine, ctx.feed_cat})
    view = Enum.find(Database.views(db), &(&1.name == "Initial View")).id
    assert {:ok, _, _} = run(db, {:add_section, view, ctx.feed_cat, 1, nil})
  end

  test "the feed itself still files into its category", %{db: db, feed: feed} = ctx do
    entry = %{
      id: "1",
      title: "Woozle seen",
      link: "https://heffalump.example/1",
      summary: "",
      published: ~N[2026-10-26 08:00:00]
    }

    assert {:ok, db, %{added: 1}} = Core.sync_feed(db, feed, [entry], @now)
    [woozle] = Enum.filter(Database.items(db), &(&1.text == "Woozle seen"))
    assert Database.member?(db, woozle.id, ctx.feed_cat)
  end

  test "renaming a feed or a calendar renames its category", %{db: db} = ctx do
    assert {:ok, db, _} = run(db, {:rename_feed, ctx.feed, "Woozle Weekly"})
    assert db.feeds[ctx.feed].name == "Woozle Weekly"
    assert db.categories[ctx.feed_cat].name == "Woozle Weekly"

    assert {:ok, db, _} = run(db, {:rename_calendar, ctx.cal, "Office"})
    assert {db.calendars[ctx.cal].name, db.categories[ctx.cal_cat].name} == {"Office", "Office"}

    assert run(db, {:rename_feed, ctx.feed, "  "}) == {:error, :empty_text}
  end

  test "a two-feed rename to the same name is refused", %{db: db} = ctx do
    {:ok, db, _second} = Core.subscribe_feed(db, "Rabbit's List", "https://rabbit.example/rss")
    assert run(db, {:rename_feed, ctx.feed, "rabbit's list"}) == {:error, :duplicate}
  end

  test "unsubscribing hands the category back to the person", %{db: db} = ctx do
    db = Core.unsubscribe_feed(db, ctx.feed, false)
    refute Core.ingested?(db, ctx.feed_cat)
    # no feeds left: the Feeds parent is the person's too
    refute Core.ingested?(db, ctx.feeds_parent)
    assert {:ok, db, _} = run(db, {:rename_category, ctx.feed_cat, "Kept news"})
    assert db.categories[ctx.feed_cat].name == "Kept news"
  end
end
