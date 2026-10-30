# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.UserDateCategoriesTest do
  @moduledoc """
  Date categories the user creates (R6a; User's Guide 6-3, 7-2 to 7-4):
  besides Entry, When and Done, e.g. Due or End, made from a standard
  category; each item has at most one date (and time) in it.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.{Database, ViewModel}

  # A Thursday
  @today ~D[2026-10-08]
  @now ~N[2026-10-08 10:00:00]

  setup do
    db = Core.new_file()
    {:ok, db, due} = Core.add_category(db, db.main_id, "Due")
    {:ok, db} = Core.make_date(db, due, @today)
    {db, item} = Core.add_item(db, "Pay the electricity bill", @today)
    %{db: db, due: due, item: item}
  end

  test "a new date category: kind date, matching no text", %{db: db, due: due} do
    assert db.categories[due].kind == :date
    refute db.categories[due].match_name
    {db, id} = Core.add_item(db, "Due diligence", @today)
    refute Database.member?(db, id, due)
  end

  test "a date makes the item a member; clearing it removes it",
       %{db: db, due: due, item: item} do
    db = Core.set_date(db, item, due, ~D[2026-10-30], @today)
    assert Database.item_date(db, item, due) == ~D[2026-10-30]
    assert Database.member?(db, item, due)
    assert Enum.map(Database.items_in(db, due), & &1.id) == [item]

    db = Core.remove_from_category(db, item, due, @today)
    assert Database.item_date(db, item, due) == nil
    refute Database.member?(db, item, due)
  end

  test "typing in its column reads a date and a time", %{db: db, due: due, item: item} do
    {:ok, db, :date} = Core.assign_by_name(db, item, due, "next friday at 3pm", @now)
    assert Database.item_date(db, item, due) == ~D[2026-10-16]
    assert Database.item_time(db, item, due) == ~T[15:00:00]
    assert ViewModel.cell(db, db.items[item], due) == "10/16/26 3:00pm"

    assert Core.assign_by_name(db, item, due, "someday", @now) == {:error, :invalid_date}
  end

  test "its dates are listed with the item's assignments", %{db: db, due: due, item: item} do
    db = Core.set_date(db, item, due, ~D[2026-10-30], @today)

    assert %{category: ^due, kind: :date, date: ~D[2026-10-30]} =
             Enum.find(Core.item_assignments(db, item), &(&1.category == due))
  end

  test "date conditions and date actions work with it", %{db: db, due: due, item: item} do
    {:ok, db, soon} = Core.add_category(db, db.main_id, "Soon")
    {:ok, db} = Core.set_range_condition(db, soon, due, {"today", "in 7 days", :inside}, @today)
    db = Core.set_date(db, item, due, ~D[2026-10-12], @today)
    assert Database.member?(db, item, soon)

    {:ok, db, billed} = Core.add_category(db, db.main_id, "Billed")
    {:ok, db} = Core.set_action(db, billed, due, {:set, "in 30 days"}, @today)
    {db, other} = Core.add_item(db, "Invoice Anna", @today)
    db = Core.assign(db, other, billed, @today)
    assert Database.item_date(db, other, due) == ~D[2026-11-07]
  end

  test "discarding the item or the category drops its dates", %{db: db, due: due, item: item} do
    db = Core.set_date(db, item, due, ~D[2026-10-30], @today)
    assert Core.discard_item(db, item).dates == %{}
    {:ok, db} = Core.discard_category(db, due)
    assert db.dates == %{}
  end

  describe "converting a standard category (User's Guide 7-3 to 7-4)" do
    setup %{db: db} do
      {:ok, db, review} = Core.add_category(db, db.main_id, "Review")
      {:ok, db, nov} = Core.add_category(db, review, "November 20, 2026")
      {:ok, db, later} = Core.add_category(db, review, "after the meeting")
      {db, a} = Core.add_item(db, "Check the budget", @today)
      {db, b} = Core.add_item(db, "Check the plan", @today)
      {db, c} = Core.add_item(db, "Check the team", @today)
      db = db |> Core.assign(a, nov) |> Core.assign(b, later) |> Core.assign(c, review)
      %{db: db, review: review, a: a, b: b, c: c}
    end

    test "says what will happen", %{db: db, review: review} do
      assert Core.date_conversion(db, review, @today) ==
               %{children: 2, non_dates: ["after the meeting"], assigned: 1}
    end

    test "children that are dates become dates; the rest are dropped",
         %{db: db, review: review, a: a, b: b, c: c} do
      {:ok, db} = Core.make_date(db, review, @today)
      assert db.categories[review].kind == :date
      assert db.categories[review].children == []
      assert Database.item_date(db, a, review) == ~D[2026-11-20]
      assert Database.item_date(db, b, review) == nil
      assert Database.item_date(db, c, review) == nil
    end

    test "only standard categories without grandchildren", %{db: db, review: review, due: due} do
      {:ok, db, _} = Core.add_category(db, hd(db.categories[review].children), "Deeper")
      assert Core.make_date(db, review, @today) == {:error, :too_deep}
      assert Core.make_date(db, due, @today) == {:error, :not_standard}
      assert Core.make_date(db, db.special.when, @today) == {:error, :not_standard}
    end
  end
end
