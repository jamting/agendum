# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Extras.FamiliesTest do
  @moduledoc """
  The extras' families (R75a; code review 2026-10-26): Feeds and Calendars
  under MAIN are the extras' own while they hold a feed or a calendar;
  subscriptions go only there, never into a family or a category of the
  person's; a name is one subscription's.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.Database

  @now ~N[2026-10-26 20:00:00]

  defp feeds(db, names) do
    Enum.reduce(names, {db, []}, fn name, {db, ids} ->
      {:ok, db, id} =
        Core.subscribe_feed(db, name, "https://#{String.downcase(name)}.example/rss")

      {db, ids ++ [id]}
    end)
  end

  defp family(db, %{category_id: cat}), do: db.categories[cat].parent_id

  test "unsubscribing one feed keeps the Feeds family the extra's, its feeds safe" do
    {db, [bbc, hn]} = feeds(Core.new_file(), ["BBC", "HN"])
    parent = family(db, db.feeds[bbc])
    db = Core.unsubscribe_feed(db, hn, false)

    assert Core.ingested?(db, parent)
    assert Core.run(db, {:discard_category, parent}, @now) == {:error, :ingested}
    assert Map.has_key?(db.feeds, bbc)
    # the kept category is the person's, in the family, and may go
    kept = Enum.find(db.categories[parent].children, &(db.categories[&1].name == "HN"))
    refute Core.ingested?(db, kept)
    assert {:ok, _, _} = Core.run(db, {:discard_category, kept}, @now)
  end

  test "the same for the Calendars family" do
    db = Core.new_file()
    {:ok, db, a} = Core.subscribe_calendar(db, "A", "https://a.example/a.ics")
    {:ok, db, b} = Core.subscribe_calendar(db, "B", "https://b.example/b.ics")
    parent = family(db, db.calendars[a])
    db = Core.unsubscribe_calendar(db, b, false)
    assert Core.ingested?(db, parent)
  end

  test "a name is one subscription's: a second one is refused" do
    {db, _} = feeds(Core.new_file(), ["BBC"])
    assert Core.subscribe_feed(db, "bbc", "https://other.example/rss") == {:error, :duplicate}

    {:ok, db, _} = Core.subscribe_calendar(db, "Work", "https://w.example/w.ics")
    assert Core.subscribe_calendar(db, "work", "https://w2.example/w.ics") == {:error, :duplicate}
  end

  test "a new calendar goes into Calendars, never a family of the person's" do
    db = Core.new_file()
    {:ok, db, cal} = Core.subscribe_calendar(db, "Birthdays", "https://b.example/b.ics")
    {:ok, db, personal} = Core.add_category(db, db.main_id, "Personal")
    {:ok, db, _} = Core.add_category(db, personal, "Mine")
    # an old file: a calendar's category in a family of the person's
    {:ok, db} = Database.move_category(db, db.calendars[cal].category_id, personal, nil)

    {:ok, db, second} = Core.subscribe_calendar(db, "Holidays", "https://h.example/h.ics")
    parent = family(db, db.calendars[second])
    assert db.categories[parent].name == "Calendars"
    assert db.categories[parent].parent_id == db.main_id
    refute Core.ingested?(db, personal)
  end

  test "renaming the family on opening never touches Feeds" do
    db = Core.new_file()
    {db, [feed]} = feeds(db, ["BBC"])
    {:ok, db, cal} = Core.subscribe_calendar(db, "Work", "https://w.example/w.ics")
    feeds_family = family(db, db.feeds[feed])
    calendars_family = family(db, db.calendars[cal])
    # an old file: a calendar's category moved under Feeds
    {:ok, db} = Database.move_category(db, db.calendars[cal].category_id, feeds_family, nil)
    {:ok, db} = Database.delete_category(db, calendars_family)

    db = Agendum.Store.upgrade(db)
    assert db.categories[feeds_family].name == "Feeds"
  end

  test "calendars an older version put under MAIN join Calendars with the next subscription" do
    db = Core.new_file()
    {:ok, db, a} = Core.subscribe_calendar(db, "A", "https://a.example/a.ics")
    family = family(db, db.calendars[a])
    {:ok, db} = Database.move_category(db, db.calendars[a].category_id, db.main_id, nil)
    {:ok, db} = Database.delete_category(db, family)

    # opened, the file keeps the shape it was saved with
    db = Agendum.Store.upgrade(db)
    assert family(db, db.calendars[a]) == db.main_id

    {:ok, db, b} = Core.subscribe_calendar(db, "B", "https://b.example/b.ics")
    assert family(db, db.calendars[a]) == family(db, db.calendars[b])
    assert db.categories[family(db, db.calendars[a])].name == "Calendars"
  end
end
