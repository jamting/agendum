# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Extras.SubscriptionNameTest do
  @moduledoc """
  The name offered when subscribing (R75, R45; the owner, 2026-10-27): the
  feed's or calendar's own title, cleaned, else the address's host.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.Extras.ICal

  test "a title is offered cleaned: one line, no control characters, not too long" do
    assert Core.subscription_name("  Owl's\\n Gazette ", "https://o.example/rss") ==
             "Owl's\\n Gazette"

    assert Core.subscription_name("Owl's\nGazette\e[2J", "https://o.example/rss") ==
             "Owl's Gazette [2J"

    assert String.length(Core.subscription_name(String.duplicate("x", 500), "https://o")) == 60
  end

  test "without a title, the address's host" do
    assert Core.subscription_name(nil, "https://news.example/feed.xml") == "news.example"
    assert Core.subscription_name("   ", "webcal://cal.example/a.ics") == "cal.example"
  end

  test "a calendar's own name is its X-WR-CALNAME" do
    ics =
      "BEGIN:VCALENDAR\r\nX-WR-CALNAME:Wood\\, Events\r\nBEGIN:VEVENT\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"

    assert ICal.name(ics) == "Wood, Events"
    assert ICal.name("BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n") == nil
    assert ICal.name("not a calendar") == nil
  end
end
