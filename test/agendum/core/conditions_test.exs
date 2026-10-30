# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.ConditionsTest do
  @moduledoc """
  Assignment conditions (SPEC R15; Agenda 2.0 User's Guide, chapters 18
  and 20): a category assigns items that meet its conditions, and breaks
  that assignment when they no longer do.
  """
  use ExUnit.Case, async: true

  import Agendum.Fixtures
  alias Agendum.Core
  alias Agendum.Core.Database

  defp in?(db, item, name), do: Database.member?(db, item, cat(db, name))

  setup do
    db =
      with_categories(Core.new_file(), [
        {"Work", [match_name: false], ["Taxes", "Accountant", "Urgent"]},
        {"Priority", [exclusive: true, match_name: false], ["High", "Medium", "Low"]},
        {"People", [match_name: false], ["Dana", "Jan"]},
        "Me",
        "Watch"
      ])

    %{db: db}
  end

  test "all conditions must hold: Urgent needs Taxes and Accountant (the manual's example)", %{
    db: db
  } do
    {:ok, db} = Core.add_condition(db, cat(db, "Urgent"), cat(db, "Taxes"), :assigned)
    {:ok, db} = Core.add_condition(db, cat(db, "Urgent"), cat(db, "Accountant"), :assigned)

    {db, item} = Core.add_item(db, "file the return", today(), section: cat(db, "Taxes"))
    refute in?(db, item, "Urgent")

    db = Core.assign(db, item, cat(db, "Accountant"))
    assert in?(db, item, "Urgent")
    assert Database.conditional?(db, item, cat(db, "Urgent"))
  end

  test "conditions on mutually exclusive categories mean either (High or Low)", %{db: db} do
    {:ok, db} = Core.add_condition(db, cat(db, "Watch"), cat(db, "High"), :assigned)
    {:ok, db} = Core.add_condition(db, cat(db, "Watch"), cat(db, "Low"), :assigned)

    {db, item} = Core.add_item(db, "x", today(), section: cat(db, "Low"))
    assert in?(db, item, "Watch")
  end

  test "a negative condition: assign to Me what is not assigned to People", %{db: db} do
    {:ok, db} = Core.add_condition(db, cat(db, "Me"), cat(db, "People"), :not_assigned)

    {db, item} = Core.add_item(db, "budget line", today())
    assert in?(db, item, "Me")

    db = Core.assign(db, item, cat(db, "Dana"))
    refute in?(db, item, "Me")
  end

  test "a conditional assignment is broken when the condition no longer holds", %{db: db} do
    {:ok, db} = Core.add_condition(db, cat(db, "Watch"), cat(db, "Taxes"), :assigned)
    {db, item} = Core.add_item(db, "x", today(), section: cat(db, "Taxes"))
    assert in?(db, item, "Watch")

    db = Core.remove_from_category(db, item, cat(db, "Taxes"))
    refute in?(db, item, "Watch")
  end

  test "an assignment the user makes is never retracted by a condition", %{db: db} do
    {:ok, db} = Core.add_condition(db, cat(db, "Watch"), cat(db, "Taxes"), :assigned)
    {db, item} = Core.add_item(db, "x", today(), section: cat(db, "Taxes"))
    db = Core.assign(db, item, cat(db, "Watch"))
    refute Database.conditional?(db, item, cat(db, "Watch"))

    db = Core.remove_from_category(db, item, cat(db, "Taxes"))
    assert in?(db, item, "Watch")
  end

  test "conditions chain", %{db: db} do
    {:ok, db} = Core.add_condition(db, cat(db, "Watch"), cat(db, "Taxes"), :assigned)
    {:ok, db} = Core.add_condition(db, cat(db, "Me"), cat(db, "Watch"), :assigned)
    {db, item} = Core.add_item(db, "x", today(), section: cat(db, "Taxes"))
    assert in?(db, item, "Me")
  end

  test "contradictory conditions settle instead of looping forever", %{db: db} do
    {:ok, db} = Core.add_condition(db, cat(db, "Me"), cat(db, "Watch"), :not_assigned)
    {:ok, db} = Core.add_condition(db, cat(db, "Watch"), cat(db, "Me"), :not_assigned)
    {db, item} = Core.add_item(db, "x", today())
    assert Database.item(db, item)
  end

  test "new conditions apply to existing items only after Recalc (Utilities Execute)", %{db: db} do
    {db, item} = Core.add_item(db, "x", today(), section: cat(db, "Taxes"))
    {:ok, db} = Core.add_condition(db, cat(db, "Watch"), cat(db, "Taxes"), :assigned)
    refute in?(db, item, "Watch")

    db = Core.reassign_all(db, today())
    assert in?(db, item, "Watch")
  end

  test "a condition cannot refer to its own category or be added twice", %{db: db} do
    watch = cat(db, "Watch")
    assert Core.add_condition(db, watch, watch, :assigned) == {:error, :self}
    {:ok, db} = Core.add_condition(db, watch, cat(db, "Taxes"), :assigned)
    assert Core.add_condition(db, watch, cat(db, "Taxes"), :not_assigned) == {:error, :duplicate}
  end

  test "remove_condition, and discarding the referenced category removes the condition", %{db: db} do
    watch = cat(db, "Watch")
    {:ok, db} = Core.add_condition(db, watch, cat(db, "Taxes"), :assigned)
    {:ok, db} = Core.add_condition(db, watch, cat(db, "Jan"), :assigned)

    db = Core.remove_condition(db, watch, cat(db, "Taxes"))
    {:ok, db} = Core.discard_category(db, cat(db, "Jan"))
    assert db.categories[watch].conditions == []
  end

  # Found by the golden file (test/fixtures/formats), then checked in Agenda
  # 2.0 (2026-10-16): a category with conditions made a date or numeric
  # category keeps them in the file (agdump shows them), but its box no
  # longer shows them ("Only if Type is Standard", F1) and they assign
  # nothing, not even on Utilities Execute: no link, no date, no number.
  test "a date category's conditions are kept but assign nothing", %{db: db} do
    watch = cat(db, "Watch")
    {:ok, db} = Core.add_condition(db, watch, cat(db, "Dana"), :assigned)
    {:ok, db} = Core.make_date(db, watch, today())
    {db, item} = Core.add_item(db, "Ask Dana", today(), section: cat(db, "Dana"))

    assert db.categories[watch].conditions == [{cat(db, "Dana"), :assigned}]
    refute Database.member?(db, item, watch)
    refute Database.conditional?(db, item, watch)
    assert Agendum.Core.Invariants.violations(db) == []
  end

  test "a numeric category's conditions are kept but assign nothing", %{db: db} do
    watch = cat(db, "Watch")
    {:ok, db} = Core.add_condition(db, watch, cat(db, "Dana"), :assigned)
    {:ok, db} = Core.make_numeric(db, watch, today())
    {db, item} = Core.add_item(db, "Ask Dana", today(), section: cat(db, "Dana"))
    db = Core.execute(db, [item])

    assert db.categories[watch].conditions == [{cat(db, "Dana"), :assigned}]
    refute Database.member?(db, item, watch)
    refute Database.conditional?(db, item, watch)
  end
end
