defmodule Agenda.Core.DateSettingsTest do
  @moduledoc """
  Global date settings (R14e; User's Guide 7-15 to 7-16): the beginning
  and end of the week, the first quarter, the beginning of the year, what
  a month alone means and the times of morning, afternoon and evening.
  """
  use ExUnit.Case, async: true

  alias Agenda.Core
  alias Agenda.Core.{DateParser, DateSettings}
  alias Agenda.Core.DateLanguage.Swedish

  # A Thursday
  @today ~D[2026-10-08]
  @now ~N[2026-10-08 10:00:00]

  defp day(text, settings, today \\ @today),
    do: DateParser.parse(text, today, settings: settings)

  defp check(cases, settings) do
    for {text, expected} <- cases, do: assert(day(text, settings) == {:ok, expected}, text)
  end

  test "the defaults are Agenda's" do
    s = %DateSettings{}
    assert {s.week_start, s.week_end, s.quarter_start, s.year_start} == {1, 5, 1, 1}
    assert s.month_alone == :first
    assert {s.morning, s.afternoon, s.evening} == {~T[08:00:00], ~T[14:00:00], ~T[17:00:00]}
  end

  test "a week from Sunday to Thursday" do
    check(
      [
        {"this week", ~D[2026-10-04]},
        {"next week", ~D[2026-10-11]},
        {"end of week", ~D[2026-10-08]},
        {"end of next week", ~D[2026-10-15]},
        {"this Monday", ~D[2026-10-05]},
        {"next Sunday", ~D[2026-10-11]},
        # working days are the days of that week
        {"in 2 working days", ~D[2026-10-12]}
      ],
      %DateSettings{week_start: 7, week_end: 4}
    )
  end

  test "quarters starting in February" do
    check(
      [
        {"this quarter", ~D[2026-08-01]},
        {"next quarter", ~D[2026-11-01]},
        {"end of the quarter", ~D[2026-10-31]},
        {"first quarter", ~D[2027-02-01]},
        {"fourth quarter", ~D[2026-11-01]}
      ],
      %DateSettings{quarter_start: 2}
    )
  end

  test "a year starting in April" do
    settings = %DateSettings{year_start: 4}

    check(
      [
        {"this year", ~D[2026-04-01]},
        {"end of the year", ~D[2027-03-31]},
        {"next year", ~D[2027-04-01]}
      ],
      settings
    )

    assert day("this year", settings, ~D[2026-02-10]) == {:ok, ~D[2025-04-01]}
  end

  test "a month alone can mean its last day or a given day" do
    check([{"next April", ~D[2027-04-30]}, {"February", ~D[2027-02-28]}], %DateSettings{
      month_alone: :last
    })

    check([{"next April", ~D[2027-04-15]}, {"February", ~D[2027-02-15]}], %DateSettings{
      month_alone: 15
    })

    # a day the month does not have means its last day
    check([{"February", ~D[2027-02-28]}], %DateSettings{month_alone: 31})
  end

  test "morning, afternoon and evening" do
    settings = %DateSettings{
      morning: ~T[10:00:00],
      afternoon: ~T[15:00:00],
      evening: ~T[21:00:00]
    }

    when_ = &DateParser.parse_when(&1, @now, settings: settings)

    assert when_.("tomorrow morning") == {:ok, ~D[2026-10-09], ~T[10:00:00]}
    assert when_.("friday afternoon") == {:ok, ~D[2026-10-09], ~T[15:00:00]}
    assert when_.("tonight") == {:ok, @today, ~T[21:00:00]}

    sv = [settings: settings, languages: [Swedish]]
    assert DateParser.parse_when("i kväll", @now, sv) == {:ok, @today, ~T[21:00:00]}
  end

  test "Morning also sets which hours without am/pm are morning" do
    at_eight = &DateParser.parse_when("at 8:00", @now, settings: &1)
    assert at_eight.(%DateSettings{}) == {:ok, @today, ~T[08:00:00]}
    assert at_eight.(%DateSettings{morning: ~T[09:00:00]}) == {:ok, @today, ~T[20:00:00]}

    # 12 o'clock has no later twelve-hour twin
    late = [settings: %DateSettings{morning: ~T[13:00:00]}]
    assert DateParser.parse_when("at 12:30", @now, late) == {:ok, @today, ~T[12:30:00]}
  end

  test "the file's settings apply to items" do
    db = Core.new_file()
    db = Core.set_date_settings(db, %DateSettings{evening: ~T[21:00:00], month_alone: :last})

    {db, id} = Core.add_item(db, "Call Bob tonight", @now)
    assert {db.items[id].when, db.items[id].when_time} == {@today, ~T[21:00:00]}

    {db, id} = Core.add_item(db, "Conference next April", @now)
    assert db.items[id].when == ~D[2027-04-30]
  end

  describe "cycle/3, as File Properties changes them" do
    test "weekdays and months go round" do
      s = %DateSettings{}
      assert DateSettings.cycle(s, :week_start, -1).week_start == 7
      assert DateSettings.cycle(s, :week_end, 1).week_end == 6
      assert DateSettings.cycle(s, :year_start, -1).year_start == 12
    end

    test "month alone: first day, last day, then day 2 to 31" do
      s = %DateSettings{}
      assert DateSettings.cycle(s, :month_alone, 1).month_alone == :last
      assert DateSettings.cycle(%{s | month_alone: :last}, :month_alone, 1).month_alone == 2
      assert DateSettings.cycle(%{s | month_alone: 31}, :month_alone, 1).month_alone == :first
      assert DateSettings.cycle(s, :month_alone, -1).month_alone == 31
    end

    test "times move by half an hour" do
      s = %DateSettings{}
      assert DateSettings.cycle(s, :morning, 1).morning == ~T[08:30:00]
      assert DateSettings.cycle(s, :evening, -1).evening == ~T[16:30:00]
      assert DateSettings.cycle(%{s | evening: ~T[23:30:00]}, :evening, 1).evening == ~T[00:00:00]
    end
  end
end
