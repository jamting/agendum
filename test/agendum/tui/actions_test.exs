# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.ActionsTest do
  @moduledoc "Assignment, date, numeric and special actions in Category Properties (R15b)."
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.Core.Database
  alias Agendum.TUI.State

  # Meetings is the last category in the manager.
  setup do
    %{state: start(Agendum.Sample.build(~D[2026-10-08]), now: ~N[2026-10-08 10:00:00])}
  end

  defp cat(state, name), do: hd(Database.find_categories(state.db, name))

  defp open_actions(state),
    do:
      state
      |> press([{:f, 9}, :ctrl_end, {:f, 6}])
      |> to_setting("Assignment actions")
      |> press(" ")

  test "SPACE on a category cycles: assign, remove, none", %{state: state} do
    state = open_actions(state) |> press(["Calls", :enter, " "])
    meetings = state.db.categories[cat(state, "Meetings")]
    assert meetings.also_assign == [cat(state, "Calls")]

    state = press(state, " ")
    meetings = state.db.categories[cat(state, "Meetings")]
    assert meetings.also_assign == []
    assert meetings.actions == [{cat(state, "Calls"), :remove}]

    state = press(state, " ")
    assert state.db.categories[cat(state, "Meetings")].actions == []
  end

  test "the row lists the actions", %{state: state} do
    state = open_actions(state) |> press(["Calls", :enter, " ", " ", :esc])
    assert screen(state) =~ ~r/Assignment actions:.*\n.*-Calls/
  end

  test "a date category opens the Date Action box", %{state: state} do
    state = open_actions(state) |> press(["When", :enter, " "])
    assert %{type: :action_box} = State.mode(state)
    assert screen(state) =~ "Date action: When"

    state = press(state, [:down, "tomorrow", :enter])

    assert state.db.categories[cat(state, "Meetings")].actions == [
             {state.db.special.when, {:set, "tomorrow"}}
           ]

    # the action runs when an item joins Meetings
    db = quiet_meetings(state.db)
    item = hd(db.item_order)
    db = Core.assign(db, item, cat(state, "Meetings"), ~D[2026-10-08])
    assert db.items[item].when == ~D[2026-10-09]
  end

  test "the Date Action box can clear the date instead, and DEL removes the action",
       %{state: state} do
    state = open_actions(state) |> press(["When", :enter, " ", " ", :enter])

    assert state.db.categories[cat(state, "Meetings")].actions == [
             {state.db.special.when, :clear}
           ]

    state = press(state, ["When", :enter, " ", :delete])
    assert state.db.categories[cat(state, "Meetings")].actions == []
  end

  test "a bad date keeps the box open", %{state: state} do
    state = open_actions(state) |> press(["When", :enter, " ", :down, "someday", :enter])
    assert %{type: :action_box} = State.mode(state)
    assert panel(state) =~ message(:bad_date)
  end

  test "Special action cycles none, done, discard", %{state: state} do
    state =
      state |> press([{:f, 9}, :ctrl_end, {:f, 6}]) |> to_setting("Special actions") |> press(" ")

    assert state.db.categories[cat(state, "Meetings")].special == :done
    assert screen(state) =~ ~r/Special actions: +Mark items done/
    state = press(state, " ")
    assert state.db.categories[cat(state, "Meetings")].special == :discard
    state = press(state, " ")
    assert state.db.categories[cat(state, "Meetings")].special == nil
  end

  test "an item discarded by a special action as it is typed does not upset the view",
       %{state: state} do
    {:ok, db} = Core.set_special_action(state.db, cat(state, "Calls"), :discard)
    state = %{state | db: db} |> press(["Spam call", :enter])
    refute Enum.any?(Database.items(state.db), &(&1.text == "Spam call"))
    assert screen(state) =~ "Calls"
  end
end
