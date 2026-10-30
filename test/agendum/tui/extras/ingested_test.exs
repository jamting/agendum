# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Extras.IngestedTest do
  @moduledoc """
  Ingested categories in the TUI (R75a; meeting 2026-10-26-1732, § 6; the
  owner's choices, 2026-10-26): the Feeds family starts folded in the
  category manager, ALT-= opens it; changing a feed's category there is
  refused with a message saying where to do it; F2 in the Feeds and
  Calendars boxes renames a feed or a calendar, its category with it.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core

  setup do
    db = Core.new_file()
    {:ok, db, feed} = Core.subscribe_feed(db, "Heffalump News", "https://heffalump.example/rss")
    {:ok, db, cal} = Core.subscribe_calendar(db, "Work Calendar", "webcal://work.example/c.ics")
    %{state: start(db, extras: true), feed: feed, cal: cal}
  end

  defp manager(state), do: press(state, {:f, 9})

  # the highlight onto the category manager's row of that name
  defp to_row(state, name) do
    mode = Agendum.TUI.State.mode(state)
    rows = Agendum.TUI.CategoryScreens.rows(state, mode)
    index = Enum.find_index(rows, &(state.db.categories[row_id(&1)].name == name))
    press(state, List.duplicate(:down, index - mode.cursor))
  end

  defp row_id({id, _depth}), do: id
  defp row_id(id), do: id

  test "the Feeds family starts folded in the category manager; ALT-= opens it", %{state: state} do
    state = manager(state)
    assert screen(state) =~ "Feeds"
    refute screen(state) =~ "Heffalump News"

    opened = state |> to_row("Feeds") |> press({:alt, "="})
    assert screen(opened) =~ "Heffalump News"
  end

  test "renaming a feed's category in the manager is refused, with where to do it",
       %{state: state, feed: feed} do
    state =
      state |> manager() |> to_row("Feeds") |> press({:alt, "="}) |> to_row("Heffalump News")

    renamed = press(state, [{:f, 2}, {:ctrl, "u"}] ++ String.graphemes("Mine") ++ [:enter])

    assert renamed.db.feeds[feed].name == "Heffalump News"
    assert renamed.db.categories[renamed.db.feeds[feed].category_id].name == "Heffalump News"
    assert screen(renamed) =~ "File ▸ Transfer ▸ Feeds"
  end

  test "F2 in the Feeds box renames the feed and its category", %{state: state, feed: feed} do
    state = press(state, [{:f, 10}, "f", "t", "f"])
    asked = press(state, {:f, 2})
    assert screen(asked) =~ "New name of the feed:"
    assert screen(asked) =~ "Heffalump News"

    renamed = press(asked, [{:ctrl, "u"}] ++ String.graphemes("Woozle Weekly") ++ [:enter])
    assert renamed.db.feeds[feed].name == "Woozle Weekly"
    assert renamed.db.categories[renamed.db.feeds[feed].category_id].name == "Woozle Weekly"
    assert screen(renamed) =~ "Woozle Weekly"
  end

  test "F2 in the Calendars box renames the calendar and its category", %{state: state, cal: cal} do
    state = press(state, [{:f, 10}, "f", "t", "c"])
    renamed = press(state, [{:f, 2}, {:ctrl, "u"}] ++ String.graphemes("Office") ++ [:enter])
    assert renamed.db.calendars[cal].name == "Office"
    assert renamed.db.categories[renamed.db.calendars[cal].category_id].name == "Office"
  end

  test "the Calendars family is folded too, and says where to change it", %{state: state} do
    state = manager(state)
    assert screen(state) =~ "Calendars"
    refute screen(state) =~ "Work Calendar"

    refused = state |> to_row("Calendars") |> press({:f, 2})
    assert screen(refused) =~ "Calendars holds your calendars"
    assert screen(refused) =~ "File ▸ Transfer ▸ Calendars"
  end

  test "in a file with calendars and no feeds, Calendars is folded too" do
    db = Core.new_file()
    {:ok, db, _} = Core.subscribe_calendar(db, "Work Calendar", "webcal://work.example/c.ics")
    state = start(db, extras: true) |> manager()
    assert screen(state) =~ "Calendars"
    refute screen(state) =~ "Work Calendar"
  end
end
