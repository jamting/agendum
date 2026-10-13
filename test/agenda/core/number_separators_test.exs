defmodule Agenda.Core.NumberSeparatorsTest do
  @moduledoc """
  The person's decimal and thousands separators (R54; Setting Up Agenda
  1-25, 1-28): numbers are shown and read their way, wherever the core
  gets their context.
  """
  use ExUnit.Case, async: true

  alias Agenda.Core
  alias Agenda.Core.{Context, Database, InputFormat, NumberFormat, RangeFilter, ViewModel}

  @today ~D[2026-10-08]
  @comma %Context{now: ~N[2026-10-08 10:00:00], input: %InputFormat{decimal: ","}}

  # an item "Seeds" with 1234.5 in a numeric Cost column showing thousands
  defp costs(clock) do
    db = Core.new_file()
    {:ok, db, cost} = Core.add_category(db, db.main_id, "Cost")
    {:ok, db} = Core.make_numeric(db, cost)
    [view] = Database.views(db)
    db = Core.add_column(db, view.id, cost, {0, 0}, 12)

    db =
      Core.set_column_format(db, view.id, {0, 0}, %NumberFormat{thousands: true, calcs: [:total]})

    # the view again, with its columns
    [view] = Database.views(db)

    {db, seeds} = Core.add_item(db, "Seeds", @today, section: hd(view.sections).category_id)
    {:ok, db, :number} = Core.assign_by_name(db, seeds, cost, "1.234,5", clock)
    {db, view, seeds, cost}
  end

  test "Agenda's defaults: a dot for decimals, a comma for thousands" do
    assert InputFormat.number_opts(%InputFormat{}) == [decimal: ".", thousands: ","]
    assert Context.number_opts(@today) == [decimal: ".", thousands: ","]
  end

  test "a comma for decimals makes the dot the thousands separator, unless one is chosen" do
    assert InputFormat.number_opts(%InputFormat{decimal: ","}) == [decimal: ",", thousands: "."]

    assert InputFormat.number_opts(%InputFormat{decimal: ",", thousands: " "}) ==
             [decimal: ",", thousands: " "]

    # never the same character for both
    assert InputFormat.number_opts(%InputFormat{decimal: ",", thousands: ","}) ==
             [decimal: ",", thousands: "."]
  end

  test "typed numbers are read, and shown, the person's way" do
    {db, view, seeds, cost} = costs(@comma)
    assert Database.number(db, seeds, cost) == 1234.5

    [section] = ViewModel.build(db, view, @comma)
    assert hd(hd(section.rows).cells) == "1.234,50"
    assert [{:total, ["1.234,50", ""]}] = section.calcs
  end

  test "date-free clocks keep Agenda's defaults" do
    {db, view, _, _} = costs(@comma)
    [section] = ViewModel.build(db, view, @today)
    assert hd(hd(section.rows).cells) == "1,234.50"
  end

  test "range filters read and show bounds the person's way" do
    {db, _view, _, cost} = costs(@comma)

    assert {:ok, {:range, 2.5, nil, :inside}} =
             RangeFilter.build(db, cost, "2,5", nil, :inside, @comma)

    assert RangeFilter.describe(db, {:range, 2.5, 1000.0, :inside}, @comma) =~ "2,50..1.000"
  end

  test "children's names become numbers the person's way" do
    db = Core.new_file()
    {:ok, db, forecast} = Core.add_category(db, db.main_id, "Forecast")
    {:ok, db, half} = Core.add_category(db, forecast, "2,5")
    {db, a} = Core.add_item(db, "a", @today)
    db = Core.assign(db, a, half)

    assert Core.numeric_conversion(db, forecast, @comma).non_numeric == []
    {:ok, db} = Core.make_numeric(db, forecast, @comma)
    assert Database.number(db, a, forecast) == 2.5
  end
end
