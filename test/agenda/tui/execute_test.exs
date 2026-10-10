defmodule Agenda.TUI.ExecuteTest do
  @moduledoc "Utilities Execute, ALT-X and ALT-E (R15e)."
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.Core
  alias Agenda.Core.Database
  alias Agenda.TUI.State

  # Calls holds five items; Meetings gets a text condition and Calls a
  # special action after the items were entered.
  setup do
    state = start(Agenda.Sample.build(~D[2026-10-08]))
    meetings = hd(Database.find_categories(state.db, "Meetings"))
    calls = hd(Database.find_categories(state.db, "Calls"))
    {:ok, db} = Core.set_also_match(state.db, meetings, "meeting")
    {:ok, db} = Core.set_special_action(db, calls, :done)
    %{state: %{state | db: db}, meetings: meetings, calls: calls}
  end

  defp in_meetings(state, meetings),
    do: Enum.count(Database.items(state.db), &Database.member?(state.db, &1.id, meetings))

  test "Category ▸ Execute shows the Execute box; ENTER applies everything to all items",
       %{state: state, meetings: meetings} do
    state = press(state, [{:f, 10}, "c", "e"])
    assert %{type: :execute} = State.mode(state)
    text = screen(state)
    assert text =~ "Execute conditions and actions"
    assert text =~ ~r/Apply conditions of\s+: MAIN \(all categories\)/
    assert text =~ ~r/Against\s+: All items/
    assert text =~ ~r/Apply actions to\s+: New assignments only/

    state = press(state, [:down, :down, :enter])
    assert state.modes == []
    assert in_meetings(state, meetings) == 2
    assert screen(state) =~ "Executed for 5 items"
    # Calls' new action did not run on old assignments
    refute Enum.any?(Database.items(state.db), & &1.done)
  end

  test "Old & new assignments runs the actions on items already there", %{state: state} do
    state = press(state, [{:f, 10}, "c", "e", :down, :down, " ", :enter])
    assert Enum.all?(Database.items(state.db), & &1.done)
  end

  test "Against: the current item only", %{state: state, meetings: meetings} do
    # the first item: "Set up meeting at Terracotta…"
    state = press(state, [:down, {:f, 10}, "c", "e", :down, " ", :enter])
    assert in_meetings(state, meetings) == 1
  end

  test "Apply conditions of: a chosen family", %{state: state, meetings: meetings} do
    # Contact's family has no conditions: nothing changes
    state = press(state, [{:f, 10}, "c", "e", :enter, "Contact", :enter, :down, :down, :enter])
    assert in_meetings(state, meetings) == 0
  end

  test "ALT-X executes everything at once", %{state: state, meetings: meetings} do
    state = press(state, {:alt, "x"})
    assert in_meetings(state, meetings) == 2
  end

  test "ALT-E in the category manager executes the highlighted category", %{state: state} do
    # Meetings is the last category
    state = press(state, [{:f, 9}, :ctrl_end, {:alt, "e"}])
    assert screen(state) =~ "Executed Meetings for 5 items"
    assert %{type: :catmgr} = State.mode(state)
  end

  test "ALT-E executes the highlighted section's category on all items", %{state: state} do
    # on the Calls head: Calls' family (with its special action, for new
    # assignments only) — the items already in Calls stay undone
    state = press(state, {:alt, "e"})
    assert screen(state) =~ "Executed Calls for 5 items"
  end
end
