defmodule Agendum.TUI.ColumnMoveTest do
  @moduledoc """
  View ▸ Column ▸ Move, or ALT-F10 on a column head (User's Guide 5-20):
  ← → (or < >) move the highlighted column in its section, and the view
  shows it at once; ENTER keeps the new place, one undo step, and ESC puts
  it back. Only the current section changes, even for a linked column.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core.{Database, View}
  alias Agendum.TUI.{History, State}

  # the sample's Activities view: Calls has When, Priority, Contact
  setup do
    %{state: start(Agendum.Sample.build(~D[2026-10-08]))}
  end

  defp heads(state, view_fun \\ &stored/1) do
    state
    |> view_fun.()
    |> View.columns(0)
    |> Enum.map(&state.db.categories[&1.category_id].name)
  end

  defp stored(state), do: hd(Database.views(state.db))

  test "the menu moves the highlighted column; ENTER keeps it, one undo step",
       %{state: state} do
    # Contact, the third column, highlighted on an item
    state = press(state, [:down, :right, :right, :right, {:f, 10}, "v", "c", "m"])
    assert %{type: :column_move} = State.mode(state)
    assert panel(state) =~ "Moving column Contact"
    state = press(state, [:left, :left])
    # the view shows it, the file does not have it yet
    assert heads(state, &State.view/1) == ["Contact", "When", "Priority"]
    assert heads(state) == ["When", "Priority", "Contact"]
    # the highlight goes with the column
    assert state.col == 1
    state = press(state, :enter)
    assert State.mode(state) == nil
    assert heads(state) == ["Contact", "When", "Priority"]
    assert state |> History.undo() |> heads() == ["When", "Priority", "Contact"]
  end

  test "ALT-F10 on a column head moves the column; > and < too", %{state: state} do
    # the section head line, its first column head (When) highlighted
    state = press(state, [:right, {:alt_f, 10}])
    assert %{type: :column_move} = State.mode(state)
    state = press(state, [">", ">", ">", "<", :enter])
    assert heads(state) == ["Priority", "When", "Contact"]
  end

  test "ESC puts it back, with the highlight", %{state: state} do
    state = press(state, [:right, {:alt_f, 10}, :right, :right, :esc])
    assert State.mode(state) == nil
    assert heads(state, &State.view/1) == ["When", "Priority", "Contact"]
    assert state.col == 1
    assert state.undo == []
  end

  describe "the item column (R55)" do
    # the screen's lines with Calls' head and its first item
    defp lines(state) do
      state |> screen() |> String.split("\n") |> Enum.filter(&(&1 =~ ~r/Contact|Terracotta/))
    end

    defp position(state), do: hd(stored(state).sections).item_column.position

    test "Move on the item text moves the item column among the columns", %{state: state} do
      state = press(state, [:down, {:f, 10}, "v", "c", "m"])
      assert panel(state) =~ "Moving the item column"
      state = press(state, [:right, :right, :enter])
      # When and Priority, then the item text, then Contact
      assert [head, item | _] = lines(state)
      assert head =~ ~r/^ When +Priority +Calls +Contact/
      assert item =~ ~r/^ 2026-10-31 +Medium +• Set up meeting/
      assert position(state) == 2
      # the highlight stays on the item text
      assert state.col == 0
      assert state |> History.undo() |> position() == 0
    end

    test "→ and ← go through the columns as they are shown", %{state: state} do
      state = press(state, [:down, {:f, 10}, "v", "c", "m", :right, :enter])
      # When, the item text, Priority, Contact: from the item text → is Priority
      assert state |> press(:right) |> Map.fetch!(:col) == 2
      assert state |> press(:left) |> Map.fetch!(:col) == 1
      assert state |> press([:left, :left, :left]) |> Map.fetch!(:col) == 1
    end

    test "ALT-R on the item text adds the column right of it", %{state: state} do
      state = press(state, [:down, {:f, 10}, "v", "c", "m", :right, :enter])
      state = press(state, [{:alt, "r"}, "p", "r", :enter])
      assert heads(state) == ["When", "Priority", "Priority", "Contact"]
      assert position(state) == 1
      assert state.col == 2
    end
  end
end
