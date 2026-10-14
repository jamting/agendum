defmodule Agendum.Core.RangeFiltersTest do
  @moduledoc "Date and numeric filters on views and sections (R28a; User's Guide 11-5 to 11-12)."
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.{Database, ViewModel}

  # Thursday
  @today ~D[2026-10-08]

  # Items with When dates on the 5th, 9th and 20th of October (and one
  # without), and Cost numbers 50, 500 and 5000 (and one without).
  setup do
    db = Core.new_file()
    {:ok, db, cost} = Core.add_category(db, db.main_id, "Cost")
    {:ok, db} = Core.make_numeric(db, cost)
    view = hd(db.view_order)
    section = hd(db.views[view].sections).category_id

    data = [
      {"a", ~D[2026-10-05], 50},
      {"b", ~D[2026-10-09], 500},
      {"c", ~D[2026-10-20], 5000},
      {"d", nil, nil}
    ]

    db =
      Enum.reduce(data, db, fn {text, date, number}, db ->
        {db, id} = Core.add_item(db, text, @today, section: section)
        db = if date, do: Core.set_date(db, id, db.special.when, date), else: db
        if number, do: elem(Core.set_number(db, id, cost, number), 1), else: db
      end)

    %{db: db, view: view, cost: cost, when: db.special.when}
  end

  defp shown(db, view, today \\ @today) do
    db
    |> ViewModel.build(db.views[view], today)
    |> hd()
    |> Map.fetch!(:rows)
    |> Enum.map(& &1.item.text)
  end

  defp filter(db, view, cat, show, from, to, where \\ :inside, scope \\ :view) do
    {:ok, db} = Core.set_range_filter(db, view, scope, cat, {show, from, to, where}, @today)
    db
  end

  describe "date filters" do
    test "a date range shows the items dated inside it", %{db: db, view: view, when: w} do
      assert db |> filter(view, w, :assigned, "2026-10-05", "2026-10-09") |> shown(view) == [
               "a",
               "b"
             ]
    end

    test "or outside it", %{db: db, view: view, when: w} do
      db = filter(db, view, w, :assigned, "2026-10-05", "2026-10-09", :outside)
      assert shown(db, view) == ["c"]
    end

    test "an open end reaches the first or last date", %{db: db, view: view, when: w} do
      assert db |> filter(view, w, :assigned, "2026-10-09", nil) |> shown(view) == ["b", "c"]
      assert db |> filter(view, w, :assigned, nil, "2026-10-09") |> shown(view) == ["a", "b"]
    end

    test "no range: every item with a date; not assigned: those without", %{
      db: db,
      view: view,
      when: w
    } do
      assert db |> filter(view, w, :assigned, nil, nil) |> shown(view) == ["a", "b", "c"]
      assert db |> filter(view, w, :not_assigned, nil, nil) |> shown(view) == ["d"]
    end

    test "relative dates are read again each day", %{db: db, view: view, when: w} do
      # "today" to "friday": Thursday 8th to Friday 9th, a week later 15th to 16th
      db = filter(db, view, w, :assigned, "today", "friday")
      assert shown(db, view) == ["b"]
      assert shown(db, view, ~D[2026-10-19]) == ["c"]
    end

    test "a date that cannot be read is refused", %{db: db, view: view, when: w} do
      assert Core.set_range_filter(
               db,
               view,
               :view,
               w,
               {:assigned, "someday", nil, :inside},
               @today
             ) ==
               {:error, :invalid_date}
    end
  end

  describe "numeric filters" do
    test "a range of numbers, inside or outside", %{db: db, view: view, cost: cost} do
      assert db |> filter(view, cost, :assigned, "100", "1000") |> shown(view) == ["b"]

      assert db |> filter(view, cost, :assigned, "100", "1000", :outside) |> shown(view) == [
               "a",
               "c"
             ]

      assert db |> filter(view, cost, :assigned, nil, "$1,000") |> shown(view) == ["a", "b"]
    end

    test "not assigned shows items without a number", %{db: db, view: view, cost: cost} do
      assert db |> filter(view, cost, :not_assigned, nil, nil) |> shown(view) == ["d"]
    end

    test "text that is not a number is refused", %{db: db, view: view, cost: cost} do
      assert Core.set_range_filter(
               db,
               view,
               :view,
               cost,
               {:assigned, "lots", nil, :inside},
               @today
             ) ==
               {:error, :not_a_number}
    end
  end

  test "only date and numeric categories take ranges", %{db: db, view: view} do
    assert Core.set_range_filter(
             db,
             view,
             :view,
             db.main_id,
             {:assigned, "1", nil, :inside},
             @today
           ) ==
             {:error, :not_a_range_category}
  end

  test "sections have range filters too", %{db: db, view: view, cost: cost} do
    db = filter(db, view, cost, :assigned, "1000", nil, :inside, {:section, 0})
    assert shown(db, view) == ["c"]
  end

  test "removing the filter shows everything again", %{db: db, view: view, cost: cost} do
    db = db |> filter(view, cost, :assigned, "1000", nil) |> Core.remove_filter(view, :view, cost)
    assert shown(db, view) == ["a", "b", "c", "d"]
  end

  describe "new items in a filtered view" do
    test "get the start date, or the day before it when outside", %{db: db, view: view, when: w} do
      inside = filter(db, view, w, :assigned, "2026-10-05", "2026-10-09")
      assert Core.entry_values(inside, view, 0, @today) == [{w, {:date, ~D[2026-10-05]}}]

      outside = filter(db, view, w, :assigned, "2026-10-05", "2026-10-09", :outside)
      assert Core.entry_values(outside, view, 0, @today) == [{w, {:date, ~D[2026-10-04]}}]

      only_end = filter(db, view, w, :assigned, nil, "2026-10-09")
      assert Core.entry_values(only_end, view, 0, @today) == [{w, {:date, ~D[2026-10-09]}}]
    end

    test "get the minimum, or the number below it when outside", %{db: db, view: view, cost: cost} do
      inside = filter(db, view, cost, :assigned, "100", "1000")
      assert Core.entry_values(inside, view, 0, @today) == [{cost, {:number, 100.0}}]

      outside = filter(db, view, cost, :assigned, "100", "1000", :outside)
      assert Core.entry_values(outside, view, 0, @today) == [{cost, {:number, 99.0}}]
    end

    test "date and numeric categories are not assigned like standard ones", %{
      db: db,
      view: view,
      cost: cost
    } do
      db = filter(db, view, cost, :assigned, "100", "1000")
      assert Core.entry_categories(db, view, 0) == []
    end

    test "applying the values dates and numbers the item", %{
      db: db,
      view: view,
      cost: cost,
      when: w
    } do
      db =
        db
        |> filter(view, w, :assigned, "2026-10-05", nil)
        |> filter(view, cost, :assigned, "100", nil)

      {db, id} = Core.add_item(db, "e", @today)
      db = Core.apply_entry_values(db, id, Core.entry_values(db, view, 0, @today))
      assert db.items[id].when == ~D[2026-10-05]
      assert Database.number(db, id, cost) == 100.0
    end
  end

  describe "shifting date filters (browsing, R48)" do
    setup do
      db = Agendum.Core.new_file()
      {:ok, db, cost} = Agendum.Core.add_category(db, db.main_id, "Cost")
      {:ok, db} = Agendum.Core.make_numeric(db, cost)
      %{db: db, when: db.special.when, cost: cost}
    end

    @monday ~N[2026-10-12 10:00:00]

    test "date ranges move by days and months and become fixed dates",
         %{db: db, when: when_id, cost: cost} do
      # this week ends on Friday, the 16th (the file's end of week)
      filters = [
        {when_id, {:range, "today", "end of this week", :inside}},
        {cost, {:range, 5.0, nil, :inside}},
        {db.main_id, :assigned}
      ]

      assert Agendum.Core.shift_filters(db, filters, %{days: 7, months: 0}, @monday) == [
               {when_id, {:range, "2026-10-19", "2026-10-23", :inside}},
               {cost, {:range, 5.0, nil, :inside}},
               {db.main_id, :assigned}
             ]

      [{_, range} | _] = Agendum.Core.shift_filters(db, filters, %{days: 0, months: -1}, @monday)
      assert range == {:range, "2026-09-12", "2026-09-16", :inside}
    end

    test "an open end stays open; nothing moves without a shift", %{db: db, when: when_id} do
      filters = [{when_id, {:range, nil, "2026-12-31", :outside}}]

      assert Agendum.Core.shift_filters(db, filters, %{days: 1, months: 0}, @monday) ==
               [{when_id, {:range, nil, "2027-01-01", :outside}}]

      assert Agendum.Core.shift_filters(db, filters, %{days: 0, months: 0}, @monday) == filters
    end

    test "which filters can be browsed", %{db: db, when: when_id, cost: cost} do
      assert Agendum.Core.date_filters?(db, [{when_id, {:range, "today", nil, :inside}}])
      refute Agendum.Core.date_filters?(db, [{cost, {:range, 1.0, 2.0, :inside}}])
      refute Agendum.Core.date_filters?(db, [{when_id, :assigned}])
    end
  end
end
