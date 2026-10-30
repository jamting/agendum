# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.SearchTest do
  @moduledoc """
  Searching a view (ALT-F6) and the file (Show View), and ALT-F8 (R37), as
  Agenda 2.0 does (checked 2026-10-26; the owner's choice): ENTER on
  Search for takes the text and a second ENTER searches; a forward search
  starts after the highlighted item; search mode is quiet, its key bar F1
  Help alone and the File line without the time; past the last match ALT-N
  only beeps; no match is Agenda's Error box.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.TUI.{Layout, State, Update}

  setup do
    %{state: start(Agendum.Sample.build(~D[2026-10-08]))}
  end

  defp current(state), do: Layout.current_row(state).item.text
  defp line(state, n), do: state |> screen() |> String.split("\n") |> Enum.at(n)

  test "ENTER takes the text, a second ENTER searches", %{state: state} do
    state = press(state, [{:alt_f, 6}])
    assert screen(state) =~ "Search"

    state = press(state, ["abigail", :enter])
    assert %{type: :search_box} = State.mode(state)
    assert screen(state) =~ ~r/Search for: +abigail/

    state = press(state, :enter)
    assert %{type: :searching} = State.mode(state)
    assert current(state) =~ "Call Marketing"
  end

  test "search mode is quiet: no message, no time, F1 Help alone", %{state: state} do
    state = press(state, [{:alt_f, 6}, "abigail", :enter, :enter])
    refute screen(state) =~ "Match 1 of 2"
    assert line(state, 0) =~ ~r/ 10\/08\/26 *$/
    assert slots(state) == "F1 Help"
  end

  test "a forward search starts after the highlighted item", %{state: state} do
    state = press(state, [{:alt_f, 6}, "abigail", :enter, :enter, :enter])
    assert current(state) =~ "Call Marketing"

    state = press(state, [{:alt_f, 6}, :enter])
    assert current(state) =~ "Check with Abigail"
  end

  test "ALT-N and ALT-P move between matches; past the last, a beep", %{state: state} do
    state = press(state, [{:alt_f, 6}, "abigail", :enter, :enter, {:alt, "n"}])
    assert current(state) =~ "Check with Abigail"

    {last, effects} = Update.handle(state, {:alt, "n"})
    assert current(last) =~ "Check with Abigail"
    assert {:sound, :error} in effects
    refute panel(last) =~ message(:no_more_matches)

    state = press(state, {:alt, "p"})
    assert current(state) =~ "Call Marketing"
  end

  test "F7 marks the highlighted match; ENTER ends the search", %{state: state} do
    state = press(state, [{:alt_f, 6}, "abigail", :enter, :enter, {:f, 7}, :enter])
    assert state.modes == []
    assert Layout.current_row(state).item.marked
    refute panel(state) =~ "Search ended"
  end

  test "no match is Agenda's Error box; any key closes it", %{state: state} do
    state = press(state, [{:alt_f, 6}, "zebra", :enter, :enter])
    assert screen(state) =~ "Error"
    assert screen(state) =~ message(:no_matches)
    assert screen(state) =~ "Press any key to continue"

    assert press(state, " ").modes == []
  end

  test "searching notes and matching case are settings", %{state: state} do
    [first | _] = state.db.item_order
    state = %{state | db: Core.set_note(state.db, first, "bring the Budget", state.today)}

    # Match on: Item text -> Note text
    state = press(state, [{:alt_f, 6}, "budget", :enter, :down, " ", :enter])
    assert Layout.current_row(state).item.id == first

    # Ignore case: Yes -> No; "budget" no longer matches "Budget"
    state =
      press(state, [:esc, :home, {:alt_f, 6}, :down, :down, :down, " ", :enter])

    assert screen(state) =~ message(:no_matches)
  end

  test "the last search is offered again", %{state: state} do
    state = press(state, [{:alt_f, 6}, "abigail", :enter, :enter, :esc, {:alt_f, 6}])
    assert screen(state) =~ "abigail"
  end

  test "Show Match shows every match in the Show View; ALT-F8 returns", %{state: state} do
    state = press(state, [{:f, 10}, "u", "s", "m", "Abigail", :enter, :enter])
    assert State.view(state).name == "*Show View*"
    assert Enum.count(Layout.rows(state), &(&1.kind == :item)) == 2

    state = press(state, {:alt_f, 8})
    assert State.view(state).name == "Activities"
    assert State.view(press(state, {:alt_f, 8})).name == "*Show View*"
  end
end
