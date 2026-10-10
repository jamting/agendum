defmodule Agenda.Core.RecurringDatesTest do
  @moduledoc """
  Recurring dates (R14a; User's Guide 6-10, 7-11 to 7-12): "every Monday"
  gives a When date and a rule; marking the item done makes the next one.
  Cases from Lotus's support Q&A (docs/reference/ag2qanda.txt.html) check
  that Agenda 2.0's bugs are not repeated.
  """
  use ExUnit.Case, async: true

  alias Agenda.Core
  alias Agenda.Core.{Database, DateParser, Recurrence}
  alias Agenda.Core.DateLanguage.{English, Swedish}

  # Thursday
  @today ~D[2026-10-08]
  @now ~N[2026-10-08 10:00:00]

  defp read(text, languages \\ [English]) do
    case DateParser.parse_recurring(text, @now, languages: languages) do
      {:ok, date, _time, rule} -> {date, rule}
      :error -> :error
    end
  end

  describe "reading recurring dates" do
    test "every weekday, and every other one" do
      assert read("every Monday") == {~D[2026-10-12], %Recurrence{unit: :week, weekday: 1}}
      assert read("each thursday") == {~D[2026-10-08], %Recurrence{unit: :week, weekday: 4}}
      assert read("evry fri") == {~D[2026-10-09], %Recurrence{unit: :week, weekday: 5}}

      assert read("every other Monday") ==
               {~D[2026-10-12], %Recurrence{every: 2, unit: :week, weekday: 1}}
    end

    test "every day, week, month, quarter and year, from today" do
      assert read("every day") == {@today, %Recurrence{unit: :day}}
      assert read("every other week") == {@today, %Recurrence{every: 2, unit: :week}}
      assert read("every month") == {@today, %Recurrence{unit: :month, day: 8}}
      assert read("every quarter") == {@today, %Recurrence{every: 3, unit: :month, day: 8}}
      assert read("every three months") == {@today, %Recurrence{every: 3, unit: :month, day: 8}}
      assert read("every 2 days") == {@today, %Recurrence{every: 2, unit: :day}}
      assert read("every year") == {@today, %Recurrence{unit: :year}}
    end

    test "a day of every month: this month's if still to come, else next month's" do
      assert read("the 30th of every month") ==
               {~D[2026-10-30], %Recurrence{unit: :month, day: 30}}

      assert read("the 1st of every month") == {~D[2026-11-01], %Recurrence{unit: :month, day: 1}}

      assert read("the fifteenth of each month") ==
               {~D[2026-10-15], %Recurrence{unit: :month, day: 15}}
    end

    test "with a time" do
      assert {:ok, ~D[2026-10-12], ~T[09:00:00], %Recurrence{weekday: 1}} =
               DateParser.parse_recurring("Every Monday at 9am", @now)
    end

    test "dates that do not recur have no rule" do
      assert read("next monday") == {~D[2026-10-12], nil}
    end

    test "in item text" do
      assert {:ok, ~D[2026-10-09], nil, %Recurrence{weekday: 5}, "every friday"} =
               DateParser.extract_recurring("Staff meeting every Friday", @now)
    end

    test "in Swedish" do
      sv = [Swedish]
      assert read("varje måndag", sv) == {~D[2026-10-12], %Recurrence{unit: :week, weekday: 1}}

      assert read("varannan fredag", sv) ==
               {~D[2026-10-09], %Recurrence{every: 2, unit: :week, weekday: 5}}

      assert read("var annan vecka", sv) == {@today, %Recurrence{every: 2, unit: :week}}
      assert read("varje dag", sv) == {@today, %Recurrence{unit: :day}}
      assert read("varje kvartal", sv) == {@today, %Recurrence{every: 3, unit: :month, day: 8}}
      assert read("var tredje månad", sv) == {@today, %Recurrence{every: 3, unit: :month, day: 8}}
      assert read("varje år", sv) == {@today, %Recurrence{unit: :year}}

      assert read("den 15:e varje månad", sv) ==
               {~D[2026-10-15], %Recurrence{unit: :month, day: 15}}

      assert read("den 30 varje månad", sv) ==
               {~D[2026-10-30], %Recurrence{unit: :month, day: 30}}
    end
  end

  describe "the next date" do
    test "weeks and days count from the base date" do
      assert Recurrence.next(%Recurrence{unit: :week, weekday: 1}, ~D[2026-10-12]) ==
               ~D[2026-10-19]

      assert Recurrence.next(%Recurrence{every: 2, unit: :week}, ~D[2026-10-12]) == ~D[2026-10-26]
      assert Recurrence.next(%Recurrence{every: 3, unit: :day}, ~D[2026-10-30]) == ~D[2026-11-02]
    end

    test "months keep their day, using the month's last day when it is shorter" do
      # Lotus Q&A "Monthly Recurring Dates": the 30th must not drift
      rule = %Recurrence{unit: :month, day: 30}

      dates =
        Stream.iterate(~D[2027-01-30], &Recurrence.next(rule, &1)) |> Enum.take(4)

      assert dates == [~D[2027-01-30], ~D[2027-02-28], ~D[2027-03-30], ~D[2027-04-30]]
    end

    test "quarters are three months, not six" do
      # Lotus Q&A "Quarterly Recurring Dates" and "Every Three Months"
      rule = %Recurrence{every: 3, unit: :month, day: 1}
      assert Recurrence.next(rule, ~D[2026-10-01]) == ~D[2027-01-01]
    end

    test "years, including the 29th of February" do
      assert Recurrence.next(%Recurrence{unit: :year}, ~D[2028-02-29]) == ~D[2029-02-28]
    end

    test "descriptions, as Item Properties shows them" do
      assert Recurrence.describe(%Recurrence{unit: :week, weekday: 1}) == "every Monday"

      assert Recurrence.describe(%Recurrence{every: 2, unit: :week, weekday: 5}) ==
               "every 2nd Friday"

      assert Recurrence.describe(%Recurrence{every: 3, unit: :month, day: 8}) == "every 3 months"
      assert Recurrence.describe(%Recurrence{unit: :month, day: 30}) == "the 30th of every month"
      assert Recurrence.describe(%Recurrence{unit: :day}) == "every day"
    end
  end

  describe "items" do
    test "an item with a recurring date gets the rule" do
      {db, id} = Core.add_item(Core.new_file(), "Staff meeting every Monday", @today)
      assert db.items[id].when == ~D[2026-10-12]
      assert db.items[id].recurrence == %Recurrence{unit: :week, weekday: 1}
    end

    test "marking it done makes the next one, with the same text, note and categories" do
      db = Core.new_file()
      {:ok, db, staff} = Core.add_category(db, db.main_id, "Staff")
      {db, id} = Core.add_item(db, "Status meeting every Monday", @today)
      db = db |> Core.assign(id, staff) |> Core.set_note(id, "agenda in the wiki")

      db = Core.toggle_done(db, id, ~D[2026-10-12])
      assert db.items[id].done == ~D[2026-10-12]

      [next_id] = db.item_order -- [id]
      next = db.items[next_id]
      assert next.text == "Status meeting every Monday"
      assert next.note == "agenda in the wiki"
      assert next.when == ~D[2026-10-19]
      assert next.done == nil
      assert next.recurrence == db.items[id].recurrence
      assert Database.member?(db, next_id, staff)
      # the copy comes right after the original
      assert Enum.drop_while(db.item_order, &(&1 != id)) |> Enum.take(2) == [id, next_id]
    end

    test "marking it not done again does not make another" do
      {db, id} = Core.add_item(Core.new_file(), "Pay rent the 1st of every month", @today)
      db = db |> Core.toggle_done(id, @today) |> Core.toggle_done(id, @today)
      assert length(db.item_order) == 2
      assert db.items[id].done == nil
    end

    test "bulk done makes the next ones too" do
      {db, id} = Core.add_item(Core.new_file(), "Backup every day", @today)
      db = Core.mark_done(db, id, @today)
      assert length(db.item_order) == 2
    end

    test "setting the When date explicitly to a plain date ends the recurrence" do
      {db, id} = Core.add_item(Core.new_file(), "Walk every day", @today)
      db = Core.set_date(db, id, db.special.when, ~D[2026-12-24])
      assert db.items[id].recurrence == nil
    end

    test "typing a recurring date in the When column sets the rule" do
      db = Core.new_file()
      {db, id} = Core.add_item(db, "Water the plants", @today)

      {:ok, db, :date} =
        Core.assign_by_name(db, id, db.special.when, "every other Friday", @today)

      assert db.items[id].when == ~D[2026-10-09]
      assert db.items[id].recurrence == %Recurrence{every: 2, unit: :week, weekday: 5}
    end

    test "editing the text so that it no longer recurs drops the rule" do
      {db, id} = Core.add_item(Core.new_file(), "Gym every Monday", @today)
      db = Core.edit_item(db, id, "Gym on Monday", @today)
      assert db.items[id].recurrence == nil
      assert db.items[id].when == ~D[2026-10-12]
    end
  end
end
