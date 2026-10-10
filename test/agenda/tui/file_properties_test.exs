defmodule Agenda.TUI.FilePropertiesTest do
  @moduledoc "File ▸ Properties: the date display format (R41)."
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
    assert text =~ "Sample: 1990-11-13 15:25"
  end

  test "changing a setting changes every date on the screen at once", %{state: state} do
    # Date format: YYYYMMDD -> YYMMDD; then the separator - -> .
    state = press(state, [{:f, 10}, "f", "p", " ", :down, " "])
    assert state.db.date_format.order == :yymmdd
    assert state.db.date_format.separator == "."
    assert screen(state) =~ "Sample: 90.11.13 15:25"

    state = press(state, :esc)
    assert state.modes == []
    text = screen(state)
    assert text =~ "26.10.31"
    assert text =~ "26.10.08 09:00"
  end

  test "← goes back through the choices; the clock and day of week toggle", %{state: state} do
    state = press(state, [{:f, 10}, "f", "p", :left, :down, :down, " ", :down, :right])
    f = state.db.date_format
    assert f.order == :ddmmmyyyy
    assert f.clock == 12
    assert f.day_of_week
    assert screen(state) =~ "Sample: Tue 13 Nov 1990 3:25pm"
  end

  test "each change is one undo step", %{state: state} do
    state = press(state, [{:f, 10}, "f", "p", " ", " ", :esc])
    assert state.db.date_format.order == :yyyyddmm
    state = History.undo(state)
    assert state.db.date_format.order == :yymmdd
  end
end
