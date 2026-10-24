defmodule Agendum.TUI.HistoryTest do
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core.Database
  alias Agendum.TUI.{Layout, State}

  setup do
    Process.delete(:effects_seen)
    %{state: start(Agendum.Sample.build(~D[2026-10-08]))}
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
    assert length(state.history.undo) == 2

    state = press(state, [{:ctrl, "z"}])
    assert "one" in texts(state)
    refute "two" in texts(state)
  end

  describe "a step ended partway through a key (State.end_step/1)" do
    alias Agendum.TUI.History

    defp add(state, text) do
      {db, _id} = Agendum.Core.add_item(state.db, text, state.today)
      State.change_db(state, db)
    end

    test "makes two undo steps of one key", %{state: state} do
      before = state
      middle = add(state, "first")
      next = middle |> State.end_step() |> add("second")

      state = History.record(before, next)
      assert length(state.history.undo) == 2
      assert state.history.step == nil

      state = History.undo(state)
      assert state.db == middle.db
      state = History.undo(state)
      assert state.db == before.db
    end

    test "is one step when nothing changed before it, or nothing after", %{state: state} do
      changed = add(state, "one")
      assert length(History.record(state, State.end_step(changed)).history.undo) == 1

      assert length(History.record(state, state |> State.end_step() |> add("one")).history.undo) ==
               1
    end
  end

  test "undo reverses column assignments, done marks and discards", %{state: state} do
    original = state.db

    state =
      press(state, [:down, :right, "friday", :enter, :left, {:f, 4}, {:alt_f, 4}, "y"])

    assert length(state.history.undo) == 3
    state = press(state, [{:ctrl, "z"}, {:ctrl, "z"}, {:ctrl, "z"}])
    assert state.db == original

    assert state.history.undo == []
    assert screen(press(state, {:ctrl, "z"})) =~ "Nothing to undo"
  end

  test "a new change clears the redo stack", %{state: state} do
    state = press(state, ["one", :enter, {:ctrl, "z"}, "two", :enter])
    assert state.history.redo == []
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
    state = press(state, [{:f, 8}, :insert, "People", :enter, "s", "Contact", :enter])
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

  # Agenda's menus have no Undo or Redo: the keys do it (AGENDA_PARITY, the
  # menu's shape)
  test "CTRL-Z undoes and CTRL-Y redoes", %{state: state} do
    state = press(state, ["one", :enter, {:ctrl, "z"}])
    refute "one" in texts(state)
    state = press(state, {:ctrl, "y"})
    assert "one" in texts(state)
  end

  test "undo keeps the cursor usable when the current item disappears", %{state: state} do
    state = press(state, [:end, "last one", :enter, {:ctrl, "z"}])
    assert Layout.current_row(state)
  end
end
