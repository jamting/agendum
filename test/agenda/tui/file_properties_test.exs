defmodule Agenda.TUI.FilePropertiesTest do
  @moduledoc """
  File ▸ Properties: where new columns go (R55), the date display format
  (R41) and date settings (R14e).
  """
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.TUI.{History, State}

  setup do
    %{state: start(Agenda.Sample.build(~D[2026-10-08]))}
  end

  # File Properties ▸ Global date settings (below Insert new columns in) ▸
  # Display format, as in Agenda
  @dates [{:f, 10}, "f", "p", :down, " "]
  @display @dates ++ [" "]

  test "File Properties opens Agenda's boxes, one inside the other", %{state: state} do
    state = press(state, [{:f, 10}, "f", "p"])
    assert %{type: :file_props} = State.mode(state)
    assert screen(state) =~ ~r/Global date settings: +\.\.\./
    assert screen(state) =~ ~r/Auto-assign settings: +\.\.\./

    state = press(state, [:down, " "])
    assert %{type: :date_settings} = State.mode(state)
    assert screen(state) =~ ~r/Display format +: \.\.\./

    state = press(state, " ")
    assert %{type: :display_format} = State.mode(state)
    # ESC goes back one box at a time, then through the menu
    assert %{type: :date_settings} = state |> press(:esc) |> State.mode()
    assert %{type: :menu} = state |> press([:esc, :esc, :esc]) |> State.mode()
    assert state |> press([:esc, :esc, :esc, :esc, :esc]) |> Map.get(:modes) == []
  end

  test "every box fits a 25-line screen, with its frame", %{state: state} do
    state = %{state | height: 25, width: 80}

    # each box's last row, and the bottom of its frame below it
    for {keys, last} <- [
          {[], "Auto-assign"},
          {[:down, " "], "Evening"},
          {[:down, " ", " "], "Sample"}
        ] do
      lines = state |> press([{:f, 10}, "f", "p"] ++ keys) |> screen() |> String.split("\n")
      row = Enum.find_index(lines, &String.contains?(&1, last))
      assert row, "#{last} is not on the screen"
      assert Enum.any?(Enum.drop(lines, row + 1), &String.contains?(&1, "└"))
    end
  end

  describe "Insert new columns in (R55)" do
    test "is the first row, All sections in a new file", %{state: state} do
      state = press(state, [{:f, 10}, "f", "p"])
      assert screen(state) =~ ~r/Insert new columns in: +All sections/
    end

    test "SPACE makes it Current section, as one undo step", %{state: state} do
      state = press(state, [{:f, 10}, "f", "p", " "])
      assert state.db.insert_columns == :section
      assert screen(state) =~ ~r/Insert new columns in: +Current section/
      assert History.undo(state).db.insert_columns == :all
    end

    test "then ALT-R adds a column to the current section only", %{state: state} do
      {:ok, db, _} = Agenda.Core.add_category(state.db, state.db.main_id, "Ideas")
      {:ok, db, _} = Agenda.Core.add_category(db, db.main_id, "Mood")
      [view] = Agenda.Core.Database.views(db)
      db = Agenda.Core.add_section(db, view.id, Agenda.Fixtures.cat(db, "Ideas"), 1)

      state =
        press(%{state | db: db}, [
          {:f, 10},
          "f",
          "p",
          " ",
          :enter,
          :down,
          {:alt, "r"},
          "Mood",
          :enter
        ])

      heads = fn sidx ->
        state.db.views[view.id]
        |> Agenda.Core.View.columns(sidx)
        |> Enum.map(&state.db.categories[&1.category_id].name)
      end

      assert "Mood" in heads.(0)
      refute "Mood" in heads.(1)
    end
  end

  test "Display format shows the settings with a formatted sample", %{state: state} do
    state = press(state, @display)
    assert %{type: :display_format} = State.mode(state)
    text = screen(state)
    assert text =~ "Display format"
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
    state = press(state, @display ++ [:down, :down, " ", :down, " "])
    assert state.db.date_format.order == :yymmdd
    assert state.db.date_format.separator == "."
    assert screen(state) =~ ~r/Sample +: 90\.11\.13 15:25/

    state = press(state, [:enter, :enter, :enter])
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

    state = press(state, @display ++ keys)
    f = state.db.date_format
    assert f.order == :ddmmmyyyy
    assert f.clock == 12
    assert f.day_of_week
    assert screen(state) =~ ~r/Sample +: Tue 13 Nov 1990 3:25pm/
  end

  test "Agenda's other display settings and formats", %{state: state} do
    # Display date/time -> Date only; Date format back to Relative; am/pm off
    state = press(state, @display ++ [" ", :down, :down, :left, :left])
    assert state.db.date_format.show == :date
    assert state.db.date_format.order == :relative
    assert screen(state) =~ ~r/Date format +: Relative/
    assert screen(state) =~ ~r/Sample +: Tomorrow/

    state = press(state, [:down, :down, :right, :down, " ", :down, " "])
    f = state.db.date_format
    assert {f.clock, f.am_pm, f.time_separator} == {12, false, "hm"}
  end

  test "each change is one undo step", %{state: state} do
    state = press(state, @display ++ [:down, :down, " ", " ", :enter])
    assert state.db.date_format.order == :yyyyddmm
    state = History.undo(state)
    assert state.db.date_format.order == :yymmdd
  end

  test "the date settings are rows of Global date settings", %{state: state} do
    state = press(state, @dates)
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
    state = press(state, @dates ++ List.duplicate(:down, 6) ++ [" "])
    assert state.db.date_settings.month_alone == :last
    assert screen(state) =~ ~r/Month alone means +: Last day/

    state = press(state, [:down, :left])
    assert state.db.date_settings.morning == ~T[07:30:00]

    state = History.undo(state)
    assert state.db.date_settings.morning == ~T[08:00:00]
  end
end
