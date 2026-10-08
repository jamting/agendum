defmodule Agenda.TUI.HistoryTest do
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.Core.Database
  alias Agenda.TUI.{Layout, State}

  setup do
    Process.delete(:effects_seen)
    %{state: start(Agenda.Sample.build(~D[2026-10-08]))}
  end

  defp texts(state), do: state.db |> Database.items() |> Enum.map(& &1.text)

  test "CTRL-Z undoes an added item and CTRL-Y redoes it", %{state: state} do
    original = state.db
    state = press(state, ["Buy stamps", :enter])
    assert "Buy stamps" in texts(state)

    state = press(state, {:ctrl, "z"})
    assert state.db == original
    assert screen(state) =~ "Undone"

    state = press(state, {:ctrl, "y"})
    assert "Buy stamps" in texts(state)
    assert screen(state) =~ "Redone"
  end

  test "each committed action is one undo step; keystrokes while typing are not", %{state: state} do
    state = press(state, ["one", :enter, "two", :enter])
    assert length(state.undo) == 2

    state = press(state, [{:ctrl, "z"}])
    assert "one" in texts(state)
    refute "two" in texts(state)
  end

  test "undo reverses column assignments, done marks and discards", %{state: state} do
    original = state.db

    state =
      press(state, [:down, :right, "friday", :enter, :left, {:f, 4}, {:alt_f, 4}, "y"])

    assert length(state.undo) == 3
    state = press(state, [{:ctrl, "z"}, {:ctrl, "z"}, {:ctrl, "z"}])
    assert state.db == original

    assert state.undo == []
    assert screen(press(state, {:ctrl, "z"})) =~ "Nothing to undo"
  end

  test "a new change clears the redo stack", %{state: state} do
    state = press(state, ["one", :enter, {:ctrl, "z"}, "two", :enter])
    assert state.redo == []
    assert screen(press(state, {:ctrl, "y"})) =~ "Nothing to redo"
  end

  test "undoing back to the saved state clears the dirty flag", %{state: state} do
    state = press(state, ["x", :enter])
    assert state.dirty
    assert screen(state) =~ "(untitled) *"

    state = press(state, {:ctrl, "z"})
    refute state.dirty
  end

  test "undo returns to the view where the change happened", %{state: state} do
    state = press(state, [{:f, 8}, :insert, "People", :enter, "Contact", :enter])
    people = state.view_id
    state = press(state, [{:f, 8}, :up, :enter])
    refute state.view_id == people

    state = press(state, {:ctrl, "z"})
    assert Database.view(state.db, people) == nil
    assert Database.view(state.db, state.view_id)
  end

  test "undo works in the category manager", %{state: state} do
    state = press(state, [{:f, 9}, :ctrl_end, "Errands", :enter])
    assert Database.find_categories(state.db, "Errands") != []

    state = press(state, {:ctrl, "z"})
    assert Database.find_categories(state.db, "Errands") == []
    assert %{type: :catmgr} = State.mode(state)
  end

  test "CTRL-Z while typing does not undo", %{state: state} do
    state = press(state, ["one", :enter, "tw", {:ctrl, "z"}])
    assert state.edit.line.text == "tw"
    assert "one" in texts(state)
  end

  test "the menu offers Undo and Redo", %{state: state} do
    state = press(state, ["one", :enter, {:f, 10}, "u"])
    refute "one" in texts(state)
    state = press(state, [{:f, 10}, "r"])
    assert "one" in texts(state)
  end

  test "undo keeps the cursor usable when the current item disappears", %{state: state} do
    state = press(state, [:end, "last one", :enter, {:ctrl, "z"}])
    assert Layout.current_row(state)
  end
end
