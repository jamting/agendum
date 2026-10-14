defmodule Agendum.TUI.FilterBrowseTest do
  @moduledoc """
  Browsing a standard view's date filter, or a section's (R48; Help "Browse
  Through Dates"): the filter's dates move while browsing, ENTER keeps them.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.TUI.{History, Layout, State}

  # Monday 12 October 2026; the sample's items are dated around it
  setup do
    state = start(Agendum.Sample.build(~D[2026-10-12]), today: ~D[2026-10-12])
    state = %{state | now: ~N[2026-10-12 10:00:00]}
    when_id = state.db.special.when
    %{state: state, when: when_id}
  end

  defp filter_view(state, when_id, from, to) do
    {:ok, db} =
      Core.set_range_filter(
        state.db,
        state.view_id,
        :view,
        when_id,
        {:assigned, from, to, :inside},
        state.now
      )

    Layout.settle(%{state | db: db})
  end

  defp range(state, when_id), do: State.view(state).filter |> List.keyfind(when_id, 0) |> elem(1)

  test "← → move the view's date filter by days; ESC puts it back", %{state: state, when: w} do
    state = filter_view(state, w, "today", "today")
    db = state.db

    state = press(state, [{:alt, "b"}, :right, :right])
    assert screen(state) =~ "BROWSE"
    assert range(state, w) == {:range, "2026-10-14", "2026-10-14", :inside}
    assert screen(state) =~ "2026-10-14..2026-10-14"
    assert state.db == db

    state = press(state, :esc)
    assert range(state, w) == {:range, "today", "today", :inside}
  end

  test "weeks, months and years; ENTER keeps the dates, one undo step", %{state: state, when: w} do
    state = filter_view(state, w, "today", "end of this week")
    state = press(state, [{:alt, "b"}, :down, :pgdn, :ctrl_pgdn, :up])
    assert range(state, w) == {:range, "2027-11-12", "2027-11-16", :inside}

    state = press(state, :enter)
    assert state.modes == []
    assert range(state, w) == {:range, "2027-11-12", "2027-11-16", :inside}
    assert state |> History.undo() |> range(w) == {:range, "today", "end of this week", :inside}
  end

  test "ALT-F5 moves the range to start on a typed date", %{state: state, when: w} do
    state = filter_view(state, w, "today", "end of this week")
    state = press(state, [{:alt, "b"}, {:alt_f, 5}, "2026-12-21", :enter])
    assert range(state, w) == {:range, "2026-12-21", "2026-12-25", :inside}
  end

  test "a section with its own date filter is browsed on its own", %{state: state, when: w} do
    {:ok, db} =
      Core.set_range_filter(
        state.db,
        state.view_id,
        {:section, 0},
        w,
        {:assigned, "today", "today", :inside},
        state.now
      )

    state = Layout.settle(%{state | db: db})
    state = press(state, [{:alt, "b"}, :right, :enter])
    [section] = State.view(state).sections

    assert List.keyfind(section.filter, w, 0) ==
             {w, {:range, "2026-10-13", "2026-10-13", :inside}}

    assert State.view(state).filter == []
  end

  test "items move in and out of the view as the dates move", %{state: state, when: w} do
    # "Call Marketing … this Tuesday" is on the 13th
    state = filter_view(state, w, "today", "today")
    refute screen(state) =~ "Call Marketing"
    assert screen(press(state, [{:alt, "b"}, :right])) =~ "Call Marketing"
  end

  test "at 80 columns the view's line, with its dates, stays in sight", %{state: state, when: w} do
    state = %{filter_view(state, w, "today", "today") | width: 80}
    [_, view_line | _] = state |> press([{:alt, "b"}, :right]) |> screen() |> String.split("\n")
    assert view_line =~ "View: Activities [When 2026-10-13..2026-10-13]"

    {:ok, db, v} =
      Core.add_datebook_view(state.db, "Quarter", %Agendum.Core.Datebook{period: :quarter})

    datebook = %{state | db: db} |> State.switch_view(v) |> Layout.settle()
    [_, view_line | _] = datebook |> press({:alt, "b"}) |> screen() |> String.split("\n")
    assert view_line =~ "View: Quarter"
  end
end
