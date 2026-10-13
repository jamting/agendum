defmodule Agenda.TUI.ColumnMoveTest do
  @moduledoc """
  View ▸ Column ▸ Move, or ALT-F10 on a column head (User's Guide 5-20):
  ← → (or < >) move the highlighted column in its section, and the view
  shows it at once; ENTER keeps the new place, one undo step, and ESC puts
  it back. Only the current section changes, even for a linked column.
  """
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.Core.{Database, View}
  alias Agenda.TUI.{History, State}

  # the sample's Activities view: Calls has When, Priority, Contact
  setup do
    %{state: start(Agenda.Sample.build(~D[2026-10-08]))}
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

  test "asks for a column first", %{state: state} do
    state = press(state, [:down, {:f, 10}, "v", "c", "m"])
    assert panel(state) =~ "Highlight a column"
  end
end
