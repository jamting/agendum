defmodule Agendum.ParserFindingsTest do
  @moduledoc """
  The bugs the parser property tests and the hostile files found
  (ROADMAP, Sharpen the saw; 2026-10-26), each as the case that showed it.
  """
  use ExUnit.Case, async: true
  doctest Agendum.Core.Extras.Utf8

  alias Agendum.Core
  alias Agendum.Core.Extras.ICal

  @now ~N[2026-10-26 23:30:00]

  # 1. a calendar in Latin-1 reached the items with bytes that are no text,
  # and the text matching of the sync raised on them
  test "a Latin-1 calendar syncs, its text read as Latin-1" do
    text =
      "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\nUID:l1\r\n" <>
        "DTSTART;VALUE=DATE:20261027\r\nSUMMARY:Lunch at Caf" <>
        <<0xE9>> <>
        "\r\n" <>
        "END:VEVENT\r\nEND:VCALENDAR\r\n"

    assert {:ok, [event]} = ICal.parse(text)
    assert event.summary == "Lunch at Café"

    db = Core.new_file()
    {:ok, db, cal} = Core.subscribe_calendar(db, "Work", "https://w.example/w.ics")
    {:ok, db, _cat} = Core.add_category(db, db.main_id, "Lunch")
    assert {:ok, db, _counts} = Core.sync_calendar(db, cal, [event], @now)
    assert Enum.any?(Map.values(db.items), &(&1.text == "Lunch at Café"))
  end
end
