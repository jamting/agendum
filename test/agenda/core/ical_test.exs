defmodule Agenda.Core.ICalTest do
  @moduledoc "Reading iCalendar (RFC 5545) text: the events a calendar holds (R45)."
  use ExUnit.Case, async: true

  alias Agenda.Core.ICal
  alias Agenda.Core.ICal.Event

  defp calendar(events), do: "BEGIN:VCALENDAR\r\nVERSION:2.0\r\n" <> events <> "END:VCALENDAR\r\n"

  defp one(text) do
    assert {:ok, [event]} = ICal.parse(calendar(text))
    event
  end

  test "an event's title, description, start and id" do
    event =
      one("""
      BEGIN:VEVENT\r
      UID:abc-1@example.com\r
      SUMMARY:Organising Meeting\r
      DESCRIPTION:Bring the Notices\\, and a pencil.\\nRoom 2\r
      DTSTART:20261016T140000\r
      DTEND:20261016T150000\r
      END:VEVENT\r
      """)

    assert %Event{uid: "abc-1@example.com", summary: "Organising Meeting"} = event
    assert event.description == "Bring the Notices, and a pencil.\nRoom 2"
    assert event.start == {:local, ~N[2026-10-16 14:00:00]}
    assert event.rrule == nil
    assert event.status == nil
  end

  test "all-day events, UTC times and times in a named zone" do
    assert one("BEGIN:VEVENT\nUID:1\nDTSTART;VALUE=DATE:20261224\nEND:VEVENT\n").start ==
             {:date, ~D[2026-12-24]}

    assert one("BEGIN:VEVENT\nUID:2\nDTSTART:20261016T120000Z\nEND:VEVENT\n").start ==
             {:utc, ~N[2026-10-16 12:00:00]}

    assert one("BEGIN:VEVENT\nUID:3\nDTSTART;TZID=Europe/Stockholm:20261016T090000\nEND:VEVENT\n").start ==
             {:local, ~N[2026-10-16 09:00:00]}
  end

  test "the end: DTEND, or DTSTART plus DURATION; an all-day DTEND is the day after" do
    ev = fn lines -> one("BEGIN:VEVENT\nUID:1\n" <> lines <> "END:VEVENT\n") end

    assert ev.("DTSTART:20261016T140000\nDTEND:20261016T153000\n").end ==
             {:local, ~N[2026-10-16 15:30:00]}

    assert ev.("DTSTART:20261016T120000Z\nDTEND:20261016T130000Z\n").end ==
             {:utc, ~N[2026-10-16 13:00:00]}

    assert ev.("DTSTART;VALUE=DATE:20261224\nDTEND;VALUE=DATE:20261227\n").end ==
             {:date, ~D[2026-12-27]}

    assert ev.("DTSTART:20261016T140000\nDURATION:PT1H30M\n").end ==
             {:local, ~N[2026-10-16 15:30:00]}

    assert ev.("DTSTART;VALUE=DATE:20261224\nDURATION:P2D\n").end == {:date, ~D[2026-12-26]}
    assert ev.("DTSTART:20261016T140000\nDURATION:P1W\n").end == {:local, ~N[2026-10-23 14:00:00]}
    assert ev.("DTSTART:20261016T140000\n").end == nil
    # an end that cannot be read, or before the start, is none
    assert ev.("DTSTART:20261016T140000\nDURATION:soon\n").end == nil
    assert ev.("DTSTART:20261016T140000\nDTEND:20261015T100000\n").end == nil
  end

  test "folded lines are joined, and Unix line endings work" do
    event =
      one(
        "BEGIN:VEVENT\nUID:4\nSUMMARY:Count the lettuces before Tigger\n  bounces on them\nDTSTART:20261013\nEND:VEVENT\n"
      )

    assert event.summary == "Count the lettuces before Tigger bounces on them"
    assert event.start == {:date, ~D[2026-10-13]}
  end

  test "repeating events keep their rule" do
    event =
      one(
        "BEGIN:VEVENT\nUID:5\nSUMMARY:Weed\nDTSTART:20261012T080000\nRRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO;UNTIL=20271231T000000Z\nEND:VEVENT\n"
      )

    assert event.rrule == %{
             freq: :weekly,
             interval: 2,
             byday: ["MO"],
             bymonthday: [],
             count: nil,
             until: ~D[2027-12-31],
             other: []
           }

    rule =
      one(
        "BEGIN:VEVENT\nUID:6\nDTSTART:20261012\nRRULE:FREQ=MONTHLY;BYMONTHDAY=15;BYSETPOS=1\nEND:VEVENT\n"
      ).rrule

    assert rule.freq == :monthly
    assert rule.bymonthday == [15]
    assert rule.other == ["BYSETPOS"]
  end

  test "cancelled events say so; alarms inside events are skipped" do
    event =
      one(
        "BEGIN:VEVENT\nUID:7\nSUMMARY:Party\nSTATUS:CANCELLED\nDTSTART:20261020\nBEGIN:VALARM\nACTION:DISPLAY\nDESCRIPTION:Reminder\nEND:VALARM\nEND:VEVENT\n"
      )

    assert event.status == :cancelled
    assert event.description == nil
  end

  test "several events, in order; other components are ignored" do
    text =
      calendar(
        "BEGIN:VTIMEZONE\nTZID:Europe/Stockholm\nEND:VTIMEZONE\n" <>
          "BEGIN:VEVENT\nUID:a\nSUMMARY:One\nDTSTART:20261013\nEND:VEVENT\n" <>
          "BEGIN:VTODO\nUID:t\nSUMMARY:A task\nEND:VTODO\n" <>
          "BEGIN:VEVENT\nUID:b\nSUMMARY:Two\nDTSTART:20261014\nEND:VEVENT\n"
      )

    assert {:ok, [%Event{uid: "a"}, %Event{uid: "b"}]} = ICal.parse(text)
  end

  test "an event without a start or without an id" do
    # no start: not an event we can date
    assert {:ok, []} = ICal.parse(calendar("BEGIN:VEVENT\nUID:x\nSUMMARY:Someday\nEND:VEVENT\n"))
    # no id: one is made from the title and start, so a refresh finds it again
    event = one("BEGIN:VEVENT\nSUMMARY:Tea\nDTSTART:20261013\nEND:VEVENT\n")
    assert event.uid == one("BEGIN:VEVENT\nSUMMARY:Tea\nDTSTART:20261013\nEND:VEVENT\n").uid
    assert is_binary(event.uid)
  end

  test "text that is not a calendar is refused" do
    assert ICal.parse("<html>Sign in</html>") == {:error, :not_ical}
    assert ICal.parse("") == {:error, :not_ical}
  end

  test "dates that do not exist are skipped, not fatal" do
    assert {:ok, [%Event{uid: "ok"}]} =
             ICal.parse(
               calendar(
                 "BEGIN:VEVENT\nUID:bad\nDTSTART:20261340\nEND:VEVENT\n" <>
                   "BEGIN:VEVENT\nUID:ok\nDTSTART:20261013\nEND:VEVENT\n"
               )
             )
  end
end
