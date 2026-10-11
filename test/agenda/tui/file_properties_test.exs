defmodule Agenda.TUI.FilePropertiesTest do
  @moduledoc "File ▸ Properties: the date display format (R41) and date settings (R14e)."
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.TUI.{History, State}

  setup do
    %{state: start(Agenda.Sample.build(~D[2026-10-08]))}
  end

  test "File Properties opens the box with a formatted sample", %{state: state} do
    state = press(state, [{:f, 10}, "f", "p"])
    assert %{type: :file_props} = State.mode(state)
    text = screen(state)
    assert text =~ "File properties"
    assert text =~ ~r/Date format +: YYYYMMDD/
    assert text =~ ~r/Date separator +: -/
    assert text =~ ~r/Clock +: 24 hr/
    assert text =~ ~r/Show day of week +: No/
    assert text =~ ~r/Display date\/time +: Date time/
    assert text =~ ~r/Show am\/pm +: Yes/
    assert text =~ ~r/Time separator +: :/
    assert text =~ ~r/Sample +: 1990-11-13 15:25/
  end

  test "changing a setting changes every date on the screen at once", %{state: state} do
    # Date format: YYYYMMDD -> YYMMDD; then the separator - -> .
    state = press(state, [{:f, 10}, "f", "p", :down, :down, " ", :down, " "])
    assert state.db.date_format.order == :yymmdd
    assert state.db.date_format.separator == "."
    assert screen(state) =~ ~r/Sample +: 90\.11\.13 15:25/

    state = press(state, :esc)
    assert state.modes == []
    text = screen(state)
    assert text =~ "26.10.31"
    assert text =~ "26.10.08 09:00"
  end

  test "← goes back through the choices; the clock and day of week toggle", %{state: state} do
    keys = [
      :down,
      " ",
      :down,
      :left,
      :left,
      :left,
      :left,
      :left,
      :left,
      :left,
      :down,
      :down,
      :right
    ]

    state = press(state, [{:f, 10}, "f", "p"] ++ keys)
    f = state.db.date_format
    assert f.order == :ddmmmyyyy
    assert f.clock == 12
    assert f.day_of_week
    assert screen(state) =~ ~r/Sample +: Tue 13 Nov 1990 3:25pm/
  end

  test "Agenda's other display settings and formats", %{state: state} do
    # Display date/time -> Date only; Date format back to Relative; am/pm off
    state = press(state, [{:f, 10}, "f", "p", " ", :down, :down, :left, :left])
    assert state.db.date_format.show == :date
    assert state.db.date_format.order == :relative
    assert screen(state) =~ ~r/Date format +: Relative/
    assert screen(state) =~ ~r/Sample +: Tomorrow/

    state = press(state, [:down, :down, :right, :down, " ", :down, " "])
    f = state.db.date_format
    assert {f.clock, f.am_pm, f.time_separator} == {12, false, "hm"}
  end

  test "each change is one undo step", %{state: state} do
    state = press(state, [{:f, 10}, "f", "p", :down, :down, " ", " ", :esc])
    assert state.db.date_format.order == :yyyyddmm
    state = History.undo(state)
    assert state.db.date_format.order == :yymmdd
  end

  test "the date settings are rows of the box too", %{state: state} do
    state = press(state, [{:f, 10}, "f", "p"])
    text = screen(state)
    assert text =~ ~r/Beginning of week +: Mon/
    assert text =~ ~r/End of week +: Fri/
    assert text =~ ~r/First quarter +: Jan 1/
    assert text =~ ~r/Beginning of year +: Jan 1/
    assert text =~ ~r/Month alone means +: First day/
    assert text =~ ~r/Morning +: 08:00/
    assert text =~ ~r/Afternoon +: 14:00/
    assert text =~ ~r/Evening +: 17:00/
  end

  test "changing a date setting changes how dates are read", %{state: state} do
    # down to Month alone means, then First day -> Last day
    state = press(state, [{:f, 10}, "f", "p"] ++ List.duplicate(:down, 12) ++ [" "])
    assert state.db.date_settings.month_alone == :last
    assert screen(state) =~ ~r/Month alone means +: Last day/

    state = press(state, [:down, :left])
    assert state.db.date_settings.morning == ~T[07:30:00]

    state = History.undo(state)
    assert state.db.date_settings.morning == ~T[08:00:00]
  end
end
