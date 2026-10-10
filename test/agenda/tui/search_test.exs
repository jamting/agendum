defmodule Agenda.TUI.SearchTest do
  @moduledoc "Searching a view (ALT-F6) and the file (Show View), and ALT-F8 (R37)."
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.Core
  alias Agenda.TUI.{Layout, State}

  setup do
    %{state: start(Agenda.Sample.build(~D[2026-10-08]))}
  end

  defp current(state), do: Layout.current_row(state).item.text

  test "ALT-F6 finds the first match and enters search mode", %{state: state} do
    state = press(state, [{:alt_f, 6}])
    assert screen(state) =~ "Search this view"

    state = press(state, ["abigail", :enter])
    assert %{type: :searching} = State.mode(state)
    assert current(state) =~ "Call Marketing"
    assert screen(state) =~ "Match 1 of 2"
    assert screen(state) =~ "SEARCH"
  end

  test "ALT-N and ALT-P move between matches; the ends are reported", %{state: state} do
    state = press(state, [{:alt_f, 6}, "abigail", :enter, {:alt, "n"}])
    assert current(state) =~ "Check with Abigail"
    assert screen(press(state, {:alt, "n"})) =~ "No more matches after this one"

    state = press(state, {:alt, "p"})
    assert current(state) =~ "Call Marketing"
  end

  test "F7 marks the highlighted match; ENTER ends the search", %{state: state} do
    state = press(state, [{:alt_f, 6}, "abigail", :enter, {:f, 7}, :enter])
    assert state.modes == []
    assert Layout.current_row(state).item.marked
  end

  test "no match is reported", %{state: state} do
    state = press(state, [{:alt_f, 6}, "zebra", :enter])
    assert screen(state) =~ ~s(No item in this view contains "zebra")
    assert state.modes == []
  end

  test "searching notes and matching case are settings", %{state: state} do
    [first | _] = state.db.item_order
    state = %{state | db: Core.set_note(state.db, first, "bring the Budget")}

    # Match on: Item text -> Note text
    state = press(state, [{:alt_f, 6}, "budget", :down, " ", :enter])
    assert Layout.current_row(state).item.id == first

    # Ignore case: Yes -> No; "budget" no longer matches "Budget"
    state =
      press(state, [:esc, {:alt_f, 6}, {:ctrl, "u"}, "budget", :down, :down, :down, " ", :enter])

    assert screen(state) =~ "No item in this view contains"
  end

  test "the last search is offered again", %{state: state} do
    state = press(state, [{:alt_f, 6}, "abigail", :enter, :esc, {:alt_f, 6}])
    assert screen(state) =~ "abigail"
  end

  test "Search > File shows every match in the Show View; ALT-F8 returns", %{state: state} do
    state = press(state, [{:f, 10}, "s", "f", "Abigail", :enter])
    assert State.view(state).name == "Show View"
    assert screen(state) =~ "2 item(s) contain"
    assert Enum.count(Layout.rows(state), &(&1.kind == :item)) == 2

    state = press(state, {:alt_f, 8})
    assert State.view(state).name == "Activities"
    assert State.view(press(state, {:alt_f, 8})).name == "Show View"
  end
end
