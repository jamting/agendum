defmodule Agenda.Core.RangeConditionsTest do
  @moduledoc """
  Date and numeric conditions (R15a; User's Guide 20-5 to 20-7): a category
  pulls in items whose date or number is in (or outside) a range, and lets
  them go again when it no longer is, also when the date changes.
  """
  use ExUnit.Case, async: true

  alias Agenda.Core
  alias Agenda.Core.{Context, Database}
  alias Agenda.Core.DateLanguage.{English, Swedish}

  # Thursday
  @today ~D[2026-10-08]

  setup do
    db = Core.new_file()
    {:ok, db, this_week} = Core.add_category(db, db.main_id, "This Week", match_name: false)
    {:ok, db, cost} = Core.add_category(db, db.main_id, "Cost")
    {:ok, db} = Core.make_numeric(db, cost)
    {:ok, db, expensive} = Core.add_category(db, db.main_id, "Expensive", match_name: false)
    %{db: db, this_week: this_week, cost: cost, expensive: expensive}
  end

  defp member?(db, item, cat), do: Database.member?(db, item, cat)

  test "a date condition pulls in items dated in the range, read against today",
       %{db: db, this_week: week} do
    # this week: Monday 5th to Friday 9th
    {:ok, db} =
      Core.set_range_condition(
        db,
        week,
        db.special.when,
        {"beginning of this week", "end of this week", :inside},
        @today
      )

    {db, friday} = Core.add_item(db, "Report due friday", @today)
    {db, later} = Core.add_item(db, "Party on 2026-10-20", @today)
    assert member?(db, friday, week)
    refute member?(db, later, week)
    assert Database.conditional?(db, friday, week)
  end

  test "the assignment breaks when the date leaves the range", %{db: db, this_week: week} do
    {:ok, db} =
      Core.set_range_condition(
        db,
        week,
        db.special.when,
        {"2026-10-05", "2026-10-09", :inside},
        @today
      )

    {db, id} = Core.add_item(db, "Report due friday", @today)
    assert member?(db, id, week)
    db = Core.set_date(db, id, db.special.when, ~D[2026-10-20], @today)
    refute member?(db, id, week)
  end

  test "relative ranges are checked again when the date changes", %{db: db, this_week: week} do
    {:ok, db} =
      Core.set_range_condition(
        db,
        week,
        db.special.when,
        {"beginning of this week", "end of this week", :inside},
        @today
      )

    {db, id} = Core.add_item(db, "Report due friday", @today)
    assert member?(db, id, week)

    # a week later the item's Friday (9th) is last week
    db = Core.recheck_conditions(db, ~D[2026-10-15])
    refute member?(db, id, week)
  end

  test "a numeric condition", %{db: db, cost: cost, expensive: expensive} do
    {:ok, db} = Core.set_range_condition(db, expensive, cost, {"1000", nil, :inside}, @today)
    {db, id} = Core.add_item(db, "New laptop", @today)
    refute member?(db, id, expensive)

    {:ok, db} = Core.set_number(db, id, cost, 1500, @today)
    assert member?(db, id, expensive)

    {:ok, db} = Core.set_number(db, id, cost, 500, @today)
    refute member?(db, id, expensive)
  end

  test "bad dates and numbers are refused", %{db: db, this_week: week, cost: cost, expensive: e} do
    assert Core.set_range_condition(db, week, db.special.when, {"someday", nil, :inside}, @today) ==
             {:error, :invalid_date}

    assert Core.set_range_condition(db, e, cost, {"lots", nil, :inside}, @today) ==
             {:error, :not_a_number}

    assert Core.set_range_condition(db, week, db.main_id, {"1", nil, :inside}, @today) ==
             {:error, :not_a_range_category}

    assert Core.set_range_condition(db, cost, cost, {"1", nil, :inside}, @today) ==
             {:error, :self}
  end

  test "dates are read in the reader's languages", %{db: db, this_week: week} do
    sv = %Context{now: ~N[2026-10-08 09:00:00], languages: [Swedish, English]}

    {:ok, db} =
      Core.set_range_condition(db, week, db.special.when, {"idag", "i övermorgon", :inside}, sv)

    {db, id} = Core.add_item(db, "Möte på fredag", sv)
    assert member?(db, id, week)
  end

  test "the conditions box lists a range like a filter", %{db: db, cost: cost, expensive: e} do
    {:ok, db} = Core.set_range_condition(db, e, cost, {"1000", "5000", :outside}, @today)
    assert db.categories[e].conditions == [{cost, {:range, 1000.0, 5000.0, :outside}}]
    db = Core.remove_condition(db, e, cost)
    assert db.categories[e].conditions == []
  end
end
