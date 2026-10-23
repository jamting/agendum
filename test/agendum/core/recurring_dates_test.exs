defmodule Agendum.Core.RecurringDatesTest do
  @moduledoc """
  Recurring dates (R14a; User's Guide 6-10, 7-11 to 7-12): "every Monday"
  gives a When date and a rule; marking the item done makes the next one.
  Cases from Lotus's support Q&A (docs/reference/ag2qanda.txt.html) check
  that Agenda 2.0's bugs are not repeated.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.{Database, DateParser, Recurrence}
  alias Agendum.Core.DateLanguage.{English, Swedish}

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
  end

  # Where a recurring item shows (R14a; checked in Agenda 2.0, 2026-10-15
  # and 2026-10-23): on every date it recurs on within a range, counted
  # from the base date, never before it
  describe "occurrences in a range" do
    test "every day from a Friday: the Friday and every day after, nothing before" do
      rule = %Recurrence{unit: :day}

      assert Recurrence.occurrences(rule, ~D[2026-10-16], ~D[2026-10-13], ~D[2026-10-18]) ==
               [~D[2026-10-16], ~D[2026-10-17], ~D[2026-10-18]]
    end

    test "intervals are kept from the base date" do
      other_day = %Recurrence{every: 2, unit: :day}

      assert Recurrence.occurrences(other_day, ~D[2026-10-17], ~D[2026-10-26], ~D[2026-11-04]) ==
               [~D[2026-10-27], ~D[2026-10-29], ~D[2026-10-31], ~D[2026-11-02], ~D[2026-11-04]]

      # every 2nd Tuesday from 10/20: 11/3, not 10/27
      second_tuesday = %Recurrence{every: 2, unit: :week, weekday: 2}

      assert Recurrence.occurrences(
               second_tuesday,
               ~D[2026-10-20],
               ~D[2026-10-26],
               ~D[2026-11-08]
             ) ==
               [~D[2026-11-03]]
    end

    test "months keep their day across February, far from the base date" do
      rule = %Recurrence{unit: :month, day: 30}

      assert Recurrence.occurrences(rule, ~D[2026-01-30], ~D[2031-02-01], ~D[2031-03-31]) ==
               [~D[2031-02-28], ~D[2031-03-30]]
    end

    test "every quarter, and every year on the 29th of February" do
      quarter = %Recurrence{every: 3, unit: :month, day: 1}

      assert Recurrence.occurrences(quarter, ~D[2026-10-01], ~D[2027-01-01], ~D[2027-12-31]) ==
               [~D[2027-01-01], ~D[2027-04-01], ~D[2027-07-01], ~D[2027-10-01]]

      year = %Recurrence{unit: :year}

      assert Recurrence.occurrences(year, ~D[2028-02-29], ~D[2029-01-01], ~D[2032-12-31]) ==
               [~D[2029-02-28], ~D[2030-02-28], ~D[2031-02-28], ~D[2032-02-29]]
    end

    test "an empty range, or one before the base date, has none" do
      rule = %Recurrence{unit: :week, weekday: 1}
      assert Recurrence.occurrences(rule, ~D[2026-10-19], ~D[2026-10-20], ~D[2026-10-25]) == []
      assert Recurrence.occurrences(rule, ~D[2026-10-19], ~D[2026-10-01], ~D[2026-10-18]) == []
      assert Recurrence.occurrences(rule, ~D[2026-10-19], ~D[2026-10-27], ~D[2026-10-26]) == []
    end

    test "occurs?/4 with open ends, as date filters have them" do
      rule = %Recurrence{unit: :week, weekday: 1}
      assert Recurrence.occurs?(rule, ~D[2026-10-19], ~D[2027-06-01], nil)
      assert Recurrence.occurs?(rule, ~D[2026-10-19], nil, ~D[2026-10-19])
      refute Recurrence.occurs?(rule, ~D[2026-10-19], nil, ~D[2026-10-18])
      refute Recurrence.occurs?(rule, ~D[2026-10-19], ~D[2026-10-20], ~D[2026-10-25])
    end

    test "first/3: the first occurrence on or after a date" do
      rule = %Recurrence{unit: :week, weekday: 1}
      assert Recurrence.first(rule, ~D[2026-10-19], ~D[2026-11-01]) == ~D[2026-11-02]
      assert Recurrence.first(rule, ~D[2026-10-19], ~D[2026-10-01]) == ~D[2026-10-19]
    end
  end

  describe "describing" do
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
      db = db |> Core.assign(id, staff) |> Core.set_note(id, "agenda in the wiki", @today)

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

  # Editing a recurring date offers its rule and base date, so accepting it
  # keeps them (R14a; Agenda 2.0, checked 2026-10-23: ALT-F2 on "every
  # Monday" offers `every Mon (strtng 10/19/2026)`, with a time `… at
  # 9:00am`, and reads it back; ours writes the words out and the date as
  # ISO 8601, in the reader's language)
  describe "the rule offered for editing" do
    defp offered(rule, base, time \\ nil, pack \\ English),
      do: DateParser.format_recurring(rule, base, time, pack)

    test "in English" do
      monday = %Recurrence{unit: :week, weekday: 1}
      assert offered(monday, ~D[2026-10-19]) == "every Monday (starting 2026-10-19)"

      assert offered(%{monday | every: 2}, ~D[2026-10-19]) ==
               "every other Monday (starting 2026-10-19)"

      assert offered(%Recurrence{unit: :week}, ~D[2026-10-19]) ==
               "every week (starting 2026-10-19)"

      assert offered(%Recurrence{unit: :week, every: 2}, ~D[2026-10-19]) ==
               "every 2 weeks (starting 2026-10-19)"

      assert offered(%Recurrence{unit: :day, every: 3}, ~D[2026-10-19]) ==
               "every 3 days (starting 2026-10-19)"

      assert offered(%Recurrence{unit: :month, day: 30}, ~D[2026-10-30]) ==
               "the 30th of every month (starting 2026-10-30)"

      assert offered(%Recurrence{unit: :month, every: 3, day: 1}, ~D[2027-01-01]) ==
               "every 3 months (starting 2027-01-01)"

      assert offered(%Recurrence{unit: :year}, ~D[2027-03-01]) ==
               "every year (starting 2027-03-01)"

      assert offered(monday, ~D[2026-10-19], ~T[09:00:00]) ==
               "every Monday (starting 2026-10-19) at 9:00am"

      assert offered(monday, ~D[2026-10-19], ~T[14:30:00]) ==
               "every Monday (starting 2026-10-19) at 2:30pm"
    end

    test "in Swedish" do
      assert offered(%Recurrence{unit: :week, weekday: 1}, ~D[2026-10-19], nil, Swedish) ==
               "varje måndag (från 2026-10-19)"

      assert offered(%Recurrence{unit: :week, weekday: 5, every: 2}, ~D[2026-10-23], nil, Swedish) ==
               "varannan fredag (från 2026-10-23)"

      assert offered(%Recurrence{unit: :month, every: 3, day: 1}, ~D[2027-01-01], nil, Swedish) ==
               "var tredje månad (från 2027-01-01)"

      assert offered(%Recurrence{unit: :month, day: 30}, ~D[2026-10-30], nil, Swedish) ==
               "den 30:e varje månad (från 2026-10-30)"

      assert offered(%Recurrence{unit: :month, day: 1}, ~D[2026-11-01], nil, Swedish) ==
               "den 1:a varje månad (från 2026-11-01)"

      assert offered(%Recurrence{unit: :year, every: 2}, ~D[2027-03-01], nil, Swedish) ==
               "vartannat år (från 2027-03-01)"

      assert offered(%Recurrence{unit: :day}, ~D[2026-10-19], ~T[09:00:00], Swedish) ==
               "varje dag (från 2026-10-19) kl 09:00"
    end

    test "each pack reads its own phrase back as the same rule, base date and time" do
      cases = [
        {%Recurrence{unit: :week, weekday: 1}, ~D[2026-10-19], nil},
        {%Recurrence{unit: :week, weekday: 3, every: 2}, ~D[2026-11-04], ~T[07:15:00]},
        {%Recurrence{unit: :week, every: 2}, ~D[2026-10-20], nil},
        {%Recurrence{unit: :day}, ~D[2026-10-16], ~T[17:30:00]},
        {%Recurrence{unit: :day, every: 3}, ~D[2026-10-16], nil},
        {%Recurrence{unit: :month, day: 30}, ~D[2026-10-30], nil},
        {%Recurrence{unit: :month, day: 1, every: 3}, ~D[2027-01-01], nil},
        {%Recurrence{unit: :year}, ~D[2028-02-29], nil},
        {%Recurrence{unit: :year, every: 2}, ~D[2027-03-01], ~T[12:00:00]}
      ]

      for pack <- [English, Swedish], {rule, base, time} <- cases do
        text = offered(rule, base, time, pack)

        assert DateParser.parse_recurring(text, @now, languages: [pack]) ==
                 {:ok, base, time, rule},
               "#{inspect(pack)}: #{text}"
      end
    end

    test "Agenda's own phrase is read too" do
      assert read("every Mon (strtng 10/19/2026)") ==
               {~D[2026-10-19], %Recurrence{unit: :week, weekday: 1}}

      assert DateParser.parse_recurring("every Mon (strtng 10/26/2026) at 9:00am", @now) ==
               {:ok, ~D[2026-10-26], ~T[09:00:00], %Recurrence{unit: :week, weekday: 1}}
    end

    test "a start that is not on the rule's day moves to its next one" do
      assert read("every Monday (starting 2026-10-20)") ==
               {~D[2026-10-26], %Recurrence{unit: :week, weekday: 1}}

      assert read("the 15th of every month (starting 2026-10-20)") ==
               {~D[2026-11-15], %Recurrence{unit: :month, day: 15}}
    end

    test "a rule a pack cannot say, and a date that does not recur, are not offered or read" do
      # "var tredje måndag" has no English words
      assert offered(%Recurrence{unit: :week, weekday: 1, every: 3}, ~D[2026-10-19]) == nil
      assert offered(%Recurrence{unit: :day, every: 6}, ~D[2026-10-19], nil, Swedish) == nil
      assert read("tomorrow (starting 2026-10-19)") == :error
    end
  end
end
