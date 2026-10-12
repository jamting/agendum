defmodule Agenda.Core.DatebookTest do
  @moduledoc "Datebook views (R47; User's Guide chapter 10): their slots, and which items each shows."
  use ExUnit.Case, async: true

  alias Agenda.Core
  alias Agenda.Core.{Database, Datebook, DateSettings, ViewModel}
  alias Agenda.Core.Datebook.Slot

  # Monday 12 October 2026
  @now ~N[2026-10-12 10:15:00]
  @settings %DateSettings{}

  defp slots(datebook), do: Datebook.slots(datebook, @settings, @now)
  defp spans(datebook), do: Enum.map(slots(datebook), &{&1.kind, &1.from, &1.to})

  describe "the slots of a period" do
    test "a week: a day each, from Start at to End at (Mon to Fri by default)" do
      assert spans(%Datebook{period: :week}) ==
               for(d <- 12..16, do: {:day, Date.new!(2026, 10, d), Date.new!(2026, 10, d)})

      days = %Datebook{period: :week, start_day: 7, end_day: 6} |> slots() |> Enum.map(& &1.from)
      assert hd(days) == ~D[2026-10-11]
      assert List.last(days) == ~D[2026-10-17]
    end

    test "a day: the day itself for items without a time, then the hours" do
      [untimed | hours] = slots(%Datebook{period: :day})
      assert %Slot{kind: :untimed, from: ~D[2026-10-12]} = untimed
      # Morning to Evening by default: 8:00 … 17:00
      assert hd(hours) == %Slot{
               kind: :time,
               from: ~N[2026-10-12 08:00:00],
               to: ~N[2026-10-12 09:00:00]
             }

      assert List.last(hours).from == ~N[2026-10-12 17:00:00]
      assert length(hours) == 10

      halves = %Datebook{
        period: :day,
        interval: 30,
        start_time: ~T[07:30:00],
        end_time: ~T[09:00:00]
      }

      assert Enum.map(tl(slots(halves)), &NaiveDateTime.to_time(&1.from)) ==
               [~T[07:30:00], ~T[08:00:00], ~T[08:30:00], ~T[09:00:00]]
    end

    test "a month: weeks by default, or days" do
      weeks = slots(%Datebook{period: :month})
      assert Enum.all?(weeks, &(&1.kind == :week))
      # the weeks of October 2026, Monday to Friday, the first starting before the 1st
      assert hd(weeks) |> Map.take([:from, :to]) == %{from: ~D[2026-09-28], to: ~D[2026-10-02]}
      assert List.last(weeks).from == ~D[2026-10-26]

      assert length(slots(%Datebook{period: :month, interval: :day})) == 31
    end

    test "a quarter: weeks by default, or days or months, from the file's first quarter" do
      months = slots(%Datebook{period: :quarter, interval: :month})
      assert Enum.map(months, & &1.from) == [~D[2026-10-01], ~D[2026-11-01], ~D[2026-12-01]]
      assert List.last(months).to == ~D[2026-12-31]

      # with quarters from February (Feb–Apr, May–Jul, Aug–Oct, Nov–Jan),
      # 12 October is in August to October
      feb = %{@settings | quarter_start: 2}
      [first | _] = Datebook.slots(%Datebook{period: :quarter, interval: :month}, feb, @now)
      assert first.from == ~D[2026-08-01]
    end

    test "the base date is read like any date, every time the view is shown" do
      assert hd(slots(%Datebook{period: :week, base: "next week"})).from == ~D[2026-10-19]
      assert hd(slots(%Datebook{period: :day, base: "tomorrow"})).from == ~D[2026-10-13]
      assert hd(slots(%Datebook{period: :week, base: "2026-12-24"})).from == ~D[2026-12-21]
      # unreadable: today
      assert hd(slots(%Datebook{period: :day, base: "someday"})).from == ~D[2026-10-12]
    end
  end

  describe "a datebook view" do
    setup do
      db = Core.new_file()
      when_id = db.special.when
      {:ok, db, view} = Core.add_datebook_view(db, "This week", %Datebook{period: :week})

      add = fn db, text ->
        {db, id} = Core.add_item(db, text, @now)
        {db, id}
      end

      {db, tea} = add.(db, "Tea with Pooh on Tuesday at 4pm")
      {db, picnic} = add.(db, "Picnic next Thursday")
      {db, nothing} = add.(db, "Count the lettuces")
      %{db: db, view: view, when: when_id, tea: tea, picnic: picnic, nothing: nothing}
    end

    defp texts(section), do: Enum.map(section.rows, & &1.item.text)

    test "has a section per slot, each showing the items dated in it", %{db: db, view: view} do
      sections = ViewModel.build(db, db.views[view], @now)
      assert length(sections) == 5
      assert Enum.map(sections, & &1.slot.from) == Enum.map(12..16, &Date.new!(2026, 10, &1))
      assert texts(Enum.at(sections, 1)) == ["Tea with Pooh on Tuesday at 4pm"]
      assert sections |> Enum.flat_map(&texts/1) |> length() == 1
      # every section has the Section category as its head
      assert Enum.all?(sections, &(&1.category.name == "When"))
    end

    test "shows next week's items when the base date is next week", %{db: db, view: view} do
      db = Core.set_datebook(db, view, %{db.views[view].datebook | base: "next week"}) |> elem(1)
      sections = ViewModel.build(db, db.views[view], @now)
      assert texts(Enum.at(sections, 3)) == ["Picnic next Thursday"]
    end

    test "a day view puts items by time, and those without one first", %{db: db, view: view} do
      {:ok, db} = Core.set_datebook(db, view, %Datebook{period: :day, base: "tuesday"})
      {db, _} = Core.add_item(db, "Water the haycorns on Tuesday", @now)
      sections = ViewModel.build(db, db.views[view], @now)

      assert texts(hd(sections)) == ["Water the haycorns on Tuesday"]
      four = Enum.find(sections, &(&1.slot.from == ~N[2026-10-13 16:00:00]))
      assert texts(four) == ["Tea with Pooh on Tuesday at 4pm"]
    end

    test "with an End category, an item shows in every slot until it ends",
         %{db: db, view: view, tea: tea} do
      {:ok, db, over} = Core.add_category(db, db.main_id, "Over")
      {:ok, db} = Core.make_date(db, over, @now)
      db = Core.set_date(db, tea, over, ~D[2026-10-15])
      {:ok, db} = Core.set_datebook(db, view, %{db.views[view].datebook | end_category: over})

      days = db |> ViewModel.build(db.views[view], @now) |> Enum.map(&texts/1)

      assert days == [
               [],
               ["Tea with Pooh on Tuesday at 4pm"],
               ["Tea with Pooh on Tuesday at 4pm"],
               ["Tea with Pooh on Tuesday at 4pm"],
               []
             ]
    end

    test "the Section setting shows only its items", %{db: db, view: view, tea: tea} do
      {:ok, db, visits} = Core.add_category(db, db.main_id, "Visits")

      {:ok, db} =
        Core.set_datebook(db, view, %{db.views[view].datebook | section_category: visits})

      assert db |> ViewModel.build(db.views[view], @now) |> Enum.flat_map(&texts/1) == []

      db = Core.assign(db, tea, visits)

      assert db |> ViewModel.build(db.views[view], @now) |> Enum.flat_map(&texts/1) ==
               ["Tea with Pooh on Tuesday at 4pm"]
    end

    test "an item typed into a slot gets its date and time", %{db: db, view: view, when: when_id} do
      {:ok, db} = Core.set_datebook(db, view, %Datebook{period: :day})
      slot = db.views[view].datebook |> Datebook.slots(db.date_settings, @now) |> Enum.at(3)

      {db, id} =
        Core.add_item(db, "Status meeting", @now, Datebook.entry(db.views[view].datebook, slot))

      item = db.items[id]

      assert {item.when, item.when_time, item.when_explicit} ==
               {~D[2026-10-12], ~T[10:00:00], true}

      assert Database.member?(db, id, when_id)
    end

    test "the settings must name date categories", %{db: db, view: view} do
      main = db.main_id

      assert Core.set_datebook(db, view, %{db.views[view].datebook | date_category: main}) ==
               {:error, :not_a_date_category}

      assert Core.add_datebook_view(db, "x", %Datebook{end_category: main}) ==
               {:error, :not_a_date_category}
    end

    test "deleting a category it uses falls back to When", %{db: db, view: view} do
      {:ok, db, visits} = Core.add_category(db, db.main_id, "Visits")

      {:ok, db} =
        Core.set_datebook(db, view, %{db.views[view].datebook | section_category: visits})

      {:ok, db} = Core.discard_category(db, visits)
      assert db.views[view].datebook.section_category == db.special.when
    end
  end
end
