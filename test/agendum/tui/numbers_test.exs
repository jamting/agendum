# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.NumbersTest do
  @moduledoc "Numeric columns in the TUI (R29; User's Guide chapter 8)."
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.Core.{Database, NumberFormat}

  @today ~D[2026-10-08]

  defmodule CategoryHelpers do
    @moduledoc false
    alias Agendum.TUI.CategoryScreens

    def props(state, cat_id), do: CategoryScreens.open_props(state, cat_id)

    def choose(state, label),
      do: state |> Agendum.TUIHelpers.to_setting(label) |> Agendum.TUIHelpers.press(" ")
  end

  # An Expenses section with the columns When and Amount (numeric), and the
  # items heat, rent and phone. The cursor starts on heat's Amount cell.
  setup do
    db = Core.new_file()
    {:ok, db, expenses} = Core.add_category(db, db.main_id, "Expenses")
    {:ok, db, amount} = Core.add_category(db, db.main_id, "Amount")
    {:ok, db} = Core.make_numeric(db, amount)
    view = hd(db.view_order)
    db = Core.set_section_category(db, view, 0, expenses)
    db = Core.add_column(db, view, amount, {0, 1})

    db =
      Enum.reduce(["heat", "rent", "phone"], db, fn text, db ->
        {db, _} = Core.add_item(db, text, @today, section: expenses)
        db
      end)

    state = db |> start() |> press([:down, :right, :right])
    %{state: state, amount: amount, view: view}
  end

  defp heat(state), do: Enum.find(Map.values(state.db.items), &(&1.text == "heat")).id

  test "typing a number in a numeric column enters it, right-aligned; the section shows its total",
       %{state: state, amount: amount} do
    state = press(state, ["120", :enter, :down, "800.5", :enter])
    assert Database.number(state.db, heat(state), amount) == 120.0

    text = screen(state)
    assert text =~ ~r/heat\s+120\.00/
    assert text =~ ~r/rent\s+800\.50/
    assert text =~ ~r/TOTAL\s+920\.50/
  end

  test "printing to a file includes the calculations", %{state: state} do
    state = press(state, ["120", :enter])
    assert Agendum.TUI.Render.Export.text(state) =~ "TOTAL  [Amount: 120.00]"
  end

  test "text that is not a number is refused", %{state: state} do
    state = press(state, ["lots", :enter])
    assert panel(state) =~ message(:bad_number)
    assert state.db.numbers == %{}
  end

  test "F2 edits the number; DEL removes it", %{state: state, amount: amount} do
    state = press(state, ["120", :enter, {:f, 2}])
    assert state.edit.line.text == "120"

    state = press(state, [{:ctrl, "u"}, "99", :enter, :delete])
    assert Database.number(state.db, heat(state), amount) == nil
  end

  # Agenda shows # at the right of the View line, beside ♪'s place
  # (checked in Agenda 2.0, 2026-10-25)
  test "the control panel shows # on a numeric column", %{state: state} do
    second = fn state -> state |> screen() |> String.split("\n") |> Enum.at(1) end
    assert second.(state) =~ ~r/# *$/
    refute second.(press(state, :left)) =~ "#"
    refute screen(state) =~ "# 2026-10-08"
  end

  test "View ▸ Column ▸ Properties sets the format and the calculations",
       %{state: state, view: view} do
    state = press(state, ["1234.5", :enter, {:f, 10}, "v", "c", "p"])
    text = screen(state)
    assert text =~ ~r/Column head: +Amount +Category type: +Numeric/
    assert text =~ ~r/Decimal places: +2/
    assert text =~ "Formatted Samples"
    assert text =~ ~r/1234.50 +-1234.50/

    # ↓ from Column head: Width, then Symbol: None -> $; ↓ ↓ Thousands
    # separator: Yes; → beside it, Average: Yes
    state = press(state, [:down, :down, " ", :down, :down, " ", :right, " ", :enter])

    assert hd(tl(Agendum.Core.View.columns(state.db.views[view], 0))).number ==
             %NumberFormat{symbol: "$", thousands: true, calcs: [:total, :average]}

    text = screen(state)
    assert text =~ "$1,234.50"
    assert text =~ ~r/AVERAGE\s+\$1,234\.50/
  end

  test "Display % of total: a % tot column beside the numbers (User's Guide 8-7)",
       %{state: state, view: view} do
    state = press(state, ["120", :enter, :down, "800.5", :enter, :down, "79.5", :enter])
    state = press(state, [{:f, 10}, "v", "c", "p"])
    assert screen(state) =~ ~r/Display % of total: +No +Maximum: +No/
    state = state |> to_setting("Display % of total") |> press([" ", :enter])
    assert hd(tl(Agendum.Core.View.columns(state.db.views[view], 0))).number.percent
    # and in print, after the number
    assert Agendum.TUI.Render.Export.text(state) =~ "heat  [Amount: 120.00 (12%)]"

    lines = state |> screen() |> String.split("\n")
    head = Enum.find(lines, &(&1 =~ "Amount"))
    assert head =~ ~r/Amount +% tot/
    # each share right-aligned under "% tot", 120 of 1000 being 12%
    heat = Enum.find(lines, &(&1 =~ "heat"))
    assert heat =~ ~r/120\.00 +12%/
    assert at_end(head, "% tot") == at_end(heat, "12%")
    assert Enum.find(lines, &(&1 =~ "rent")) =~ ~r/800\.50 +80%/
  end

  # the column (in characters) where `text` ends in `line`
  defp at_end(line, text),
    do: (line |> String.split(text) |> hd() |> String.length()) + String.length(text)

  # F8 and ALT-F8 (User's Guide 2-17): a new column's number format
  test "ALT-F8 puts a numeric column's format back", %{state: state, view: view} do
    number = fn s -> hd(tl(Agendum.Core.View.columns(s.db.views[view], 0))).number end

    keys = [
      "1234.5",
      :enter,
      {:f, 10},
      "v",
      "c",
      "p",
      :down,
      :down,
      " ",
      :down,
      :down,
      " ",
      :right,
      " "
    ]

    changed = press(state, keys)
    refute number.(changed) == %Agendum.Core.NumberFormat{}
    assert number.(press(changed, {:alt_f, 8})) == %Agendum.Core.NumberFormat{}
  end

  test "Select numeric functions: ALT-F8 gives back a new column's (Total)",
       %{state: state, view: view} do
    box =
      state
      |> press(["1234.5", :enter, {:f, 10}, "v", "s", "p"])
      |> to_setting("Select numeric functions")
      |> press(" ")
      |> to_setting("Average")
      |> press(" ")

    calcs = fn s -> Agendum.Core.section_calcs(s.db, view, 0) end
    assert :average in calcs.(box)
    assert calcs.(press(box, {:alt_f, 8})) == [:total]
  end

  test "decimal places are typed", %{state: state, view: view} do
    # ↓ from Column head: Width, Symbol, Decimal places; ENTER keeps it, ENTER the box
    keys = [{:f, 10}, "v", "c", "p", :down, :down, :down, "3", :enter, :enter]

    state = press(state, keys)
    assert hd(tl(Agendum.Core.View.columns(state.db.views[view], 0))).number.decimals == 3
  end

  test "Column Properties on the When column opens the date settings", %{state: state} do
    state = press(state, [:left, {:f, 10}, "v", "c", "p"])
    assert screen(state) =~ "Date Column Properties"
  end

  test "Item Properties lists the number; F4 changes it", %{state: state, amount: amount} do
    state = press(state, ["120", :enter, :left, :left, {:f, 6}])
    assert screen(state) =~ "Amount (120.00)"

    # rows: text, note, stats, Entry, Expenses, Amount
    state = press(state, [:down, :down, :down, :down, :down, {:f, 4}])
    assert screen(state) =~ "Amount:"
    state = press(state, [{:ctrl, "u"}, "75", :enter])
    assert Database.number(state.db, heat(state), amount) == 75.0
  end

  test "SPACE on a numeric category in the assignment profile asks for the number",
       %{state: state, amount: amount} do
    # F3 on the item text opens the profile; rows: MAIN Entry When Done Expenses Amount
    state = press(state, [:left, :left, {:f, 3}] ++ List.duplicate(:down, 5) ++ [" "])
    assert screen(state) =~ "Amount:"
    state = press(state, ["42", :enter])
    assert Database.number(state.db, heat(state), amount) == 42.0

    # SPACE again removes it
    state = press(state, " ")
    assert Database.number(state.db, heat(state), amount) == nil
  end

  test "typing a numeric category in Item Properties asks for the number",
       %{state: state, amount: amount} do
    state = press(state, [:left, :left, {:f, 6}, :end, "Amou", :enter])
    assert screen(state) =~ "Amount:"
    state = press(state, ["7", :enter])
    assert Database.number(state.db, heat(state), amount) == 7.0
  end

  test "ALT-M does not assign a numeric category without a number", %{state: state} do
    # MakeAssign box: MAIN Entry When Done Expenses Amount
    state = press(state, [:left, :left, {:alt, "m"}] ++ List.duplicate(:down, 5) ++ [:enter])
    assert screen(state) =~ "Type numbers in the Amount column"
    assert state.db.numbers == %{}
  end

  describe "making a category numeric in Category Properties" do
    test "a category without children converts at once", %{state: state} do
      {:ok, db, cost} = Core.add_category(state.db, state.db.main_id, "Cost")
      state = %{state | db: db} |> CategoryHelpers.props(cost)
      assert screen(state) =~ ~r/Type: +Standard/

      state = state |> CategoryHelpers.choose("Type") |> press("n")
      assert state.db.categories[cost].kind == :numeric
      assert screen(state) =~ ~r/Type: +Numeric/
    end

    test "with children, Agenda asks first and says which names become 0", %{state: state} do
      db = state.db
      {:ok, db, forecast} = Core.add_category(db, db.main_id, "Forecast")
      {:ok, db, _} = Core.add_category(db, forecast, "Good")

      state =
        %{state | db: db}
        |> CategoryHelpers.props(forecast)
        |> CategoryHelpers.choose("Type")
        |> press("n")

      # the question box (it wraps the text over its lines)
      assert Agendum.TUI.State.mode(state).question ==
               "Convert Forecast to numeric? Its 1 children become numbers; Good becomes 0."

      state = press(state, "y")
      assert state.db.categories[forecast].kind == :numeric
    end

    test "a date category cannot change type", %{state: state} do
      state =
        state |> CategoryHelpers.props(state.db.special.when) |> CategoryHelpers.choose("Type")

      assert panel(state) =~ message(:cannot_change_type)
    end
  end
end
