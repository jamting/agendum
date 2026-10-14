defmodule Agendum.Core.NumbersTest do
  @moduledoc "Numeric categories, number formats and calculations (R29; User's Guide chapter 8)."
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.{Database, NumberFormat, ViewModel}
  alias Agendum.Core.View.{Column, SortKey}

  @today ~D[2026-10-08]

  describe "reading numbers" do
    test "plain, signed, decimal and scientific numbers" do
      assert NumberFormat.parse("120") == {:ok, 120.0}
      assert NumberFormat.parse(" -3 ") == {:ok, -3.0}
      assert NumberFormat.parse("3.459") == {:ok, 3.459}
      assert NumberFormat.parse("3.22e+12") == {:ok, 3.22e12}
      assert NumberFormat.parse(".5") == {:ok, 0.5}
    end

    test "symbols, thousands separators and parentheses are accepted" do
      assert NumberFormat.parse("$1,234.50") == {:ok, 1234.5}
      assert NumberFormat.parse("(12.5)") == {:ok, -12.5}
      assert NumberFormat.parse("12%") == {:ok, 12.0}
      assert NumberFormat.parse("£3") == {:ok, 3.0}
    end

    test "anything else is not a number" do
      for text <- ["", "abc", "1.2.3", "12 apples", "--1", "()"],
          do: assert(NumberFormat.parse(text) == :error, text)
    end

    test "the separators can be swapped" do
      assert NumberFormat.parse("1.234,5", decimal: ",", thousands: ".") == {:ok, 1234.5}
    end
  end

  describe "showing numbers" do
    test "two decimals by default, rounded" do
      assert NumberFormat.format(3.459, %NumberFormat{}) == "3.46"
      assert NumberFormat.format(120.0, %NumberFormat{decimals: 0}) == "120"
      assert NumberFormat.format(-0.004, %NumberFormat{}) == "0.00"
    end

    test "thousands separator, symbols and negative style" do
      assert NumberFormat.format(1234.5, %NumberFormat{thousands: true}) == "1,234.50"
      assert NumberFormat.format(-12.5, %NumberFormat{symbol: "$"}) == "-$12.50"

      assert NumberFormat.format(-12.5, %NumberFormat{symbol: "$", negative: :parens}) ==
               "($12.50)"

      assert NumberFormat.format(12.0, %NumberFormat{symbol: "%"}) == "12.00%"
      assert NumberFormat.format(12.0, %NumberFormat{symbol: "¢", decimals: 0}) == "12¢"
      assert NumberFormat.format(3.0, %NumberFormat{symbol: "£"}) == "£3.00"
    end

    test "the separators can be swapped" do
      format = %NumberFormat{thousands: true}

      assert NumberFormat.format(1234.5, format, decimal: ",", thousands: ".") ==
               "1.234,50"
    end

    test "numbers too wide for the column use scientific notation" do
      assert NumberFormat.format(3.22e12, %NumberFormat{}, width: 8) == "3.22e+12"
    end
  end

  # A file with an Expenses section, an Amount column and three items.
  defp file do
    db = Core.new_file()
    {:ok, db, expenses} = Core.add_category(db, db.main_id, "Expenses")
    {:ok, db, amount} = Core.add_category(db, db.main_id, "Amount")
    {:ok, db} = Core.make_numeric(db, amount)
    view_id = hd(db.view_order)
    db = Core.set_section_category(db, view_id, 0, expenses)
    db = Core.add_column(db, view_id, amount, {0, 1})

    {db, ids} =
      Enum.reduce(["heat", "rent", "phone"], {db, []}, fn text, {db, ids} ->
        {db, id} = Core.add_item(db, text, @today, section: expenses)
        {db, ids ++ [id]}
      end)

    %{db: db, amount: amount, view: view_id, ids: ids}
  end

  describe "numeric categories" do
    test "a number assigns the item to the numeric category" do
      %{db: db, amount: amount, ids: [heat | _]} = file()
      {:ok, db} = Core.set_number(db, heat, amount, 120)
      assert Database.number(db, heat, amount) == 120.0
      assert Database.member?(db, heat, amount)

      db = Core.clear_number(db, heat, amount)
      assert Database.number(db, heat, amount) == nil
      refute Database.member?(db, heat, amount)
    end

    test "only numeric categories take numbers" do
      %{db: db, ids: [heat | _]} = file()
      assert Core.set_number(db, heat, db.main_id, 1) == {:error, :not_numeric}
    end

    test "a numeric category does not match item text" do
      %{db: db, amount: amount} = file()
      {db, id} = Core.add_item(db, "Amount due", @today)
      refute Database.member?(db, id, amount)
    end

    test "discarding an item or the category forgets its numbers" do
      %{db: db, amount: amount, ids: [heat, rent | _]} = file()
      {:ok, db} = Core.set_number(db, heat, amount, 120)
      {:ok, db} = Core.set_number(db, rent, amount, 800)

      assert Database.delete_item(db, heat).numbers |> Map.keys() == [{rent, amount}]
      assert {:ok, %{numbers: numbers}} = Database.delete_category(db, amount)
      assert numbers == %{}
    end
  end

  describe "converting a standard category" do
    test "a category without children becomes numeric" do
      db = Core.new_file()
      {:ok, db, cost} = Core.add_category(db, db.main_id, "Cost")
      {:ok, db} = Core.make_numeric(db, cost)
      assert db.categories[cost].kind == :numeric
      refute db.categories[cost].match_name
    end

    test "children become the values of their items: numbers as written, other names as 0" do
      db = Core.new_file()
      {:ok, db, forecast} = Core.add_category(db, db.main_id, "Forecast")
      {:ok, db, ten} = Core.add_category(db, forecast, "10")
      {:ok, db, good} = Core.add_category(db, forecast, "Good")
      {db, a} = Core.add_item(db, "a", @today)
      {db, b} = Core.add_item(db, "b", @today)
      db = db |> Core.assign(a, ten) |> Core.assign(b, good)

      assert Core.numeric_conversion(db, forecast) == %{
               children: 2,
               non_numeric: ["Good"],
               assigned: 0
             }

      {:ok, db} = Core.make_numeric(db, forecast)

      assert db.categories[forecast].children == []
      assert Database.number(db, a, forecast) == 10.0
      assert Database.number(db, b, forecast) == 0.0
    end

    test "items assigned to the category itself get 0" do
      db = Core.new_file()
      {:ok, db, cost} = Core.add_category(db, db.main_id, "Cost")
      {db, a} = Core.add_item(db, "a", @today)
      db = Core.assign(db, a, cost)
      assert Core.numeric_conversion(db, cost).assigned == 1
      {:ok, db} = Core.make_numeric(db, cost)
      assert Database.number(db, a, cost) == 0.0
    end

    test "categories with grandchildren, and other kinds, cannot be converted" do
      db = Core.new_file()
      {:ok, db, top} = Core.add_category(db, db.main_id, "Top")
      {:ok, db, mid} = Core.add_category(db, top, "Mid")
      {:ok, db, _} = Core.add_category(db, mid, "Low")
      assert Core.make_numeric(db, top) == {:error, :too_deep}
      assert Core.make_numeric(db, db.special.when) == {:error, :not_standard}
      assert Core.make_numeric(db, db.main_id) == {:error, :protected}
    end
  end

  describe "numeric columns and calculations" do
    setup do
      %{db: db, amount: amount, ids: [heat, rent, phone]} = f = file()
      {:ok, db} = Core.set_number(db, heat, amount, 120)
      {:ok, db} = Core.set_number(db, rent, amount, 800.5)
      _ = phone
      Map.put(f, :db, db)
    end

    test "cells show the column's number format", %{db: db, view: view, ids: [heat, _, phone]} do
      [section] = ViewModel.build(db, db.views[view])
      cells = Map.new(section.rows, &{&1.item.id, &1.cells})
      assert cells[heat] == ["", "120.00"]
      assert cells[phone] == ["", ""]
    end

    test "Display % of total: each number's share of the section's total (User's Guide 8-7)",
         %{db: db, view: view, amount: amount, ids: [heat, rent, phone]} do
      [section] = ViewModel.build(db, db.views[view])
      assert Enum.map(section.rows, & &1.percents) == List.duplicate([nil, nil], 3)

      # 120 + 800.5 + 79.5 = 1000
      {:ok, db} = Core.set_number(db, phone, amount, 79.5)
      db = Core.set_column_format(db, view, {0, 1}, %NumberFormat{percent: true})
      [section] = ViewModel.build(db, db.views[view])
      percents = Map.new(section.rows, &{&1.item.id, &1.percents})

      assert {percents[heat], percents[rent], percents[phone]} ==
               {[nil, "12%"], [nil, "80%"], [nil, "8%"]}
    end

    test "% of total: nothing without a number, or when the total is 0" do
      assert NumberFormat.percent_of(nil, 10.0) == ""
      assert NumberFormat.percent_of(5.0, 0.0) == ""
      assert NumberFormat.percent_of(5.0, 20.0) == "25%"
    end

    test "% of total takes room on the screen beside the column" do
      column = %Column{category_id: 1, width: 12, number: %NumberFormat{percent: true}}
      assert Column.shown_width(column) == 18
      assert Column.shown_width(%{column | number: %NumberFormat{}}) == 12
    end

    test "a column given a standard head does not keep % of total",
         %{db: db, view: view, ids: [heat | _]} do
      db = Core.set_column_format(db, view, {0, 1}, %NumberFormat{percent: true})
      {:ok, db, other} = Core.add_category(db, db.main_id, "Other")
      _ = heat
      db = Core.set_column_head(db, view, {0, 1}, other)
      refute (db.views[view] |> Agendum.Core.View.columns(0) |> Enum.at(1)).number.percent
    end

    test "a section shows the total by default", %{db: db, view: view} do
      [section] = ViewModel.build(db, db.views[view])
      assert section.calcs == [{:total, ["", "920.50"]}]
    end

    test "each column chooses its calculations", %{db: db, view: view} do
      format = %NumberFormat{calcs: [:count, :total, :average, :minimum, :maximum]}
      db = Core.set_column_format(db, view, {0, 1}, format)
      [section] = ViewModel.build(db, db.views[view])

      assert section.calcs == [
               {:count, ["", "2"]},
               {:total, ["", "920.50"]},
               {:average, ["", "460.25"]},
               {:minimum, ["", "120.00"]},
               {:maximum, ["", "800.50"]}
             ]
    end

    test "a section without numeric columns has no calculations" do
      db = Core.new_file()
      [section] = ViewModel.build(db, db.views[hd(db.view_order)])
      assert section.calcs == []
    end

    test "items sort by their number", %{db: db, view: view, amount: amount} do
      key = %SortKey{on: {:category, amount}, order: :desc}
      db = Core.set_sort(db, view, :view, [key])
      [section] = ViewModel.build(db, db.views[view])
      assert Enum.map(section.rows, & &1.item.text) == ["rent", "heat", "phone"]
    end

    test "a new column gets the default number format" do
      assert %Column{}.number == %NumberFormat{}
    end
  end
end
