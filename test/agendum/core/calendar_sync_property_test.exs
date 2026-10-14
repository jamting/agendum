defmodule Agendum.Core.CalendarSyncPropertyTest do
  @moduledoc "Any calendar can be read, and reading the same one twice changes nothing more (R45)."
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Agendum.Core
  alias Agendum.Core.ICal.Event

  @now ~N[2026-10-12 10:00:00]

  defp a_date, do: map(integer(-400..400), &Date.add(~D[2026-10-12], &1))

  defp start do
    one_of([
      map(a_date(), &{:date, &1}),
      map({a_date(), integer(0..23), integer(0..59)}, fn {d, h, m} ->
        {:local, NaiveDateTime.new!(d, Time.new!(h, m, 0))}
      end)
    ])
  end

  defp rrule do
    one_of([
      constant(nil),
      fixed_map(%{
        freq: member_of([:daily, :weekly, :monthly, :yearly, nil]),
        interval: integer(1..4),
        byday: list_of(member_of(~w(MO TU WE TH FR SA SU XX)), max_length: 3),
        bymonthday: list_of(integer(-31..31), max_length: 2),
        count: one_of([constant(nil), integer(1..20)]),
        until: one_of([constant(nil), a_date()]),
        other: one_of([constant([]), constant(["BYSETPOS"])])
      })
    ])
  end

  defp event do
    gen all(
          uid <- member_of(~w(a b c d e f g)),
          summary <- member_of(["Tea", "", "Visit Pooh next Friday", "Choir"]),
          description <- member_of([nil, "", "Room 2"]),
          start <- start(),
          finish <- one_of([constant(nil), start()]),
          rrule <- rrule(),
          status <- member_of([nil, :cancelled, :confirmed])
        ) do
      %Event{
        uid: uid,
        summary: summary,
        description: description,
        start: start,
        end: finish,
        rrule: rrule,
        status: status
      }
    end
  end

  property "a refresh never fails, and a second identical refresh changes no items" do
    check all(first <- list_of(event(), max_length: 8), second <- list_of(event(), max_length: 8)) do
      db = Core.new_file()
      {:ok, db, cal} = Core.subscribe_calendar(db, "Cal", "https://x/c.ics")
      {:ok, db, _} = Core.sync_calendar(db, cal, first, @now)
      {:ok, db, _} = Core.sync_calendar(db, cal, second, @now)
      {:ok, again, counts} = Core.sync_calendar(db, cal, second, @now)
      assert counts == %{added: 0, updated: 0, removed: 0}
      assert again.items == db.items
      assert Agendum.Core.JSONFile.decode(Agendum.Core.JSONFile.encode(again)) == {:ok, again}
    end
  end
end
