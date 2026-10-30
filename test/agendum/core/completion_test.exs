# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.CompletionTest do
  @moduledoc """
  Automatic completion of category names (SPEC R32; Agenda 2.0 User's
  Guide, "Saving Time with Automatic Completion", 2-19 to 2-21).
  """
  use ExUnit.Case, async: true

  import Agendum.Fixtures
  alias Agendum.Core
  alias Agendum.Core.Database

  setup do
    db =
      with_categories(Core.new_file(), [
        {"Priority", [exclusive: true, match_name: false], ["High", "Medium", "Low", "Lowest"]},
        {"Topics", [match_name: false], ["écrit", "economy", "Planning", "Low budget"]}
      ])

    {db, item} = Core.add_item(db, "x", today())
    %{db: db, item: item, priority: cat(db, "Priority"), topics: cat(db, "Topics")}
  end

  defp names(db, ids), do: Enum.map(ids, &db.categories[&1].name)

  test "matches the beginning of names, ignoring case, in hierarchy order", %{db: db, priority: p} do
    assert names(db, Core.completions(db, p, "l")) == ["Low", "Lowest"]
    assert names(db, Core.completions(db, p, "ME")) == ["Medium"]
  end

  test "only searches the column head's subcategories", %{db: db, priority: p} do
    refute "Low budget" in names(db, Core.completions(db, p, "Low"))
  end

  test "an exact name comes first", %{db: db, priority: p} do
    db = Database.update_category(db, cat(db, "Low"), &%{&1 | name: "Lowly"})
    {:ok, db, _} = Core.add_category(db, p, "Low")
    assert hd(names(db, Core.completions(db, p, "low"))) == "Low"
  end

  test "is not accent sensitive (the manual's example)", %{db: db, topics: t} do
    assert names(db, Core.completions(db, t, "éc")) == ["écrit", "economy"]
    assert names(db, Core.completions(db, t, "ec")) == ["écrit", "economy"]
  end

  # Our choice (an extra): a feed's or a calendar's category, and the
  # Feeds and Calendars families, come after the person's own matches,
  # though they come first in hierarchy order; an exact name still leads
  test "the person's categories before a feed's or a calendar's", %{db: db} do
    {:ok, db, _} = Core.subscribe_feed(db, "News", "https://news.example/rss")
    {:ok, db, _} = Core.subscribe_calendar(db, "Nap times", "https://naps.example/n.ics")
    {:ok, db, _} = Core.add_category(db, db.main_id, "Newsletter")
    {:ok, db, _} = Core.add_category(db, db.main_id, "Friday")
    {:ok, db, _} = Core.add_category(db, db.main_id, "Calls")
    main = db.main_id

    assert names(db, Core.completions(db, main, "n")) == ["Newsletter", "News", "Nap times"]
    assert names(db, Core.completions(db, main, "news")) == ["News", "Newsletter"]
    assert names(db, Core.completions(db, main, "f")) == ["Friday", "Feeds"]
    assert names(db, Core.completions(db, main, "ca")) == ["Calls", "Calendars"]
  end

  test "nothing typed, or no match, gives no completions", %{db: db, priority: p} do
    assert Core.completions(db, p, "") == []
    assert Core.completions(db, p, "urgent") == []
  end

  test "assign_new_by_name creates the typed name even when it begins an existing one", %{
    db: db,
    item: item,
    topics: t
  } do
    {:ok, db, id} = Core.assign_new_by_name(db, item, t, "Plan")
    assert db.categories[id].name == "Plan"
    assert db.categories[id].parent_id == t
    assert Database.member?(db, item, id)
    assert "Planning" in names(db, db.categories[t].children)
  end

  test "assign_new_by_name uses an existing category of exactly that name", %{
    db: db,
    item: item,
    priority: p
  } do
    {:ok, db, id} = Core.assign_new_by_name(db, item, p, "low")
    assert id == cat(db, "Low")
    assert Database.member?(db, item, id)
  end
end
