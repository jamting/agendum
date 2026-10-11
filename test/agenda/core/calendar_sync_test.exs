defmodule Agenda.Core.CalendarSyncTest do
  @moduledoc """
  Calendar subscriptions (R45): a calendar's events become items in its
  category, from today up to a window ahead, and each refresh mirrors the
  calendar: changed events update their items, vanished ones remove them.
  """
  use ExUnit.Case, async: true

  alias Agenda.Core
  alias Agenda.Core.{Calendar, Database, Recurrence}
  alias Agenda.Core.ICal.Event

  # a Monday
  @now ~N[2026-10-12 10:00:00]

  defp event(uid, summary, start, fields \\ []),
    do: struct(Event, [uid: uid, summary: summary, start: start] ++ fields)

  defp subscribed(name \\ "Work Calendar") do
    db = Core.new_file()
    {:ok, db, cal} = Core.subscribe_calendar(db, name, "webcal://example.com/work.ics")
    {db, cal}
  end

  defp sync(db, cal, events, now \\ @now) do
    {:ok, db, counts} = Core.sync_calendar(db, cal, events, now)
    {db, counts}
  end

  defp item(db, cal, uid), do: db.items[db.calendars[cal].events[uid].item]
  defp texts(db), do: db.items |> Map.values() |> Enum.map(& &1.text) |> Enum.sort()

  describe "subscribing" do
    test "makes the calendar's category under MAIN and remembers the calendar" do
      {db, cal} = subscribed()
      calendar = db.calendars[cal]
      assert %Calendar{name: "Work Calendar", url: "https://example.com/work.ics"} = calendar
      category = db.categories[calendar.category_id]
      assert category.name == "Work Calendar"
      assert category.parent_id == db.main_id
      refute category.match_name
      assert {calendar.ahead_days, calendar.refresh_minutes} == {90, 60}
    end

    test "an existing category of that name is used" do
      db = Core.new_file()
      {:ok, db, existing} = Core.add_category(db, db.main_id, "Family")
      {:ok, db, cal} = Core.subscribe_calendar(db, "family", "https://example.com/f.ics")
      assert db.calendars[cal].category_id == existing
    end

    test "a name and a web address are needed" do
      db = Core.new_file()
      assert Core.subscribe_calendar(db, " ", "https://x/y.ics") == {:error, :no_name}
      assert Core.subscribe_calendar(db, "Work", "ftp://x/y.ics") == {:error, :bad_url}
      assert Core.subscribe_calendar(db, "Work", "") == {:error, :bad_url}
    end
  end

  describe "a first refresh" do
    test "events from today up to the window ahead become items" do
      {db, cal} = subscribed()

      events = [
        event("a", "Organising Meeting", {:local, ~N[2026-10-16 14:00:00]},
          description: "Bring the Notices"
        ),
        event("b", "Holiday", {:date, ~D[2026-12-24]}),
        event("old", "Last week's tea", {:date, ~D[2026-10-05]}),
        event("far", "Next summer", {:date, ~D[2027-06-01]})
      ]

      {db, counts} = sync(db, cal, events)
      assert counts == %{added: 2, updated: 0, removed: 0}
      assert texts(db) == ["Holiday", "Organising Meeting"]

      meeting = item(db, cal, "a")

      assert {meeting.when, meeting.when_time, meeting.when_explicit} ==
               {~D[2026-10-16], ~T[14:00:00], true}

      assert meeting.note == "Bring the Notices"
      assert Database.member?(db, meeting.id, db.calendars[cal].category_id)

      holiday = item(db, cal, "b")
      assert {holiday.when, holiday.when_time} == {~D[2026-12-24], nil}
      assert db.calendars[cal].refreshed_at == @now
    end

    test "titles are read like typed items: text matching files them too" do
      {db, cal} = subscribed()
      {:ok, db, pooh} = Core.add_category(db, db.main_id, "Pooh")
      {db, _} = sync(db, cal, [event("a", "Tea with Pooh", {:local, ~N[2026-10-13 16:00:00]})])
      assert Database.member?(db, item(db, cal, "a").id, pooh)
    end

    test "a date in the title does not override the event's date" do
      {db, cal} = subscribed()
      {db, _} = sync(db, cal, [event("a", "Plan for next Friday", {:date, ~D[2026-10-14]})])
      assert item(db, cal, "a").when == ~D[2026-10-14]
    end

    test "cancelled events and events without a title" do
      {db, cal} = subscribed()

      {db, _} =
        sync(db, cal, [
          event("a", "Party", {:date, ~D[2026-10-20]}, status: :cancelled),
          event("b", "", {:date, ~D[2026-10-21]})
        ])

      assert texts(db) == ["(no title)"]
    end
  end

  describe "repeating events" do
    test "a rule Agenda knows becomes one recurring item, on its next date" do
      {db, cal} = subscribed()

      weekly = %{
        freq: :weekly,
        interval: 1,
        byday: ["WE"],
        bymonthday: [],
        count: nil,
        until: nil,
        other: []
      }

      {db, _} =
        sync(db, cal, [event("w", "Choir", {:local, ~N[2026-09-02 18:00:00]}, rrule: weekly)])

      choir = item(db, cal, "w")
      assert choir.when == ~D[2026-10-14]
      assert choir.when_time == ~T[18:00:00]
      assert choir.recurrence == %Recurrence{every: 1, unit: :week, weekday: 3}
    end

    test "monthly, yearly and every other week" do
      {db, cal} = subscribed()

      rule = fn freq, extra ->
        Map.merge(
          %{
            freq: freq,
            interval: 1,
            byday: [],
            bymonthday: [],
            count: nil,
            until: nil,
            other: []
          },
          extra
        )
      end

      {db, _} =
        sync(db, cal, [
          event("m", "Rent", {:date, ~D[2026-01-31]}, rrule: rule.(:monthly, %{})),
          event("y", "Eeyore's birthday", {:date, ~D[2019-10-14]}, rrule: rule.(:yearly, %{})),
          event("f", "Bins", {:date, ~D[2026-10-05]}, rrule: rule.(:weekly, %{interval: 2}))
        ])

      assert item(db, cal, "m").when == ~D[2026-10-31]
      assert item(db, cal, "m").recurrence == %Recurrence{every: 1, unit: :month, day: 31}
      assert item(db, cal, "y").when == ~D[2026-10-14]
      assert item(db, cal, "y").recurrence == %Recurrence{every: 1, unit: :year}
      assert item(db, cal, "f").when == ~D[2026-10-19]
      assert item(db, cal, "f").recurrence == %Recurrence{every: 2, unit: :week, weekday: 1}
    end

    test "a rule Agenda cannot repeat gives the next occurrence only" do
      {db, cal} = subscribed()

      twice = %{
        freq: :weekly,
        interval: 1,
        byday: ["MO", "TH"],
        bymonthday: [],
        count: nil,
        until: nil,
        other: []
      }

      {db, _} = sync(db, cal, [event("t", "Exercise", {:date, ~D[2026-10-01]}, rrule: twice)])
      exercise = item(db, cal, "t")
      assert exercise.when == ~D[2026-10-12]
      assert exercise.recurrence == nil
    end

    test "a weekly rule on days Agenda does not know is read as weekly" do
      {db, cal} = subscribed()

      odd = %{
        freq: :weekly,
        interval: 1,
        byday: ["XX", "1MO"],
        bymonthday: [],
        count: nil,
        until: nil,
        other: []
      }

      {db, _} = sync(db, cal, [event("o", "Odd", {:date, ~D[2026-10-01]}, rrule: odd)])
      assert item(db, cal, "o").when == ~D[2026-10-15]
    end

    test "a series that has ended, or used up its count, is not imported" do
      {db, cal} = subscribed()

      base = %{
        freq: :weekly,
        interval: 1,
        byday: [],
        bymonthday: [],
        count: nil,
        until: nil,
        other: []
      }

      {db, _} =
        sync(db, cal, [
          event("u", "Old class", {:date, ~D[2026-09-01]},
            rrule: %{base | until: ~D[2026-10-01]}
          ),
          event("c", "Short course", {:date, ~D[2026-09-01]}, rrule: %{base | count: 3})
        ])

      assert texts(db) == []
    end
  end

  describe "refreshing mirrors the calendar" do
    setup do
      {db, cal} = subscribed()

      {db, _} =
        sync(db, cal, [
          event("a", "Organising Meeting", {:local, ~N[2026-10-16 14:00:00]},
            description: "Room 1"
          ),
          event("b", "Tea", {:date, ~D[2026-10-13]})
        ])

      %{db: db, cal: cal}
    end

    test "a changed event updates its item", %{db: db, cal: cal} do
      {db, counts} =
        sync(db, cal, [
          event("a", "Organising Meeting (moved)", {:local, ~N[2026-10-17 09:00:00]},
            description: "Room 2"
          ),
          event("b", "Tea", {:date, ~D[2026-10-13]})
        ])

      assert counts == %{added: 0, updated: 1, removed: 0}
      meeting = item(db, cal, "a")
      assert meeting.text == "Organising Meeting (moved)"
      assert {meeting.when, meeting.when_time} == {~D[2026-10-17], ~T[09:00:00]}
      assert meeting.note == "Room 2"
    end

    test "what the calendar did not change keeps the person's edits", %{db: db, cal: cal} do
      id = item(db, cal, "a").id
      db = Core.edit_item(db, id, "Organising Meeting, bring cake", @now)
      db = Core.set_note(db, id, "My own note", @now)
      {:ok, db, owl} = Core.add_category(db, db.main_id, "Owl")
      db = Core.assign(db, id, owl)

      {db, counts} =
        sync(db, cal, [
          event("a", "Organising Meeting", {:local, ~N[2026-10-16 15:00:00]},
            description: "Room 1"
          ),
          event("b", "Tea", {:date, ~D[2026-10-13]})
        ])

      assert counts.updated == 1
      meeting = db.items[id]
      assert meeting.text == "Organising Meeting, bring cake"
      assert meeting.note == "My own note"
      assert meeting.when_time == ~T[15:00:00]
      assert Database.member?(db, id, owl)
    end

    test "an event gone from the calendar, or cancelled, removes its item", %{db: db, cal: cal} do
      {db, counts} =
        sync(db, cal, [
          event("a", "Organising Meeting", {:local, ~N[2026-10-16 14:00:00]}, status: :cancelled)
        ])

      assert counts == %{added: 0, updated: 0, removed: 2}
      assert texts(db) == []
      assert db.calendars[cal].events == %{}
    end

    test "an event now in the past keeps its item", %{db: db, cal: cal} do
      later = ~N[2026-10-20 10:00:00]

      {db, counts} =
        sync(
          db,
          cal,
          [
            event("a", "Organising Meeting", {:local, ~N[2026-10-16 14:00:00]},
              description: "Room 1"
            ),
            event("b", "Tea", {:date, ~D[2026-10-13]})
          ],
          later
        )

      assert counts == %{added: 0, updated: 0, removed: 0}
      assert length(texts(db)) == 2
    end

    test "an item the person discarded is not brought back", %{db: db, cal: cal} do
      db = Core.discard_item(db, item(db, cal, "b").id)

      {db, counts} =
        sync(db, cal, [
          event("a", "Organising Meeting", {:local, ~N[2026-10-16 14:00:00]},
            description: "Room 1"
          ),
          event("b", "Tea", {:date, ~D[2026-10-13]})
        ])

      assert counts.added == 0
      assert texts(db) == ["Organising Meeting"]
    end

    test "a refresh is one change: undo takes it all back", %{db: db, cal: cal} do
      {after_sync, _} = sync(db, cal, [])
      refute after_sync == db
      assert after_sync.calendars[cal].events == %{}
    end
  end

  describe "settings and unsubscribing" do
    test "how often to refresh and how far ahead" do
      {db, cal} = subscribed()
      db = Core.cycle_calendar_setting(db, cal, :refresh_minutes, 1)
      assert db.calendars[cal].refresh_minutes == 360
      db = Core.cycle_calendar_setting(db, cal, :ahead_days, -1)
      assert db.calendars[cal].ahead_days == 30

      refreshes =
        Stream.iterate(db, &Core.cycle_calendar_setting(&1, cal, :refresh_minutes, 1))
        |> Enum.take(6)

      assert nil in Enum.map(refreshes, & &1.calendars[cal].refresh_minutes)
    end

    test "a calendar is due when never refreshed or its interval has passed" do
      {db, cal} = subscribed()
      assert Calendar.due?(db.calendars[cal], @now)
      {db, _} = sync(db, cal, [])
      refute Calendar.due?(db.calendars[cal], NaiveDateTime.add(@now, 59 * 60))
      assert Calendar.due?(db.calendars[cal], NaiveDateTime.add(@now, 60 * 60))
      manual = Core.cycle_calendar_setting(db, cal, :refresh_minutes, -1)
      assert manual.calendars[cal].refresh_minutes == nil
      refute Calendar.due?(manual.calendars[cal], NaiveDateTime.add(@now, 999_999))
    end

    test "a failed refresh is remembered until the next good one" do
      {db, cal} = subscribed()
      db = Core.calendar_failed(db, cal, "could not connect", @now)
      assert db.calendars[cal].error == "could not connect"
      assert db.calendars[cal].refreshed_at == @now
      {db, _} = sync(db, cal, [])
      assert db.calendars[cal].error == nil
    end

    test "unsubscribing keeps or removes its items" do
      {db, cal} = subscribed()
      {db, _} = sync(db, cal, [event("a", "Tea", {:date, ~D[2026-10-13]})])
      kept = Core.unsubscribe_calendar(db, cal, false)
      assert kept.calendars == %{}
      assert texts(kept) == ["Tea"]
      removed = Core.unsubscribe_calendar(db, cal, true)
      assert texts(removed) == []
    end
  end
end
