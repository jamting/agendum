defmodule Agenda.TUI.ScheduleBoxTest do
  @moduledoc "Search ▸ Schedule (R49): the Show Schedule box and the Show View it fills."
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.TUI.State

  # Monday 12 October 2026; "Call Marketing … this Tuesday" is on the 13th
  setup do
    state = start(Agenda.Sample.build(~D[2026-10-12]), today: ~D[2026-10-12])
    %{state: %{state | now: ~N[2026-10-12 10:00:00]}}
  end

  defp open_box(state), do: press(state, [{:f, 10}, "s", "s"])

  defp items(state),
    do: state |> screen() |> String.split("\n") |> Enum.filter(&String.starts_with?(&1, " • "))

  test "the box shows Agenda's defaults: When, today, no filter", %{state: state} do
    state = open_box(state)
    assert %{type: :schedule} = State.mode(state)
    text = screen(state)
    assert text =~ "Show Schedule"
    assert text =~ ~r/Date category +: When/
    assert text =~ ~r/Section head +: When/
    assert text =~ ~r/Date +: Mon 2026-10-12/
    assert text =~ ~r/Filter +: \(none\)/
  end

  test "ENTER shows the date's items in the Show View", %{state: state} do
    state = state |> open_box() |> press([:down, :down, " ", {:ctrl, "u"}, "tuesday", :enter])
    assert screen(state) =~ ~r/Date +: Tue 2026-10-13/

    state = press(state, :enter)
    assert State.view(state).name == "Show View"
    assert [item] = items(state)
    assert item =~ "Call Marketing"
    assert panel(state) =~ "Schedule for Tue 2026-10-13"

    # at 80 columns the message leaves the view's line in sight
    [_, view_line | _] = %{state | width: 80} |> screen() |> String.split("\n")
    assert view_line =~ "View: Show View"
  end

  test "F3 picks the date from the pop-up calendar", %{state: state} do
    state = state |> open_box() |> press([:down, :down, {:f, 3}])
    assert %{type: :calendar} = State.mode(state)
    state = press(state, [:right, :enter])
    assert %{type: :schedule, date: ~D[2026-10-13]} = State.mode(state)
  end

  test "a filter narrows it; the date category must be a date category", %{state: start} do
    tuesday = start |> open_box() |> press([:down, :down, " ", {:ctrl, "u"}, "tuesday", :enter])

    # Filter: Low (Call Marketing is Low), then not Low; in the list the
    # first ESC clears the search typed there, the second closes it
    low = press(tuesday, [:down, " ", "Low", :enter, :esc, :esc])
    assert screen(low) =~ ~r/Filter +: Low/
    assert low |> press(:enter) |> items() |> length() == 1

    not_low = press(tuesday, [:down, " ", "Low", :enter, :enter, :esc, :esc])
    assert screen(not_low) =~ ~r/Filter +: -Low/
    assert not_low |> press(:enter) |> items() == []

    picked = start |> open_box() |> press([" ", "Calls", :enter])
    assert screen(picked) =~ "Pick a date category"
  end

  test "the Show View can then be browsed to other days", %{state: state} do
    state = state |> open_box() |> press(:enter)
    assert items(state) == []
    state = press(state, [{:alt, "b"}, :right])
    assert [item] = items(state)
    assert item =~ "Call Marketing"
  end
end
