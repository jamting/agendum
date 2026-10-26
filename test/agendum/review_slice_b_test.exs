defmodule Agendum.ReviewSliceBTest do
  @moduledoc """
  The findings of the cloud review of slice B, the core's rules
  (docs/CODE_REVIEW_SLICES.md; 2026-10-26), each as the case that showed it.
  Conditions run again when an item joins or leaves a category, its date
  categories too, as Agenda's (User's Guide 18-5/6), and an item is circular
  only when it keeps moving (20-21).
  """
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.{Database, Invariants, JSONFile}

  @now ~N[2026-10-26 23:00:00]

  defp cat(db, name, parent \\ nil) do
    {:ok, db, id} = Core.add_category(db, parent || db.main_id, name)
    {db, id}
  end

  defp item(db, text, section) do
    {db, id} = Core.add_item(db, text, @now, section: section)
    {db, id}
  end

  defp section(db), do: hd(Database.find_categories(db, "Initial Section"))

  # 1. discarding a category takes it out of the other categories' actions
  test "a discarded category leaves no action pointing at it, and the file reads back" do
    {db, a} = cat(Core.new_file(), "A")
    {db, b} = cat(db, "B")
    {:ok, db} = Core.set_action(db, a, b, :remove)
    db = Database.delete_category(db, b) |> then(fn {:ok, db} -> db end)

    assert db.categories[a].actions == []
    assert Invariants.violations(db) == []
    assert {:ok, _} = db |> JSONFile.encode() |> JSONFile.decode()
  end

  test "the invariants see a dangling action" do
    {db, a} = cat(Core.new_file(), "A")
    db = put_in(db.categories[a].actions, [{9999, :remove}])
    assert Enum.any?(Invariants.violations(db), &(&1 =~ "actions"))
  end

  # 2. a template keeps no Show View of items that are gone
  test "a template of a file with a Show Circular view opens" do
    db = Core.new_file()
    {db, id} = item(db, "Loop", section(db))
    {db, view} = Database.insert_view(db, "Circular", sections: [db.main_id])
    db = Database.update_view(db, view, &%{&1 | match: {:circular, [id]}})

    template = Core.template(db)
    assert template.views[view].match == nil
    assert Invariants.violations(template) == []
  end

  # 3. a template starts its subscriptions afresh
  test "a template forgets what its feeds and calendars read" do
    db = Core.new_file()
    {:ok, db, feed} = Core.subscribe_feed(db, "News", "https://n.example/rss")
    {:ok, db, cal} = Core.subscribe_calendar(db, "Work", "https://w.example/w.ics")
    entry = %{id: "1", title: "Seen", link: "", summary: "", published: ~N[2026-10-26 08:00:00]}
    {:ok, db, _} = Core.sync_feed(db, feed, [entry], @now)
    refute db.feeds[feed].entries == %{}

    template = Core.template(db)
    assert template.feeds[feed].entries == %{}
    assert template.feeds[feed].refreshed_at == nil
    assert template.calendars[cal].events == %{}
  end

  # 4. a recurring item's next occurrence keeps its unindexed text
  test "the next occurrence keeps the item's text in an unindexed category" do
    db = Core.new_file()
    {db, phone} = cat(db, "Landlord phone")
    {:ok, db} = Core.make_unindexed(db, phone)
    {db, rent} = item(db, "Pay rent every month on the 1st", section(db))
    {:ok, db} = Core.set_text(db, rent, phone, "555-1234")
    assert db.items[rent].recurrence

    db = Core.toggle_done(db, rent, @now)
    [next] = for {id, i} <- db.items, id != rent, i.text == db.items[rent].text, do: id
    assert Database.text(db, next, phone) == "555-1234"
  end

  # 5. an action whose value does not fit its target does nothing, never a crash
  test "a mismatched set action is left alone" do
    db = Core.new_file()
    {db, owner} = cat(db, "Owner")
    {db, amount} = cat(db, "Amount")
    {:ok, db} = Core.make_numeric(db, amount)
    # as a hand-written JSON file can hold it: text set on a numeric target
    db = put_in(db.categories[owner].actions, [{amount, {:set, "5"}}])
    {db, it} = item(db, "Something", section(db))

    assert {:ok, db, _} = Core.run(db, {:assign, it, owner}, @now)
    assert Database.number(db, it, amount) == nil
  end

  # 6. F4 Done and clearing a date run the conditions again
  test "a condition on Done fires when the item is marked done" do
    db = Core.new_file()
    {db, archive} = cat(db, "Archive")
    {:ok, db} = Core.add_condition(db, archive, db.special.done, :assigned)
    {db, it} = item(db, "Finish the report", section(db))
    refute Database.member?(db, it, archive)

    db = Core.toggle_done(db, it, @now)
    assert Database.member?(db, it, archive)
  end

  test "clearing a date with DEL runs the conditions again" do
    db = Core.new_file()
    {db, dated} = cat(db, "Dated")
    {:ok, db} = Core.add_condition(db, dated, db.special.when, :assigned)
    {db, it} = item(db, "Call Bob tomorrow", section(db))
    assert Database.member?(db, it, dated)

    db = Core.remove_from_category(db, it, db.special.when, @now)
    refute Database.member?(db, it, dated)
  end

  # 7. a category typed into a column runs its rules with the date
  test "typing a category's name into a column keeps the clock for its actions" do
    db = Core.new_file()
    {db, head} = cat(db, "Status")
    {db, soon} = cat(db, "Soon", head)
    {:ok, db} = Core.set_action(db, soon, db.special.when, {:set, "tomorrow"}, @now)
    {db, it} = item(db, "Plan the trip", section(db))

    {:ok, db, ^soon} = Core.assign_by_name(db, it, head, "Soon", @now)
    assert db.items[it].when == ~D[2026-10-27]

    {db, other} = item(db, "Pack", section(db))
    {:ok, db, _} = Core.run(db, {:assign_new_by_name, other, head, "Later"}, @now)
    assert Database.member?(db, other, hd(Database.find_categories(db, "Later")))
  end

  # 8. an item whose conditions were simply not applied yet is not circular
  test "a new condition does not mark the items it would change as circular" do
    db = Core.new_file()
    {db, sales} = cat(db, "Sales")
    {db, urgent} = cat(db, "Urgent")
    {db, _it} = item(db, "Quote for Acme", sales)
    {:ok, db} = Core.add_condition(db, urgent, sales, :assigned)

    assert Core.circular_items(db, @now) == []
  end

  # 9. no command files into a feed's own category by hand
  test "moving, columns and undiscard respect a feed's category too" do
    db = Core.new_file()
    {:ok, db, feed} = Core.subscribe_feed(db, "News", "https://n.example/rss")
    news = db.feeds[feed].category_id
    {db, it} = item(db, "Mine", section(db))

    assert Core.run(db, {:move_item, it, section(db), news, []}, @now) == {:error, :ingested}
    assert Core.run(db, {:set_in_column, it, news, true}, @now) == {:error, :ingested}
    assert Core.run(db, {:clear_column, it, news}, @now) == {:error, :ingested}
    db = Core.discard_item(db, it)
    assert Core.run(db, {:undiscard, :last, news, nil}, @now) == {:error, :ingested}
  end

  # 10. a text match never leaves a conditional mark without its link
  test "a text match its own category link takes back leaves no mark" do
    db = Core.new_file()
    {db, meetings} = cat(db, "Meetings")
    {db, unscheduled} = cat(db, "Unscheduled", meetings)
    db = Core.toggle_also_assign(db, meetings, unscheduled)
    {db, _it} = item(db, "Meetings with Bo", section(db))

    assert Invariants.violations(db) == []
  end
end
