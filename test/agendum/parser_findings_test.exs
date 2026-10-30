# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.ParserFindingsTest do
  @moduledoc """
  The bugs the parser property tests and the hostile files found
  (ROADMAP, Sharpen the saw; 2026-10-26), each as the case that showed it.
  """
  use ExUnit.Case, async: true
  doctest Agendum.Core.Extras.Utf8

  alias Agendum.Core
  alias Agendum.Core.Extras.{FeedParser, ICal, Markdown}

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

  # 3. the XML reader took quadratic time on many tags (a Unicode regular
  # expression checked all the text after each tag) and on many stray
  # closing tags (each looked down the whole stack): 40,000 of each took
  # 22 seconds; now a fraction of one
  test "a feed of many open elements and stray closing tags is read at once" do
    text =
      "<rss><channel><title>x</title>" <>
        String.duplicate("<item>", 40_000) <>
        String.duplicate("</x>", 40_000) <> "</channel></rss>"

    assert {:value, {:ok, _feed}} = Agendum.Bounded.run(fn -> FeedParser.parse(text) end, 3_000)
  end

  # 4. Markdown took quadratic time on a long paragraph (every pattern
  # tried at every character, the HTML copied at every character, Zettel
  # link positions counted from the start), and on openings that never
  # close (`[`, `![`, `_`): 40,000 characters of prose took 1.6 s
  test "a long post becomes HTML at once, whatever it holds" do
    for text <- [
          String.duplicate("absolute words ", 4_000),
          String.duplicate("[", 20_000) <> String.duplicate("](", 20_000),
          String.duplicate("![", 20_000),
          String.duplicate("_a", 20_000),
          String.duplicate("see https://x.example/a and [[bonalaku]] ", 3_000)
        ] do
      assert {:value, html} =
               Agendum.Bounded.run(fn -> Markdown.to_html(text, %{0 => 1}) end, 3_000)

      assert is_binary(html)
    end
  end

  test "a link's text, a code span or an emphasis of up to 500 characters is still markup" do
    long = String.duplicate("x", 500)
    assert Markdown.to_html("[#{long}](https://x.example/)") =~ ~s(<a href="https://x.example/">)
    assert Markdown.to_html("`#{long}`") =~ "<code>"
    assert Markdown.to_html("_#{long}_") =~ "<em>"
    # longer, it is text
    refute Markdown.to_html("`#{long}x`") =~ "<code>"
    # a letter of any language after the closing underscore keeps it text
    refute Markdown.to_html("_x_é") =~ "<em>"
  end
end
