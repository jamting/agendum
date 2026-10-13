defmodule Agenda.TUI.NumbersTest do
  @moduledoc "Numeric columns in the TUI (R29; User's Guide chapter 8)."
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.Core
  alias Agenda.Core.{Database, NumberFormat}
  alias Agenda.TUI.State

  @today ~D[2026-10-08]

  defmodule CategoryHelpers do
    @moduledoc false
    alias Agenda.TUI.{CategoryScreens, State}

    def props(state, cat_id), do: CategoryScreens.open_props(state, cat_id)

    def choose(state, field) do
      index = Enum.find_index(CategoryScreens.props_fields(), &(&1 == field))
      state = State.put_mode(state, %{State.mode(state) | cursor: index})
      Agenda.TUIHelpers.press(state, :enter)
    end
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
    db = Core.add_column(db, view, amount, 1)

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
    assert Agenda.TUI.Render.Export.text(state) =~ "TOTAL  [Amount: 120.00]"
  end

  test "text that is not a number is refused", %{state: state} do
    state = press(state, ["lots", :enter])
    assert screen(state) =~ "Not a number: lots"
    assert state.db.numbers == %{}
  end

  test "F2 edits the number; DEL removes it", %{state: state, amount: amount} do
    state = press(state, ["120", :enter, {:f, 2}])
    assert state.edit.line.text == "120"

    state = press(state, [{:ctrl, "u"}, "99", :enter, :delete])
    assert Database.number(state.db, heat(state), amount) == nil
  end

  test "the title bar shows # on a numeric column", %{state: state} do
    assert screen(state) =~ "# READY"
    refute screen(press(state, :left)) =~ "# READY"
  end

  test "View ▸ Column ▸ Properties sets the format and the calculations",
       %{state: state, view: view} do
    state = press(state, ["1234.5", :enter, {:f, 10}, "v", "c", "p"])
    text = screen(state)
    assert text =~ "Numeric column: Amount"
    assert text =~ ~r/Decimal places\s+: 2/
    assert text =~ "Sample: 1234.50 -1234.50"

    # Symbol None -> $; Thousands separator Yes; Average Yes
    state = press(state, [" ", :down, :down, " ", :down, :down, :down, :down, " ", :esc])

    assert hd(tl(state.db.views[view].columns)).number ==
             %NumberFormat{symbol: "$", thousands: true, calcs: [:total, :average]}

    text = screen(state)
    assert text =~ "$1,234.50"
    assert text =~ ~r/AVERAGE\s+\$1,234\.50/
  end

  test "decimal places go up and down with → and ←", %{state: state, view: view} do
    state = press(state, [{:f, 10}, "v", "c", "p", :down, :right, :right, :left, :esc])
    assert hd(tl(state.db.views[view].columns)).number.decimals == 3
  end

  test "Column Properties on the When column opens the date settings", %{state: state} do
    state = press(state, [:left, {:f, 10}, "v", "c", "p"])
    assert screen(state) =~ "Date column: When"
  end

  test "Item Properties lists the number; ENTER changes it", %{state: state, amount: amount} do
    state = press(state, ["120", :enter, :left, :left, {:f, 6}])
    assert screen(state) =~ "Amount (120.00)"

    # rows: text, note, stats, Entry, Expenses, Amount
    state = press(state, [:down, :down, :down, :down, :down, :enter])
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
      assert screen(state) =~ ~r/Type\s+: Standard/

      state = state |> CategoryHelpers.choose(:type) |> press("n")
      assert state.db.categories[cost].kind == :numeric
      assert screen(state) =~ ~r/Type\s+: Numeric/
    end

    test "with children, Agenda asks first and says which names become 0", %{state: state} do
      db = state.db
      {:ok, db, forecast} = Core.add_category(db, db.main_id, "Forecast")
      {:ok, db, _} = Core.add_category(db, forecast, "Good")

      state =
        %{state | db: db}
        |> CategoryHelpers.props(forecast)
        |> CategoryHelpers.choose(:type)
        |> press("n")

      assert panel(state) =~
               "Convert Forecast to numeric? Its 1 children become numbers; Good becomes 0"

      state = press(state, "y")
      assert state.db.categories[forecast].kind == :numeric
    end

    test "a date category cannot change type", %{state: state} do
      state =
        state |> CategoryHelpers.props(state.db.special.when) |> CategoryHelpers.choose(:type)

      assert screen(state) =~ "Only standard categories can change type"
    end
  end
end
