defmodule Agendum.Core.ICal.TimeZoneTest do
  @moduledoc "Times in a calendar's own time zones (VTIMEZONE, RFC 5545 3.6.5), for R45."
  use ExUnit.Case, async: true

  alias Agendum.Core.ICal

  # America/New_York as Google and Apple write it: EDT from the second
  # Sunday of March, EST from the first Sunday of November
  @new_york """
  BEGIN:VTIMEZONE\r
  TZID:America/New_York\r
  BEGIN:DAYLIGHT\r
  TZOFFSETFROM:-0500\r
  TZOFFSETTO:-0400\r
  TZNAME:EDT\r
  DTSTART:20070311T020000\r
  RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU\r
  END:DAYLIGHT\r
  BEGIN:STANDARD\r
  TZOFFSETFROM:-0400\r
  TZOFFSETTO:-0500\r
  TZNAME:EST\r
  DTSTART:20071104T020000\r
  RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU\r
  END:STANDARD\r
  END:VTIMEZONE\r
  """

  # Australia/Sydney: summer time from October to April
  @sydney """
  BEGIN:VTIMEZONE
  TZID:Australia/Sydney
  BEGIN:STANDARD
  TZOFFSETFROM:+1100
  TZOFFSETTO:+1000
  DTSTART:20080406T030000
  RRULE:FREQ=YEARLY;BYMONTH=4;BYDAY=1SU
  END:STANDARD
  BEGIN:DAYLIGHT
  TZOFFSETFROM:+1000
  TZOFFSETTO:+1100
  DTSTART:20081005T020000
  RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=1SU
  END:DAYLIGHT
  END:VTIMEZONE
  """

  # Microsoft's names and its usual last-Sunday rules
  @stockholm """
  BEGIN:VTIMEZONE
  TZID:W. Europe Standard Time
  BEGIN:STANDARD
  DTSTART:16010101T030000
  TZOFFSETFROM:+0200
  TZOFFSETTO:+0100
  RRULE:FREQ=YEARLY;INTERVAL=1;BYDAY=-1SU;BYMONTH=10
  END:STANDARD
  BEGIN:DAYLIGHT
  DTSTART:16010101T020000
  TZOFFSETFROM:+0100
  TZOFFSETTO:+0200
  RRULE:FREQ=YEARLY;INTERVAL=1;BYDAY=-1SU;BYMONTH=3
  END:DAYLIGHT
  END:VTIMEZONE
  """

  @tokyo """
  BEGIN:VTIMEZONE
  TZID:Asia/Tokyo
  BEGIN:STANDARD
  TZOFFSETFROM:+0900
  TZOFFSETTO:+0900
  TZNAME:JST
  DTSTART:19700101T000000
  END:STANDARD
  END:VTIMEZONE
  """

  defp start(zone, tzid, at) do
    text =
      "BEGIN:VCALENDAR\nVERSION:2.0\n" <>
        zone <>
        "BEGIN:VEVENT\nUID:1\nDTSTART;TZID=#{tzid}:#{at}\nEND:VEVENT\nEND:VCALENDAR\n"

    assert {:ok, [event]} = ICal.parse(text)
    event.start
  end

  test "a time in a named zone becomes UTC by the calendar's own rules" do
    # winter: EST, five hours behind; summer: EDT, four
    assert start(@new_york, "America/New_York", "20261210T090000") ==
             {:utc, ~N[2026-12-10 14:00:00]}

    assert start(@new_york, "America/New_York", "20260716T090000") ==
             {:utc, ~N[2026-07-16 13:00:00]}
  end

  test "the change happens on the rule's day: the second Sunday of March 2026 is the 8th" do
    assert start(@new_york, "America/New_York", "20260307T120000") ==
             {:utc, ~N[2026-03-07 17:00:00]}

    assert start(@new_york, "America/New_York", "20260308T120000") ==
             {:utc, ~N[2026-03-08 16:00:00]}

    # and back on the first Sunday of November (1 November 2026)
    assert start(@new_york, "America/New_York", "20261031T120000") ==
             {:utc, ~N[2026-10-31 16:00:00]}

    assert start(@new_york, "America/New_York", "20261101T120000") ==
             {:utc, ~N[2026-11-01 17:00:00]}
  end

  test "a southern zone has its summer time over the new year" do
    assert start(@sydney, "Australia/Sydney", "20260115T100000") ==
             {:utc, ~N[2026-01-14 23:00:00]}

    assert start(@sydney, "Australia/Sydney", "20260615T100000") ==
             {:utc, ~N[2026-06-15 00:00:00]}
  end

  test "last-Sunday rules, and Microsoft's zone names" do
    # summer time in Sweden 2026: 29 March to 25 October
    assert start(@stockholm, "W. Europe Standard Time", "20261024T090000") ==
             {:utc, ~N[2026-10-24 07:00:00]}

    assert start(@stockholm, "W. Europe Standard Time", "20261026T090000") ==
             {:utc, ~N[2026-10-26 08:00:00]}

    assert start(@stockholm, "W. Europe Standard Time", "20260328T090000") ==
             {:utc, ~N[2026-03-28 08:00:00]}
  end

  test "a zone without daylight saving" do
    assert start(@tokyo, "Asia/Tokyo", "20261016T090000") == {:utc, ~N[2026-10-16 00:00:00]}
  end

  test "changes listed as dates (RDATE) instead of a rule" do
    zone = """
    BEGIN:VTIMEZONE
    TZID:Listed
    BEGIN:STANDARD
    TZOFFSETFROM:+0200
    TZOFFSETTO:+0100
    DTSTART:20251026T030000
    RDATE:20261025T030000
    END:STANDARD
    BEGIN:DAYLIGHT
    TZOFFSETFROM:+0100
    TZOFFSETTO:+0200
    DTSTART:20260329T020000
    END:DAYLIGHT
    END:VTIMEZONE
    """

    assert start(zone, "Listed", "20260201T120000") == {:utc, ~N[2026-02-01 11:00:00]}
    assert start(zone, "Listed", "20260601T120000") == {:utc, ~N[2026-06-01 10:00:00]}
    assert start(zone, "Listed", "20261201T120000") == {:utc, ~N[2026-12-01 11:00:00]}
  end

  test "the end is in its own zone too" do
    text =
      "BEGIN:VCALENDAR\n" <>
        @tokyo <>
        @new_york <>
        """
        BEGIN:VEVENT
        UID:call
        DTSTART;TZID=Asia/Tokyo:20261016T220000
        DTEND;TZID=America/New_York:20261016T100000
        END:VEVENT
        END:VCALENDAR
        """

    assert {:ok, [event]} = ICal.parse(text)
    assert event.start == {:utc, ~N[2026-10-16 13:00:00]}
    assert event.end == {:utc, ~N[2026-10-16 14:00:00]}
  end

  test "a zone the calendar does not define is taken as local time, as before" do
    assert start("", "Europe/Stockholm", "20261016T090000") ==
             {:local, ~N[2026-10-16 09:00:00]}

    assert start(@tokyo, "Europe/Stockholm", "20261016T090000") ==
             {:local, ~N[2026-10-16 09:00:00]}
  end

  test "a VTIMEZONE does not become an event, and an unreadable one is ignored" do
    broken =
      "BEGIN:VTIMEZONE\nTZID:Bad\nBEGIN:STANDARD\nTZOFFSETTO:soon\nEND:STANDARD\nEND:VTIMEZONE\n"

    assert start(broken, "Bad", "20261016T090000") == {:local, ~N[2026-10-16 09:00:00]}
  end
end
