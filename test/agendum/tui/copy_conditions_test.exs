defmodule Agendum.TUI.CopyConditionsTest do
  @moduledoc """
  ALT-F9 (CPY C/A) and ALT-F8 (CLR C/A) in the category manager, as
  Agenda's (R15f; checked in Agenda 2.0, 2026-10-26): the top line says
  "Move cursor to the category you want to copy to", ENTER on the target
  copies (asking what, when the source has conditions and actions), ESC
  cancels; clearing asks first. With nothing to copy or clear nothing
  happens, as in Agenda.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.TUI.{CategoryScreens, State}

  @today ~D[2026-10-26]

  setup do
    db = Core.new_file()
    {:ok, db, people} = Core.add_category(db, db.main_id, "People")
    {:ok, db, north} = Core.add_category(db, db.main_id, "North")
    {:ok, db, new} = Core.add_category(db, db.main_id, "New")
    {:ok, db, fred} = Core.add_category(db, people, "Fred")
    {:ok, db, barney} = Core.add_category(db, people, "Barney")
    {:ok, db, wilma} = Core.add_category(db, people, "Wilma")
    {:ok, db} = Core.add_condition(db, fred, north, :assigned)
    {:ok, db} = Core.add_condition(db, wilma, north, :not_assigned)
    {:ok, db} = Core.set_action(db, wilma, new, :assign, @today)

    state = start(db, today: @today) |> press({:f, 9})
    %{state: state, fred: fred, barney: barney, wilma: wilma, north: north, new: new}
  end

  # the highlight on the category `id`
  defp on(state, id) do
    mode = State.mode(state)
    index = state |> CategoryScreens.rows(mode) |> Enum.find_index(&(elem(&1, 0) == id))
    State.put_mode(state, %{mode | cursor: index})
  end

  test "ALT-F9 asks for the target on the top line; ENTER there copies", c do
    choosing = c.state |> on(c.fred) |> press({:alt_f, 9})
    assert panel(choosing) =~ "Move cursor to the category you want to copy to"

    # the arrows move as always; ENTER copies instead of moving down
    copied = choosing |> press(:down) |> press(:enter)
    assert copied.db.categories[c.barney].conditions == [{c.north, :assigned}]
    refute panel(copied) =~ "Move cursor"
  end

  test "ESC while choosing cancels", c do
    state = c.state |> on(c.fred) |> press([{:alt_f, 9}, :down, :esc])
    assert state.db == c.state.db
    assert %{type: :catmgr} = State.mode(state)
    refute panel(state) =~ "Move cursor"
  end

  test "a source with conditions and actions asks what to copy", c do
    asked = c.state |> on(c.wilma) |> press({:alt_f, 9}) |> on(c.barney) |> press(:enter)
    assert screen(asked) =~ ~r/Copy: +Condition & action/

    conditions = press(asked, [" ", :enter])
    barney = conditions.db.categories[c.barney]
    assert barney.conditions == [{c.north, :not_assigned}]
    assert barney.also_assign == []

    both = press(asked, :enter).db.categories[c.barney]
    assert both.also_assign == [c.new]
  end

  test "ALT-F9 on a category with nothing to copy does nothing", c do
    state = c.state |> on(c.barney) |> press({:alt_f, 9})
    refute panel(state) =~ "Move cursor"
  end

  test "ALT-F8 asks Agenda's question, then clears", c do
    asked = c.state |> on(c.fred) |> press({:alt_f, 8})
    assert screen(asked) =~ "Clear the condition?"
    assert press(asked, :enter).db.categories[c.fred].conditions == []
    assert press(asked, :esc).db.categories[c.fred].conditions != []
  end

  test "ALT-F8 on conditions and actions asks what to clear", c do
    asked = c.state |> on(c.wilma) |> press({:alt_f, 8})
    assert screen(asked) =~ ~r/Clear: +Condition & action/
    wilma = press(asked, :enter).db.categories[c.wilma]
    assert wilma.conditions == [] and wilma.also_assign == []
  end

  test "ALT-F8 with nothing to clear does nothing; CTRL-Z undoes a clear", c do
    assert c.state |> on(c.barney) |> press({:alt_f, 8}) |> State.mode() |> Map.get(:type) ==
             :catmgr

    cleared = c.state |> on(c.fred) |> press([{:alt_f, 8}, :enter])
    assert press(cleared, {:ctrl, "z"}).db.categories[c.fred].conditions != []
  end
end
