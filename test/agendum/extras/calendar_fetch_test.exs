# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Extras.CalendarFetchTest do
  @moduledoc "What the shell does to events it reads (R45): UTC times become local time."
  use ExUnit.Case, async: true

  alias Agendum.Extras.CalendarFetch
  alias Agendum.Core.Extras.ICal.Event

  test "a UTC start and end both move to local time, keeping the event's length" do
    event = %Event{
      uid: "a",
      start: {:utc, ~N[2026-10-16 12:00:00]},
      end: {:utc, ~N[2026-10-16 13:30:00]}
    }

    %Event{start: {:local, start}, end: {:local, finish}} = CalendarFetch.localize(event)
    assert NaiveDateTime.diff(finish, start) == 90 * 60
  end

  test "local times, dates and a missing end stay as they are" do
    event = %Event{uid: "b", start: {:date, ~D[2026-12-24]}, end: nil}
    assert CalendarFetch.localize(event) == event

    event = %Event{
      uid: "c",
      start: {:local, ~N[2026-10-16 09:00:00]},
      end: {:local, ~N[2026-10-16 10:00:00]}
    }

    assert CalendarFetch.localize(event) == event
  end
end
