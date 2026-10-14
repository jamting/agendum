defmodule Agendum.Starters.PlannerSamplesTest do
  @moduledoc """
  Sample data for the Planner (`mix agendum.starters --samples`), for
  trying the views out: realistic items, the same every time for the same
  day.
  """
  use ExUnit.Case, async: true

  import Agendum.Fixtures, only: [cat: 2, item_id: 2]
  import ExUnit.CaptureIO

  alias Agendum.Core.Database
  alias Agendum.Starters.Planner

  @today ~D[2026-10-12]

  setup_all do
    %{db: Planner.build() |> Planner.with_samples(@today)}
  end

  defp items_in(db, name),
    do: for(i <- Database.items(db), Database.member?(db, i.id, cat(db, name)), do: i.text)

  test "the same day gives the same file" do
    assert Planner.build() |> Planner.with_samples(@today) ==
             Planner.build() |> Planner.with_samples(@today)
  end

  test "dates are counted from the day given", %{db: db} do
    later = Planner.build() |> Planner.with_samples(Date.add(@today, 7))
    id = item_id(db, "Renew the software licences")
    assert db.items[id].when == @today
    assert later.items[item_id(later, "Renew the software licences")].when == Date.add(@today, 7)
  end

  test "people with notes, projects and a trip", %{db: db} do
    people = db.categories[cat(db, "People")].children
    assert length(people) >= 5
    assert Enum.all?(people, &(db.categories[&1].note =~ ~r/^Phone: .+\nCompany: .+/))
    assert length(db.categories[cat(db, "Project")].children) >= 3

    assert "Berlin conference" in Enum.map(
             db.categories[cat(db, "Report ID")].children,
             &db.categories[&1].name
           )
  end

  test "something for every view to show", %{db: db} do
    items = Database.items(db)
    assert length(items) >= 30
    # overdue, due today with a time, done, and with a note
    assert Enum.any?(items, &((&1.when && Date.before?(&1.when, @today)) and &1.done == nil))
    assert Enum.any?(items, &(&1.when == @today and &1.when_time != nil))
    assert Enum.any?(items, &(&1.done != nil))
    assert Enum.any?(items, &(&1.note != ""))

    for name <-
          ~w(Calls Meetings Mail Reading Issues Ideas High Medium Low) ++
            ["Follow up", "Unassigned", "No Priority Assigned", "No Type", "No Purpose"],
        do: assert(items_in(db, name) != [], name)
  end

  test "expenses have amounts, types and a report", %{db: db} do
    expenses =
      for i <- Database.items(db), Database.member?(db, i.id, cat(db, "Expenses")), do: i.id

    assert length(expenses) >= 6
    assert Enum.all?(expenses, &Database.number(db, &1, cat(db, "Amount")))
    assert "Hotel in Berlin, three nights" in items_in(db, "Lodging")
    assert "Hotel in Berlin, three nights" in items_in(db, "Berlin conference")
  end

  @tag :tmp_dir
  test "mix agendum.starters writes the file, with --samples a filled copy", %{tmp_dir: dir} do
    clean = Path.join(dir, "planner.agendum")
    samples = Path.join(dir, "samples.agendum")
    # (capture_io keeps the task's "Wrote …" out of the test output)
    capture_io(fn ->
      Mix.Tasks.Agendum.Starters.run(["--output", clean])
      Mix.Tasks.Agendum.Starters.run(["--samples", "--today", "2026-10-12", "--output", samples])
    end)

    assert {:ok, db} = Agendum.Store.load(clean)
    assert db.items == %{}
    assert {:ok, db} = Agendum.Store.load(samples)
    assert map_size(db.items) >= 30
  end
end
