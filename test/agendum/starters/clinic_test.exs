# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Starters.ClinicTest do
  @moduledoc """
  The Hundred Acre clinic (`agendum --clinic`): Christopher Robin's file,
  mid-work. An Easter egg, and a showcase, so every view must have
  something in it, and the story must hold together.
  """
  use ExUnit.Case, async: true

  import Agendum.Fixtures, only: [cat: 2, item_id: 2]
  import ExUnit.CaptureIO

  alias Agendum.Core.Database
  alias Agendum.Starters.Clinic
  alias Agendum.TUI.{Render, State}

  @today ~D[2026-10-14]

  setup_all do
    %{db: Clinic.build(@today)}
  end

  defp items_in(db, name),
    do: for(i <- Database.items(db), Database.member?(db, i.id, cat(db, name)), do: i.text)

  defp item(db, text), do: db.items[item_id(db, text)]

  test "the same day gives the same file" do
    assert Clinic.build(@today) == Clinic.build(@today)
  end

  test "bigger than the Planner's sample data", %{db: db} do
    assert length(Database.items(db)) > 60
  end

  test "a client's name in a text assigns the item to the client; Wol is Owl", %{db: db} do
    assert "Session with Pooh: the honey diary" in items_in(db, "Pooh")
    assert "Call Owl's literacy tutor to confirm the lessons" in items_in(db, "Owl")
    assert "Family session with Kanga, Roo and Tigger" in items_in(db, "Roo")
    assert "Family session with Kanga, Roo and Tigger" in items_in(db, "Tigger")
  end

  test "no text set a date by itself: only the dates given are there", %{db: db} do
    undated = ["Fix the sign on the door, and politely decline Owl's offer to write it"]
    for text <- undated, do: assert(item(db, text).when == nil, text)

    for i <- Database.items(db), i.when != nil do
      assert Date.diff(i.when, @today) in -14..14, "#{i.text}: #{i.when}"
    end

    # no time came from a text either: only sessions have times
    for i <- Database.items(db),
        i.when_time != nil,
        do: assert(i.text in items_in(db, "Sessions"), i.text)
  end

  test "today's sessions, with times, and the rest of the week", %{db: db} do
    today = for i <- Database.items(db), i.when == @today and i.when_time != nil, do: i.text
    assert length(today) >= 5
    assert "Session with Pooh: the honey diary" in today
    assert item(db, "Session with Pooh: the honey diary").when_time == ~T[11:30:00]
  end

  test "every client has a treatment plan, diagnoses and notes", %{db: db} do
    plans = items_in(db, "Treatment plans")

    for client <- ~w(Pooh Piglet Eeyore Owl Rabbit Tigger Kanga Roo) do
      assert Enum.any?(plans, &(&1 in items_in(db, client))), client
      assert db.categories[cat(db, client)].note != "", client
    end

    assert "Treatment plan for Pooh" in items_in(db, "Honey use disorder")
    # Owl is not a narcissist; neither, here, is Rabbit
    assert "Treatment plan for Rabbit" in items_in(db, "Need for control")
    assert "Treatment plan for Owl" in items_in(db, "Reading difficulty")
  end

  test "some clients improving, some not", %{db: db} do
    for progress <- ["Improving", "Holding steady", "Setback"],
        do: assert(items_in(db, progress) != [], progress)
  end

  test "a session with no client is caught by the conditions", %{db: db} do
    assert items_in(db, "No client") == ["Session booked by a Mr. Sanders"]
  end

  test "a fee files the item under Fees; some paid in kind", %{db: db} do
    fees = items_in(db, "Fees")
    assert "Session with Pooh: the honey diary" in fees
    assert Enum.all?(fees, &Database.number(db, item_id(db, &1), cat(db, "Fee")))
    assert "Pooh paid in honey" in items_in(db, "Paid in kind")
  end

  test "done, overdue and undated items", %{db: db} do
    items = Database.items(db)
    assert Enum.any?(items, &(&1.done != nil))

    assert Enum.any?(
             items,
             &(&1.when != nil and Date.before?(&1.when, @today) and &1.done == nil)
           )

    assert Enum.any?(items, &(&1.when == nil))
  end

  test "every view shows something, whatever the day of the week" do
    for today <- Date.range(@today, Date.add(@today, 6)) do
      db = Clinic.build(today)

      for view <- Database.views(db) do
        state = State.new(db, today: today, now: NaiveDateTime.new!(today, ~T[09:00:00]))
        state = %{state | view_id: view.id, width: 100, height: 40}
        assert Render.render(state) |> Agendum.TUI.Terminal.Draw.to_text() =~ view.name

        assert Enum.any?(Agendum.TUI.Layout.rows(state), &(&1.kind == :item)),
               "#{view.name} shows no items on #{Date.day_of_week(today)}"
      end
    end
  end

  @tag :tmp_dir
  test "mix agendum.starters --clinic writes it", %{tmp_dir: dir} do
    path = Path.join(dir, "clinic.agendum")
    # (capture_io keeps the task's "Wrote …" out of the test output)
    capture_io(fn ->
      Mix.Tasks.Agendum.Starters.run(["--clinic", "--today", "2026-10-14", "--output", path])
    end)

    assert {:ok, db} = Agendum.Store.load(path)
    assert db == Clinic.build(@today)
  end
end
