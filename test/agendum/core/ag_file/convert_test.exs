# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.AgFile.ConvertTest do
  @moduledoc """
  The `.AG` import (R72) on the fixtures: Lotus's starter files and RICH.AG,
  made in Agenda 2.0 for these tests. What Agenda showed in RICH.AG's Tasks
  view (checked in DOSBox, 2026-10-16): "Call Bob about the budget
  tomorrow" in Calls, with Anna typed in its People column and a 15-minute
  alarm; "Meet with Anna next Friday at 9am" in Meetings at 9:00;
  "Gym every Monday" recurring; "Write to the bank" in Mail, with a
  two-line note; "Read the quarterly report" discarded. UX.AG is
  Information Sifter with one item, "Owls in winter", under Sample
  Company, Issue 10/1/90 (which Agenda, its clock in 2026, read as 2090)
  and "Barn owls at dusk42" in the unindexed Page column; its password is
  Hoot, which Agenda also took as "hoot" and refused as "owl" ("The
  password you typed is incorrect").
  """
  use ExUnit.Case, async: true

  alias Agendum.Core.{AgFile, Database, DateParser, Invariants}
  alias Agendum.Core.AgFile.{Convert, Reader}

  @dir "test/fixtures/ag"
  # Lotus's starters, then the files made in Agenda for these tests; the
  # starters' tests run only where they are (test_helper.exs)
  @lotus ~w(ACCOUNT INFOSIFT PEOPLE PLANNER)
  @own ~w(DATES RICH UX)
  # the fixtures on this machine, for the tests that go through them all
  @files @own ++ Enum.filter(@lotus, &File.exists?("test/fixtures/ag/#{&1}.AG"))
  @today ~D[2026-10-16]

  defp bytes(name), do: File.read!(Path.join(@dir, name <> ".AG"))

  defp import!(name) do
    password = if name == "UX", do: "Hoot"
    {:ok, db, report} = AgFile.import(bytes(name), clock: @today, password: password)
    {db, report}
  end

  defp item(db, text), do: db.items |> Map.values() |> Enum.find(&(&1.text == text))

  defp in?(db, item, name) do
    cat = db.categories |> Map.values() |> Enum.find(&(&1.name == name))
    Database.member?(db, item.id, cat.id)
  end

  test "every fixture imports as a whole file that keeps Agendum's rules" do
    Enum.each(@own, &imports_whole/1)
  end

  @tag :lotus_starters
  test "every starter imports as a whole file that keeps Agendum's rules" do
    Enum.each(@lotus, &imports_whole/1)
  end

  defp imports_whole(name) do
    {db, report} = import!(name)
    assert Invariants.violations(db) == [], name
    assert report.views == map_size(db.views) and report.views > 0, name
  end

  @tag :lotus_starters
  test "an imported file shows dates in Agenda's default format (R41)" do
    {db, _} = import!("PLANNER")
    assert db.date_format == Agendum.Core.DateFormat.agenda()
  end

  # DATES.AG is RICH.AG with its global Display format set in Agenda 2.0
  # (2026-10-26): DDMMYY, "-", 24 hr, day of week shown (header word 0x182)
  test "an imported file keeps its description and File Properties (R82)" do
    {db, _} = import!("UX")
    assert {db.description, db.tab_size, db.backup_on_open} == {"Information Sifter", 5, false}
  end

  test "an imported file keeps its own global date format (R41, R72)" do
    {db, _} = import!("DATES")

    assert db.date_format == %Agendum.Core.DateFormat{
             order: :ddmmyy,
             separator: "-",
             clock: 24,
             day_of_week: true,
             show: :date_time,
             am_pm: true,
             time_separator: ":"
           }
  end

  @tag :lotus_starters
  test "the categories come over with their tree and settings" do
    {db, _} = import!("PLANNER")
    by_name = Map.new(db.categories, fn {_id, c} -> {c.name, c} end)

    assert by_name["Calls"].short_name == "Phone"
    assert by_name["Calls"].also_match == "Telephone"
    assert by_name["Meetings"].also_match == "Mtgs;(meet with);(talk to);meet"
    assert by_name["Calls"].parent_id == by_name["Activity"].id
    assert by_name["Priority"].exclusive
    assert by_name["Amount"].kind == :numeric
    assert by_name["When"].id == db.special.when
    # Unassigned: items in no project… (a condition)
    assert by_name["Unassigned"].conditions != []
  end

  test "items keep their text, note, dates, alarm; the discarded one is in the trash" do
    {db, report} = import!("RICH")
    assert report.items == 5 and report.trashed == 1
    refute item(db, "Read the quarterly report")
    # Agenda's trash is ours (R24a), counted from the day of the import
    assert [%{text: "Read the quarterly report"}] = db.trash.items
    assert db.trash.day == @today
    assert db.trash.empty == :end_of_day

    bob = item(db, "Call Bob about the budget tomorrow")
    assert bob.when == ~D[2026-10-17] and bob.when_time == nil
    assert bob.entry == ~D[2026-10-16]
    assert bob.alarm_minutes == 15

    anna = item(db, "Meet with Anna next Friday at 9am")
    assert anna.when == ~D[2026-10-23] and anna.when_time == ~T[09:00:00]

    gym = item(db, "Gym every Monday")
    assert gym.recurrence == %Agendum.Core.Recurrence{every: 1, unit: :week, weekday: 1}

    bank = item(db, "Write to the bank")
    assert bank.note == "Pages 10 to 20\nAsk Carl about it"
  end

  test "assignments by hand are kept; Agendum's own rules make the rest, as Agenda did" do
    {db, report} = import!("RICH")
    bob = item(db, "Call Bob about the budget tomorrow")
    assert in?(db, bob, "Anna") and in?(db, bob, "Calls") and in?(db, bob, "Tasks")
    assert in?(db, item(db, "Write to the bank"), "Mail")
    assert in?(db, item(db, "Meet with Anna next Friday at 9am"), "Meetings")

    # Anna was made after this item was typed: Agenda had not matched it
    # again, Agendum's matching does
    assert [%{text: "Meet with Anna next Friday at 9am", only_agendum: ["Anna", "People"]}] =
             report.differences
  end

  test "relative dates in filters become phrases that Agendum reads as Agenda did" do
    for name <- @files do
      {:ok, file} = Reader.read(bytes(name))
      {db, _report} = import!(name)

      for view <- file.views,
          not Map.has_key?(view, :datebook),
          element <- view.filter ++ Enum.flat_map(view.sections, &Map.get(&1, :filter, [])),
          range <- [Map.get(element, :range)],
          range != nil do
        bounds =
          for side <- [:start, :end],
              words <- [Convert.phrase(range[:"#{side}_given_as"])],
              words != nil,
              do: {words, range[side] |> String.slice(0, 10) |> Date.from_iso8601!()}

        # Domain: Agenda keeps the date it last worked each phrase out to,
        # on a day the file does not record; some day near it must give
        # every bound of the range as Agenda had it
        unless bounds == [] do
          {_, near} = hd(bounds)

          assert Enum.any?(-40..40, fn shift ->
                   day = Date.add(near, shift)

                   Enum.all?(bounds, fn {words, agenda} ->
                     DateParser.parse(words, day, settings: db.date_settings) == {:ok, agenda}
                   end)
                 end),
                 "#{name}, #{view.name}: #{inspect(bounds)}"
        end
      end
    end
  end

  test "a file with a password needs it, in any case, as in Agenda" do
    assert AgFile.import(bytes("UX")) == {:error, :password_required}
    assert AgFile.import(bytes("UX"), password: "owl") == {:error, :wrong_password}
    assert {:ok, _db, _report} = AgFile.import(bytes("UX"), password: "hoot")
    assert {:ok, _db, _report} = AgFile.import(bytes("RICH"), password: "anything")
  end

  # unindexed categories are Agendum's too since R29b (2026-10-25)
  test "an unindexed category stays unindexed, its values texts; a date category's dates stay" do
    {db, report} = import!("UX")
    owls = item(db, "Owls in winter")
    page = db.categories |> Map.values() |> Enum.find(&(&1.name == "Page"))
    assert page.kind == :unindexed
    assert page.children == []
    assert Database.text(db, owls.id, page.id) == "Barn owls at dusk42"
    assert Database.member?(db, owls.id, page.id)
    assert in?(db, owls, "Sample Company")

    issue = db.categories |> Map.values() |> Enum.find(&(&1.name == "Issue"))
    assert {~D[2090-10-01], nil, true} = db.dates[{owls.id, issue.id}]
    refute Enum.any?(report.notes, &(&1 =~ "was unindexed"))
  end

  # Agenda showed no done item or number in these files (F4 did not take
  # in DOSBox), so they are added to what was read from RICH.AG: a Done
  # date and a number in Amount (numeric), as the reader gives them.
  test "a Done date and a number come over" do
    {:ok, file} = Reader.read(bytes("RICH"))
    gym = Enum.find(file.items, &(&1.text == "Gym every Monday"))

    more = [
      %{
        category: 16,
        how: "explicit",
        value: "2026-10-15T18:00",
        given_as: %{kind: "absolute", time_given: false}
      },
      %{category: 118, how: "explicit", value: 12.5}
    ]

    file = %{
      file
      | items:
          Enum.map(
            file.items,
            &if(&1 == gym, do: %{&1 | assignments: &1.assignments ++ more}, else: &1)
          )
    }

    converted = Convert.convert(file)
    {:ok, db} = Agendum.Core.JSONFile.decode_document(converted.document)

    assert db.items[gym.id].done == ~D[2026-10-15]
    assert db.numbers[{gym.id, 118}] == 12.5
  end

  test "anything that is not an Agenda file is refused" do
    assert AgFile.import("hello") == {:error, :not_an_agenda_file}
    refute AgFile.agenda_file?("{\"format\": \"agendum-json\"}")
    assert AgFile.agenda_file?(bytes("RICH"))
  end
end
