# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.MonthCalendarTest do
  @moduledoc "The pop-up calendar's month and its moves (R46)."
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.MonthCalendar

  describe "a month as weeks" do
    test "weeks start on the given day; days before and after the month are nil" do
      # 1 October 2026 is a Thursday
      [first | _] = weeks = MonthCalendar.weeks(~D[2026-10-12], 1)

      assert first == [
               nil,
               nil,
               nil,
               ~D[2026-10-01],
               ~D[2026-10-02],
               ~D[2026-10-03],
               ~D[2026-10-04]
             ]

      assert length(weeks) == 6
      assert Enum.all?(weeks, &(length(&1) == 7))
      assert weeks |> List.flatten() |> Enum.reject(&is_nil/1) |> length() == 31

      # Agenda's own screen started on Sunday
      [first | _] = MonthCalendar.weeks(~D[2026-10-12], 7)
      assert first == [nil, nil, nil, nil, ~D[2026-10-01], ~D[2026-10-02], ~D[2026-10-03]]
    end

    test "always six weeks, so the calendar keeps its size" do
      # February 2027 starts on a Monday and fits in four weeks
      weeks = MonthCalendar.weeks(~D[2027-02-10], 1)
      assert length(weeks) == 6
      assert hd(hd(weeks)) == ~D[2027-02-01]
    end
  end

  describe "moving the highlight" do
    test "by days and weeks" do
      assert MonthCalendar.move(~D[2026-10-31], :day, 1) == ~D[2026-11-01]
      assert MonthCalendar.move(~D[2026-10-01], :week, -1) == ~D[2026-09-24]
    end

    test "to the first and last day of the month" do
      assert MonthCalendar.move(~D[2026-02-14], :first, 0) == ~D[2026-02-01]
      assert MonthCalendar.move(~D[2028-02-14], :last, 0) == ~D[2028-02-29]
    end

    test "by months and years keep the day where the month has it" do
      assert MonthCalendar.move(~D[2026-10-12], :month, -1) == ~D[2026-09-12]
      assert MonthCalendar.move(~D[2026-01-31], :month, 1) == ~D[2026-02-28]
      assert MonthCalendar.move(~D[2028-02-29], :year, 1) == ~D[2029-02-28]
    end

    test "stays within Agenda's calendar, 1 AD to 5000" do
      assert MonthCalendar.move(~D[0001-01-03], :week, -1) == ~D[0001-01-01]
      assert MonthCalendar.move(~D[5000-12-30], :year, 1) == ~D[5000-12-31]
    end
  end

  test "a typed date or time is read as in a date column" do
    db = Core.new_file()
    now = ~N[2026-10-12 10:15:00]
    assert Core.read_when(db, "friday 3pm", now) == {:ok, ~D[2026-10-16], ~T[15:00:00]}
    assert Core.read_when(db, "2026-12-24", now) == {:ok, ~D[2026-12-24], nil}
    assert Core.read_when(db, "no date here", now) == :error
  end
end
