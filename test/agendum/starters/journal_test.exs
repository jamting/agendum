# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Starters.JournalTest do
  @moduledoc """
  The Journal starter file (R60b): Dreams, Mood, Training, Gym and Health
  as collections of one exclusive Journal family, a Today view and an
  Index, and a datebook per collection with its sums; then its rules at
  work, drawn in the TUI.
  """
  use ExUnit.Case, async: true

  import Agendum.Fixtures, only: [cat: 2]
  import Agendum.TUIHelpers

  alias Agendum.Core
  alias Agendum.Core.Database
  alias Agendum.Starters.Journal
  alias Agendum.TUI.State

  @today ~D[2026-11-04]

  setup_all do
    %{db: Journal.build()}
  end

  defp name(db, id), do: db.categories[id].name
  defp children(db, name), do: Enum.map(db.categories[cat(db, name)].children, &name(db, &1))
  defp view(db, name), do: Enum.find(Database.views(db), &(&1.name == name))

  # a line typed in Today, as a person would, on `day`
  defp log(db, text, day \\ @today), do: Core.add_item(db, text, day, section: cat(db, "Journal"))

  defp number(db, item, category, value) do
    {:ok, db} = Core.set_number(db, item, cat(db, category), value, @today)
    db
  end

  defp collection(db, item) do
    Enum.find(children(db, "Journal"), &Database.member?(db, item, cat(db, &1)))
  end

  defp show(db, name, today \\ @today) do
    state = start(db, today: today, width: 120, height: 60)
    state |> State.switch_view(view(db, name).id) |> screen()
  end

  describe "the file" do
    test "the Journal and its collections, each with what files a line there", %{db: db} do
      assert children(db, "Journal") == ~w(Dreams Mood Training Gym Health)
      assert db.categories[cat(db, "Journal")].exclusive
      assert children(db, "Training") == ["Sport"]
      assert children(db, "Gym") == ["Exercises"]
      assert children(db, "Health") == ["Symptoms"]
      # a cold can bring a headache
      refute db.categories[cat(db, "Symptoms")].exclusive
    end

    test "the numbers are numeric categories", %{db: db} do
      for n <-
            ["Vividness", "Mood 1-10", "Sleep", "Exercise", "Distance", "Minutes"] ++
              ~w(Sets Reps Weight Volume Severity),
          do: assert(db.categories[cat(db, n)].kind == :numeric, n)
    end

    test "the views: Today first, the Index, then a datebook per collection", %{db: db} do
      assert Enum.map(Database.views(db), & &1.name) ==
               ~w(Today Index Dreams Mood Training Gym Health)

      for name <- ~w(Dreams Mood Training Gym Health),
          do: assert(view(db, name).datebook.date_category == db.special.entry, name)

      assert view(db, "Mood").datebook.period == :month
      assert view(db, "Health").datebook.period == :quarter
    end

    test "how the file works is the Journal's note, shown by ♪ on Today", %{db: db} do
      assert db.categories[cat(db, "Journal")].note =~ "Index"
      assert db.items == %{}
      assert show(db, "Today") =~ "Journal"
    end

    test "starters/journal.agendum is what the code builds (run mix agendum.starters)",
         %{db: db} do
      assert {:ok, committed} = Agendum.Store.load("starters/journal.agendum")

      assert committed == db, """
      starters/journal.agendum is out of date with Agendum.Starters.Journal.
      Run `mix agendum.starters` and commit the file.
      """
    end
  end

  describe "the rules at work" do
    test "words file a line into its collection", %{db: db} do
      {db, run} = log(db, "Ran by the river")
      {db, lift} = log(db, "Bench press")
      {db, ache} = log(db, "Headache after lunch")
      {db, dream} = log(db, "Dreamt of a flood")
      {db, mood} = log(db, "Mood: calm morning")

      assert collection(db, run) == "Training"
      assert Database.member?(db, run, cat(db, "Running"))
      assert collection(db, lift) == "Gym"
      assert collection(db, ache) == "Health"
      assert collection(db, dream) == "Dreams"
      assert collection(db, mood) == "Mood"
    end

    test "Today shows today's lines; yesterday's are gone from it", %{db: db} do
      {db, _} = log(db, "Ran by the river")
      {db, _} = log(db, "Swam a mile", Date.add(@today, -1))
      today = show(db, "Today")
      assert today =~ "Ran by the river"
      refute today =~ "Swam a mile"
    end

    test "Gym sums the week: Sets and Reps and Volume in total, Weight at its most", %{db: db} do
      {db, bench} = log(db, "Bench press")
      {db, squat} = log(db, "Squat")

      db =
        db
        |> number(bench, "Sets", 3)
        |> number(bench, "Reps", 30)
        |> number(bench, "Weight", 40)
        |> number(bench, "Volume", 1200)
        |> number(squat, "Sets", 4)
        |> number(squat, "Reps", 32)
        |> number(squat, "Weight", 60)
        |> number(squat, "Volume", 1920)

      gym = show(db, "Gym")
      assert gym =~ "Bench press"
      assert gym =~ ~r/TOTAL +7 +62 +3120/
      assert gym =~ ~r/MAXIMUM +60\.0/
    end

    test "a week runs Monday to Sunday: a Saturday run is in it", %{db: db} do
      {db, _} = log(db, "Ran on Saturday", ~D[2026-11-07])
      assert show(db, "Training") =~ "Ran on Saturday"
    end

    test "Mood averages the week", %{db: db} do
      {db, a} = log(db, "Mood: tired")
      {db, b} = log(db, "Mood: calm", Date.add(@today, -1))
      db = db |> number(a, "Mood 1-10", 4) |> number(b, "Mood 1-10", 7)
      assert show(db, "Mood") =~ "5.5"
    end

    test "a week with nothing logged shows nothing", %{db: db} do
      {db, _} = log(db, "Ran by the river")
      training = show(db, "Training")
      # this month has five weeks (November 2026); only one has a line
      assert length(Regex.scan(~r/TOTAL/, training)) == 1
    end

    test "the Index lists this month's lines by collection, unused ones hidden", %{db: db} do
      {db, _} = log(db, "Ran by the river")
      {db, _} = log(db, "Headache after lunch")
      {db, _} = log(db, "Swam in October", ~D[2026-10-20])
      index = show(db, "Index")
      assert index =~ "Training"
      assert index =~ "Health"
      refute index =~ "Dreams"
      refute index =~ "Swam in October"
    end
  end
end
