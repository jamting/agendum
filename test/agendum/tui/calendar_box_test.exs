defmodule Agendum.TUI.CalendarBoxTest do
  @moduledoc """
  The pop-up calendar (R46; User's Guide 6-14 to 6-17): F3 in a date column
  picks a date, ALT-C shows the month for reference.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core.Database
  alias Agendum.TUI.{History, Layout, State}

  setup do
    state = start(Agendum.Sample.build(~D[2026-10-08]), width: 80, height: 25)
    state = %{state | now: ~N[2026-10-08 09:00:00], today: ~D[2026-10-08]}
    # the first item, "Set up meeting …", has When 2026-10-31; column 1 is When
    %{state: press(state, [:down, :right]), when: state.db.special.when}
  end

  defp item(state), do: Layout.current_row(state).item
  defp mode(state), do: State.mode(state)

  test "F3 in a date column opens the month of the entry's date, highlighted", %{state: state} do
    state = press(state, {:f, 3})
    assert %{type: :calendar, date: ~D[2026-10-31]} = mode(state)
    text = screen(state)
    assert text =~ "October 2026"
    assert text =~ ~r/Mon Tue Wed Thu Fri Sat Sun/
    assert text =~ ~r/26  27  28  29  30  31/
  end

  test "an empty entry starts on today", %{state: state} do
    state = press(state, [:down, {:f, 3}])
    assert item(state).when == nil
    assert %{type: :calendar, date: ~D[2026-10-08]} = mode(state)
  end

  test "the keys move by day, week, month and year, and to the month's ends", %{state: state} do
    state = press(state, {:f, 3})
    date = fn keys -> state |> press(keys) |> mode() |> Map.fetch!(:date) end

    assert date.(:right) == ~D[2026-11-01]
    assert date.(:up) == ~D[2026-10-24]
    assert date.(:pgdn) == ~D[2026-11-30]
    assert date.(:pgup) == ~D[2026-09-30]
    assert date.(:ctrl_right) == ~D[2027-10-31]
    assert date.(">") == ~D[2027-10-31]
    assert date.("<") == ~D[2025-10-31]
    assert date.(:home) == ~D[2026-10-01]
    assert date.([:home, :end]) == ~D[2026-10-31]
  end

  test "ENTER sets the date in the column; one undo takes it back", %{state: state} do
    state = press(state, [{:f, 3}, :left, :left, :enter])
    assert state.modes == []
    assert item(state).when == ~D[2026-10-29]
    assert screen(state) =~ "2026-10-29"
    assert History.undo(state) |> item() |> Map.get(:when) == ~D[2026-10-31]
  end

  test "ESC leaves the date as it was", %{state: state} do
    state = press(state, [{:f, 3}, :right, :esc])
    assert state.modes == []
    assert item(state).when == ~D[2026-10-31]
  end

  test "F6 sets a time to go with the date", %{state: state} do
    state = press(state, [{:f, 3}, {:f, 6}, "3pm", :enter])
    assert %{type: :calendar, time: ~T[15:00:00]} = mode(state)
    assert screen(state) =~ "Time: 15:00"

    state = press(state, :enter)
    assert {item(state).when, item(state).when_time} == {~D[2026-10-31], ~T[15:00:00]}
  end

  test "typing a date jumps there", %{state: state} do
    state = press(state, [{:f, 3}, "zebra", :enter])
    assert State.mode(state).type == :calendar
    assert panel(state) =~ message(:bad_date)

    state = press(state, ["2027-03-15", :enter])
    assert %{type: :calendar, date: ~D[2027-03-15]} = mode(state)
    assert screen(state) =~ "March 2027"
  end

  test "it works for a date category of the user's own", %{state: state} do
    {:ok, db, due} = Agendum.Core.add_category(state.db, state.db.main_id, "Due")
    {:ok, db} = Agendum.Core.make_date(db, due, ~D[2026-10-08])
    db = Agendum.Core.add_column(db, state.view_id, due, {0, 0}, 12)
    state = Layout.settle(%{state | db: db})

    state = press(state, [{:f, 3}, :right, :enter])
    assert Database.item_date(state.db, item(state).id, due) == ~D[2026-10-09]
  end

  test "ALT-C shows this month anywhere, and changes nothing", %{state: state} do
    state = press(state, [:left, {:alt, "c"}])
    assert %{type: :calendar, date: ~D[2026-10-08], target: nil} = mode(state)
    db = state.db
    state = press(state, [:right, :enter])
    assert state.modes == []
    assert state.db == db
  end
end
