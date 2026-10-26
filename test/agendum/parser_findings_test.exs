defmodule Agendum.ParserFindingsTest do
  @moduledoc """
  The bugs the parser property tests and the hostile files found
  (ROADMAP, Sharpen the saw; 2026-10-26), each as the case that showed it.
  """
  use ExUnit.Case, async: true
  doctest Agendum.Core.Extras.Utf8

  alias Agendum.Core
  alias Agendum.Core.Extras.{FeedParser, ICal}

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

  # 2. a feed with a byte that is no UTF-8 made the XML reader's regular
  # expressions raise, before a single entry was read
  test "a feed in Latin-1 is read, its text read as Latin-1" do
    text =
      ~s(<?xml version="1.0" encoding="ISO-8859-1"?><rss version="2.0"><channel>) <>
        "<title>Nyheter</title><item><guid>1</guid><title>Caf" <>
        <<0xE9>> <>
        "</title>" <>
        "</item></channel></rss>"

    assert {:ok, %{entries: [entry]}} = FeedParser.parse(text)
    assert entry.title == "Café"

    db = Core.new_file()
    {:ok, db, feed} = Core.subscribe_feed(db, "News", "https://n.example/feed")
    assert {:ok, _db, _counts} = Core.sync_feed(db, feed, [entry], @now)
  end
end
