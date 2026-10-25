defmodule Agendum.TUI.FilePropertiesTest do
  @moduledoc """
  File ▸ Properties: where new columns go (R55), the date display format
  (R41) and date settings (R14e).
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.TUI.{History, State}

  setup do
    %{state: start(Agendum.Sample.build(~D[2026-10-08]))}
  end

  # File Properties ▸ Global date settings (below Insert new columns in) ▸
  # Display format, as in Agenda
  @dates [{:f, 10}, "f", "p", :down, :down, " "]
  @display @dates ++ [" "]

  test "File Properties opens Agenda's boxes, one inside the other", %{state: state} do
    state = press(state, [{:f, 10}, "f", "p"])
    assert %{type: :file_props} = State.mode(state)
    assert screen(state) =~ ~r/Global date settings: +\.\.\./
    assert screen(state) =~ ~r/Auto-assign settings: +\.\.\./

    state = state |> to_setting("Global date settings") |> press(" ")
    assert %{type: :date_settings} = State.mode(state)
    assert screen(state) =~ ~r/Display format +: \.\.\./

    state = press(state, " ")
    assert %{type: :display_format} = State.mode(state)
    # ESC goes back one box at a time, then through the menu
    assert %{type: :date_settings} = state |> press(:esc) |> State.mode()
    assert %{type: :menu} = state |> press([:esc, :esc, :esc]) |> State.mode()
    assert state |> press([:esc, :esc, :esc, :esc, :esc]) |> Map.get(:modes) == []
  end

  test "File statistics shows how big the file is, as Agenda's", %{state: state} do
    state = press(state, [{:f, 10}, "f", "p"]) |> to_setting("File statistics")
    assert screen(state) =~ ~r/File statistics: +\.\.\./
    state = press(state, " ")
    assert %{type: :file_stats} = State.mode(state)

    stats = Agendum.Core.Database.file_statistics(state.db)
    text = screen(state)
    assert text =~ ~r/Items: +#{stats.items}\b/
    assert text =~ ~r/Items with notes: +#{stats.items_with_notes}\b/
    assert text =~ ~r/Categories: +#{stats.categories}\b/
    assert text =~ ~r/Average items\/category: +#{stats.items_per_category}\b/
    assert text =~ ~r/Average categories\/item: +#{stats.categories_per_item}\b/
    assert stats.items > 0

    # nothing to change: any key goes back to File Properties, as Agenda's
    # "Press any key to continue" (checked in Agenda 2.0, 2026-10-25)
    assert text =~ "Press any key to continue"

    for key <- [" ", "x", :enter, :esc, :down] do
      after_key = press(state, key)
      assert %{type: :file_props} = State.mode(after_key)
      assert after_key.db == state.db
    end
  end

  test "every box fits a 25-line screen, with its frame", %{state: state} do
    state = %{state | height: 25, width: 80}

    # each box's last row, and the bottom of its frame below it
    for {keys, last} <- [
          {[], "Auto-assign"},
          {[:down, :down, " "], "Evening"},
          {[:down, :down, " ", " "], "Sample"}
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
      {:ok, db, _} = Agendum.Core.add_category(state.db, state.db.main_id, "Ideas")
      {:ok, db, _} = Agendum.Core.add_category(db, db.main_id, "Mood")
      [view] = Agendum.Core.Database.views(db)
      db = Agendum.Core.add_section(db, view.id, Agendum.Fixtures.cat(db, "Ideas"), 1)

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
        |> Agendum.Core.View.columns(sidx)
        |> Enum.map(&state.db.categories[&1.category_id].name)
      end

      assert "Mood" in heads.(0)
      refute "Mood" in heads.(1)
    end
  end

  # drawn as Agenda's, like a date column's part (checked in Agenda 2.0,
  # 2026-10-25): two columns, the sample centred below
  test "Display format shows the settings with a formatted sample", %{state: state} do
    state = press(state, @display)
    assert %{type: :display_format} = State.mode(state)
    text = screen(state)
    assert text =~ "Display Format"
    assert text =~ "Date Column Properties"
    assert text =~ ~r/Display date and\/or time: +Date time/
    assert text =~ ~r/Show day of week: +No +Clock: +24 hr/
    assert text =~ ~r/Date format: +YYYYMMDD +Show am\/pm: +Yes/
    assert text =~ ~r/Date separator: +- +Time separator: +:/
    assert text =~ "Formatted Sample"
    assert text =~ "1990-11-13 15:25"
  end

  test "changing a setting changes every date on the screen at once", %{state: state} do
    # Date format: YYYYMMDD -> YYMMDD; then the separator - -> .
    state =
      state
      |> press(@display)
      |> to_setting("Date format")
      |> press(" ")
      |> to_setting("Date separator")
      |> press(" ")

    assert state.db.date_format.order == :yymmdd
    assert state.db.date_format.separator == "."
    assert screen(state) =~ "90.11.13 15:25"

    state = press(state, [:enter, :enter, :enter])
    assert state.modes == []
    text = screen(state)
    assert text =~ "26.10.31"
    assert text =~ "26.10.08 09:00"
  end

  test "SPACE goes on through the choices; the clock and day of week toggle", %{state: state} do
    # Show day of week; Date format on to DDMMMYYYY; Clock
    state =
      state
      |> press(@display)
      |> to_setting("Show day of week")
      |> press(" ")
      |> to_setting("Date format")
      |> press(List.duplicate(" ", 13))
      |> to_setting("Clock")
      |> press(" ")

    f = state.db.date_format
    assert f.order == :ddmmmyyyy
    assert f.clock == 12
    assert f.day_of_week
    assert screen(state) =~ "Tue 13 Nov 1990 3:25pm"
  end

  test "Agenda's other display settings and formats", %{state: state} do
    # Display date/time -> Date only (no clock settings then); Date format
    # on to Relative
    state = press(state, @display ++ [" "])
    assert state.db.date_format.show == :date
    refute screen(state) =~ "Clock:"
    state = state |> to_setting("Date format") |> press(List.duplicate(" ", 18))
    assert state.db.date_format.order == :relative
    assert screen(state) =~ ~r/Date format: +Relative/
    assert screen(state) =~ "Tomorrow"

    # back to Date time (Time date, Time only, Date time); the clock settings
    state = state |> to_setting("Display date and/or time") |> press([" ", " ", " "])
    assert state.db.date_format.show == :date_time

    state =
      Enum.reduce(["Clock", "Show am/pm", "Time separator"], state, fn label, state ->
        state |> to_setting(label) |> press(" ")
      end)

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
    # Month alone means: First day -> Last day
    state = state |> press(@dates) |> to_setting("Month alone means") |> press(" ")
    assert state.db.date_settings.month_alone == :last
    assert screen(state) =~ ~r/Month alone means +: Last day/

    # Morning is typed (SPACE asks for it)
    state = state |> to_setting("Morning") |> press([" ", {:ctrl, "u"}, "7:30am", :enter])
    assert state.db.date_settings.morning == ~T[07:30:00]

    state = History.undo(state)
    assert state.db.date_settings.morning == ~T[08:00:00]
  end
end
