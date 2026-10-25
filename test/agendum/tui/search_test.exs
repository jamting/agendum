defmodule Agendum.TUI.SearchTest do
  @moduledoc "Searching a view (ALT-F6) and the file (Show View), and ALT-F8 (R37)."
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.TUI.{Layout, State}

  setup do
    %{state: start(Agendum.Sample.build(~D[2026-10-08]))}
  end

  defp current(state), do: Layout.current_row(state).item.text

  test "ALT-F6 finds the first match and enters search mode", %{state: state} do
    state = press(state, [{:alt_f, 6}])
    assert screen(state) =~ "Search"

    state = press(state, ["abigail", :enter])
    assert %{type: :searching} = State.mode(state)
    assert current(state) =~ "Call Marketing"
    assert screen(state) =~ "Match 1 of 2"
  end

  test "ALT-N and ALT-P move between matches; the ends are reported", %{state: state} do
    state = press(state, [{:alt_f, 6}, "abigail", :enter, {:alt, "n"}])
    assert current(state) =~ "Check with Abigail"
    assert panel(press(state, {:alt, "n"})) =~ message(:no_more_matches)

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
    assert panel(state) =~ message(:no_matches)
    assert state.modes == []
  end

  test "searching notes and matching case are settings", %{state: state} do
    [first | _] = state.db.item_order
    state = %{state | db: Core.set_note(state.db, first, "bring the Budget", state.today)}

    # Match on: Item text -> Note text
    state = press(state, [{:alt_f, 6}, "budget", :down, " ", :enter])
    assert Layout.current_row(state).item.id == first

    # Ignore case: Yes -> No; "budget" no longer matches "Budget"
    state =
      press(state, [:esc, {:alt_f, 6}, {:ctrl, "u"}, "budget", :down, :down, :down, " ", :enter])

    assert panel(state) =~ message(:no_matches)
  end

  test "the last search is offered again", %{state: state} do
    state = press(state, [{:alt_f, 6}, "abigail", :enter, :esc, {:alt_f, 6}])
    assert screen(state) =~ "abigail"
  end

  test "Search > File shows every match in the Show View; ALT-F8 returns", %{state: state} do
    state = press(state, [{:f, 10}, "u", "s", "m", "Abigail", :enter])
    assert State.view(state).name == "Show View"
    assert screen(state) =~ "2 item(s) contain"
    assert Enum.count(Layout.rows(state), &(&1.kind == :item)) == 2

    state = press(state, {:alt_f, 8})
    assert State.view(state).name == "Activities"
    assert State.view(press(state, {:alt_f, 8})).name == "Show View"
  end
end
