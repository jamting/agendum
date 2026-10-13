defmodule Agenda.Core.JSONFileTest do
  @moduledoc "A whole file as JSON (R44; ADR 0010): complete, readable, and checked when read."
  use ExUnit.Case, async: true

  alias Agenda.Core
  alias Agenda.Core.{DateFormat, DateRule, DateSettings, JSONFile, NumberFormat, Recurrence}
  alias Agenda.Core.{Search, TextMatch}
  alias Agenda.Core.View.SortKey

  @today ~D[2026-10-08]

  defp round_trip(db), do: JSONFile.decode(JSONFile.encode(db))

  # A file using every part of the data model.
  defp rich do
    db = Core.new_file()
    main = db.main_id
    view = hd(db.view_order)
    {:ok, db, people} = Core.add_category(db, main, "People")
    {:ok, db, anna} = Core.add_category(db, people, "Anna Lasky")
    {:ok, db, bo} = Core.add_category(db, people, "Bo")
    {:ok, db, cost} = Core.add_category(db, main, "Cost")
    {:ok, db} = Core.make_numeric(db, cost)
    {:ok, db, due} = Core.add_category(db, main, "Due")
    {:ok, db} = Core.make_date(db, due, @today)
    {:ok, db, urgent} = Core.add_category(db, main, "Urgent")
    {:ok, db} = Core.make_exclusive(db, people)
    db = Core.set_short_name(db, anna, "Anna")
    db = Core.set_category_note(db, urgent, "Drop everything\nand do it")
    {:ok, db} = Core.toggle_exclude(db, urgent, bo)
    {:ok, db} = Core.set_also_match(db, urgent, "asap; (right away)")
    {:ok, db} = Core.set_match_override(db, people, :match_on, :note)
    {:ok, db} = Core.set_match_override(db, people, :confirm, :sometimes)

    {:ok, db} =
      Core.set_date_rule(db, due, %DateRule{assign: :item_text, which: 2, done_key: true})

    db = %{
      db
      | categories:
          db.categories
          |> Map.update!(urgent, fn c ->
            %{
              c
              | conditions: [{anna, :assigned}, {cost, {:range, nil, 100.0, :outside}}],
                actions: [{bo, :remove}, {due, {:set, "tomorrow"}}, {cost, {:set, 5.5}}],
                special: :done,
                also_assign: [people]
            }
          end)
    }

    {db, a} = Core.add_item(db, "Call Anna Lasky tomorrow at 3pm every Monday", @today)
    {db, b} = Core.add_item(db, "Pay the bill", @today)
    db = Core.set_note(db, b, "Ränta: \"5%\" ✓", @today)
    {:ok, db} = Core.set_number(db, b, cost, 1234.5)
    db = Core.set_date(db, b, due, ~D[2026-12-24])
    {:ok, db} = Core.make_dependent(db, a, [b])
    {:ok, db} = Core.set_alarm(db, a, 15)
    db = Core.toggle_mark(db, b)

    db = %{
      db
      | items:
          Map.update!(db.items, a, fn i ->
            %{
              i
              | recurrence: %Recurrence{every: 2, unit: :month, day: 31},
                alarm_rung_at: ~N[2026-10-09 14:45:00.123456]
            }
          end),
        conditional: MapSet.put(db.conditional, {b, urgent}),
        suggestions: %{b => [urgent, anna]},
        dates: Map.put(db.dates, {a, due}, {~D[2026-11-01], ~T[09:30:00], false})
    }

    db = Core.add_column(db, view, cost, {0, 1}, 9)
    # a column in one section only, not linked; new ones go there too (R55)
    db = Core.add_column(db, view, people, {0, 0}, 10, :section)
    db = Core.set_insert_columns(db, :section)

    db =
      Core.set_column_format(db, view, {0, 1}, %NumberFormat{
        symbol: "£",
        decimals: 0,
        calcs: [:count, :maximum]
      })

    db = Core.set_column_date_format(db, view, {0, 0}, %DateFormat{order: :relative, show: :date})
    {db, view2} = Core.add_view(db, "Found", [people, urgent])

    db =
      Agenda.Core.Database.update_view(db, view2, fn v ->
        %{
          v
          | filter: [{urgent, :not_assigned}, {due, {:range, "today", "next week", :inside}}],
            sort: [
              %SortKey{on: {:category, people}, order: :desc, sequence: :alpha, line: 2},
              %SortKey{on: {:note, urgent}, na: :top}
            ],
            sections:
              Enum.map(
                v.sections,
                &%{&1 | collapsed: true, sort: [%SortKey{}], filter: [{bo, :assigned}]}
              ),
            match: %Search{text: "bill", on: :both, ignore_case: false},
            hide_done: true,
            hide_dependent: true,
            section_sort: :alpha,
            section_order: :desc
        }
      end)

    {:ok, db, _} =
      Core.add_datebook_view(db, "Mornings", %Agenda.Core.Datebook{
        period: :day,
        interval: 30,
        start_time: ~T[07:30:00],
        end_category: due,
        section_category: urgent,
        base: "tomorrow"
      })

    {:ok, db, _} =
      Core.add_datebook_view(db, "Quarter", %Agenda.Core.Datebook{
        period: :quarter,
        interval: :month
      })

    {:ok, db, weed} = Core.add_macro(db, "Weed {the} garden")
    db = Core.set_macro_keys(db, weed, "{F10}vc{ENTER}Ränta \"5%\"{AltF2}")

    db =
      db |> Core.attach_macro(weed, "{ShfF4}") |> Core.set_macro_run_from(weed, :elsewhere, true)

    {:ok, db, _} = Core.add_macro(db, "Another")
    db = Core.move_macro(db, weed, 1)

    {:ok, db, cal} = Core.subscribe_calendar(db, "Work Calendar", "webcal://example.com/w.ics")

    events = [
      %Agenda.Core.ICal.Event{
        uid: "m@x",
        summary: "Standup",
        start: {:local, ~N[2026-10-14 09:15:00]},
        end: {:local, ~N[2026-10-14 09:30:00]},
        description: "Daily",
        rrule: %{
          freq: :weekly,
          interval: 1,
          byday: ["WE"],
          bymonthday: [],
          count: nil,
          until: nil,
          other: []
        }
      },
      %Agenda.Core.ICal.Event{uid: "t@x", summary: "Tea", start: {:date, ~D[2026-10-13]}}
    ]

    {:ok, db, _} = Core.sync_calendar(db, cal, events, ~N[2026-10-12 10:00:00])
    db = Core.cycle_calendar_setting(db, cal, :refresh_minutes, -1)
    db = Core.calendar_failed(db, cal, "timeout", ~N[2026-10-12 11:00:00])

    db
    |> Core.set_date_format(%DateFormat{
      order: :ddmmmyy,
      clock: 12,
      am_pm: false,
      time_separator: "hm"
    })
    |> Core.set_date_settings(%DateSettings{
      week_start: 7,
      month_alone: 15,
      morning: ~T[07:30:00]
    })
    |> Core.set_match_settings(%TextMatch{
      strength: :partial,
      enclosed_by: :brackets,
      ignore_accents: true
    })
    |> Core.set_confirm_assignments(:always)
  end

  describe "a round trip keeps everything" do
    test "a new file and the sample" do
      assert round_trip(Core.new_file()) == {:ok, Core.new_file()}
      sample = Agenda.Sample.build(@today)
      assert round_trip(sample) == {:ok, sample}
    end

    test "a file using every part of the data model" do
      db = rich()
      assert round_trip(db) == {:ok, db}
    end

    test "a second view in Show View mode with listed items" do
      db = Agenda.Sample.build(@today)
      db = Core.show_items(db, Enum.take(db.item_order, 2)) |> elem(0)
      assert round_trip(db) == {:ok, db}
    end
  end

  describe "the text is readable" do
    test "enumerations are words, dates ISO 8601, keys in a fixed order" do
      text = JSONFile.encode(rich())
      assert text =~ ~s("format": "agendum-json")
      assert text =~ ~s("kind": "numeric")
      assert text =~ ~s("assign": "item_text")
      assert text =~ ~s("date": "2026-12-24")
      assert text =~ ~s("morning": "07:30:00")
      assert text =~ ~s("note": "Ränta: \\"5%\\" ✓")
      assert text =~ ~s("url": "https://example.com/w.ics")
      # an item's fields start with its id and text
      assert text =~ ~r/\{\n\s+"id": \d+,\n\s+"text": "Pay the bill"/
      assert text == JSONFile.encode(rich())
    end

    test "the file's input format is not in it (it is the person's, ADR 0008)" do
      refute JSONFile.encode(rich()) =~ "number_order"
    end
  end

  describe "reading" do
    test "fields left out take their defaults" do
      # the format's name from before the rename is still read
      text = ~s({"format": "agenda-json", "version": 1, "next_id": 9, "main": 1,
        "special": {"entry": 2, "when": 3, "done": 4},
        "categories": [
          {"id": 1, "name": "MAIN", "children": [2, 3, 4, 5]},
          {"id": 2, "name": "Entry", "parent": 1, "kind": "date"},
          {"id": 3, "name": "When", "parent": 1, "kind": "date"},
          {"id": 4, "name": "Done", "parent": 1, "kind": "date"},
          {"id": 5, "name": "Calls", "parent": 1}],
        "items": [{"id": 6, "text": "Call Bo", "categories": [1, 5]}],
        "views": [{"id": 7, "name": "Calls", "sections": [{"category": 5}]}]})

      assert {:ok, db} = JSONFile.decode(text)
      assert db.items[6].text == "Call Bo"
      assert db.categories[5].match_name
      assert db.date_format == %DateFormat{}
      assert hd(db.views[7].sections).collapsed == false
      assert Agenda.Core.Database.member?(db, 6, 5)
    end

    test "errors say what is wrong and where" do
      good = JSONFile.encode(Core.new_file())
      assert JSONFile.decode("{oops") == {:error, "not valid JSON"}
      assert JSONFile.decode(~s({"a": 1})) == {:error, "not an Agendum JSON file"}

      assert JSONFile.decode(String.replace(good, ~s("version": 1), ~s("version": 9))) ==
               {:error, "unsupported version 9"}

      assert {:error, message} =
               JSONFile.decode(String.replace(good, ~s("kind": "standard"), ~s("kind": "cheese")))

      assert message =~ ~r/categories\[0\]\.kind: unknown value "cheese"/

      assert {:error, message} =
               JSONFile.decode(String.replace(good, ~s("name": "MAIN"), ~s("name": 5)))

      assert message =~ "categories[0].name: expected string, got 5"
    end

    test "references to things that do not exist are refused" do
      db = Core.new_file()
      {db, id} = Core.add_item(db, "x", @today)
      text = JSONFile.encode(db)

      broken = String.replace(text, ~s("depends_on": []), ~s("depends_on": [999]))

      refute broken == text
      assert {:error, message} = JSONFile.decode(broken)
      assert message =~ "item #{id}"
    end
  end
end
