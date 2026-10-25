defmodule Agendum.TUI.UnindexedTest do
  @moduledoc """
  Unindexed categories in the TUI (R29b; checked in Agenda 2.0,
  2026-10-25): Column Add's and Category Properties' Unindexed type, a
  text typed under "Text value:", ⌂ at the top right, DEL, F2, Item
  Properties and the profile.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Core
  alias Agendum.Core.Database
  alias Agendum.Starters.Planner
  alias Agendum.TUI.{Layout, State}

  @today ~D[2026-10-12]

  setup do
    db = Planner.build() |> Planner.with_samples(@today)
    state = start(db, today: @today, height: 25, width: 80)
    people = Enum.find(Map.values(state.db.views), &(&1.name == "People"))
    state = state |> State.switch_view(people.id) |> Layout.settle()

    # an Address column, unindexed, after the item text
    {:ok, db, address} = Core.add_category(state.db, state.db.main_id, "Address")
    {:ok, db} = Core.add_column_as(db, people.id, address, :unindexed, {0, 1})
    with_column = %{state | db: db} |> Layout.settle()

    # People's columns: Priority, then Address, then When
    %{
      state: state,
      with: with_column,
      column: press(with_column, [:down, :right, :right]),
      address: address
    }
  end

  defp line(state, n), do: state |> screen() |> String.split("\n") |> Enum.at(n)
  defp item_id(state), do: Layout.current_row(state).item.id

  describe "Column Add" do
    test "the Category type goes Standard, Numeric, Date, Unindexed, as Agenda's", %{state: state} do
      box = state |> press([:down, {:f, 10}, "v", "c", "a"]) |> to_setting("Category type")
      assert screen(press(box, List.duplicate(" ", 3))) =~ ~r/Category type: +Unindexed/
    end

    test "an unindexed column has no Format, as Agenda's", %{state: state} do
      box = state |> press([:down, {:f, 10}, "v", "c", "a"]) |> to_setting("Category type")
      refute screen(press(box, List.duplicate(" ", 3))) =~ "Format:"
    end
  end

  describe "the column" do
    test "a text is typed under Text value:, and shows in the cell", %{column: state, address: a} do
      typing = press(state, "12 Grant Ave")
      assert line(typing, 0) =~ ~r/^ Text value: +EDIT/
      assert line(typing, 1) =~ ~r/^ 12 Grant Ave/
      refute screen(typing) =~ "AUTOC"

      done = press(typing, :enter)
      assert Database.text(done.db, item_id(done), a) == "12 Grant Ave"
      assert screen(done) =~ "·12 Grant Ave"
    end

    test "⌂ at the right of the View line, as Agenda's", %{column: state} do
      assert line(state, 1) =~ "⌂"
    end

    test "DEL takes the text away", %{column: state, address: a} do
      done = press(state, ["12 Grant Ave", :enter, :delete])
      assert Database.text(done.db, item_id(done), a) == nil
    end

    test "F2 edits the text it has", %{column: state} do
      typing = press(state, ["12 Grant Ave", :enter, {:f, 2}])
      assert line(typing, 1) =~ ~r/^ 12 Grant Ave/
    end
  end

  test "Item Properties lists the text, and F4 changes it", %{column: state} do
    state = press(state, ["12 Grant Ave", :enter])
    box = press(state, [:left, {:f, 6}])
    assert screen(box) =~ "Address (12 Grant Ave)"
    box = box |> to_setting("Assigned to")

    found =
      Enum.find(0..12, fn n ->
        screen(press(box, List.duplicate(:down, n))) =~ ~r/Address \(12 Grant Ave\)/
      end)

    assert found
  end

  test "SPACE on it in the assignment profile asks for the text", %{with: state, address: a} do
    profile = press(state, [:down, {:f, 3}])
    mode = State.mode(profile)
    rows = Agendum.TUI.CategoryScreens.rows(profile, mode)
    at = Enum.find_index(rows, fn {id, _} -> id == a end)
    profile = press(profile, List.duplicate(:down, at - mode.cursor))
    asked = press(profile, " ")
    assert asked |> screen() |> String.split("\n") |> hd() =~ "Address:"
    done = press(asked, ["1 Main St", :enter])
    assert Database.text(done.db, item_id(press(state, :down)), a) == "1 Main St"
  end

  test "the category manager marks it ⌂", %{with: state, address: a} do
    catmgr = press(state, {:f, 9})
    mode = State.mode(catmgr)
    rows = Agendum.TUI.CategoryScreens.rows(catmgr, mode)
    at = Enum.find_index(rows, fn {id, _} -> id == a end)
    assert screen(press(catmgr, List.duplicate(:down, at - mode.cursor))) =~ "⌂ Address"
  end

  describe "Category Properties ▸ Type" do
    # ours a list (Unindexed first, Agenda's order), Agenda's question
    test "Unindexed first, then Numeric and Date; converting asks first", %{state: state} do
      {:ok, db, phone} = Core.add_category(state.db, state.db.main_id, "Phone")

      box =
        %{state | db: db} |> Agendum.TUI.CategoryScreens.open_props(phone) |> to_setting("Type")

      listed = press(box, " ")
      assert %{type: :choice, kind: :type} = State.mode(listed)
      asked = press(listed, :enter)
      assert screen(asked) =~ "Convert to unindexed category (can't be changed back)?"
      done = press(asked, ["y"])
      assert done.db.categories[phone].kind == :unindexed
    end
  end
end
