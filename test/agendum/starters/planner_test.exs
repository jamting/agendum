defmodule Agendum.Starters.PlannerTest do
  @moduledoc """
  The Activities Planner starter file (R60), as Agenda 2.0 shipped it in
  `apps\\planner`: the categories (screenshots 38-39, 74-77, 111-125 in
  `docs/reference/screens/notes.md`).
  """
  use ExUnit.Case, async: true

  import Agendum.Fixtures, only: [cat: 2, item_id: 2]

  alias Agendum.Core
  alias Agendum.Core.Database
  alias Agendum.Starters.Planner

  # built once for every test: the file is the same each time
  setup_all do
    %{db: Planner.build()}
  end

  # a category's children by name, in their order
  defp children(db, name), do: Enum.map(db.categories[cat(db, name)].children, &name(db, &1))
  defp name(db, id), do: db.categories[id].name
  defp category(db, name), do: db.categories[cat(db, name)]

  describe "categories" do
    test "the tree under MAIN, in Agenda's order (shot 111)", %{db: db} do
      assert children(db, "MAIN") == [
               "Entry",
               "When",
               "Done",
               "People",
               "Unassigned",
               "Project",
               "Miscellaneous Project",
               "Tasks",
               "Activity",
               "Miscellaneous Activity",
               "Expenses",
               "Priority",
               "No Priority Assigned",
               "Contact List",
               "Type",
               "No Type",
               "Report ID",
               "No Purpose",
               "Amount"
             ]

      assert children(db, "People") == ["Sample Person"]
      assert children(db, "Project") == ["Sample Project"]

      assert children(db, "Activity") ==
               ~w(Calls Meetings Mail Reading) ++ ["Follow up", "Issues", "Ideas"]

      assert children(db, "Priority") == ~w(High Medium Low)

      assert children(db, "Type") ==
               ~w(Lodging Breakfast Lunch Dinner Entertainment Air Transportation Miscellaneous)

      assert children(db, "Report ID") == ["Sample Trip"]
    end

    test "Priority, Type and Report ID have exclusive children; Amount is numeric", %{db: db} do
      exclusive = for {_, c} <- db.categories, c.exclusive, do: c.name
      assert Enum.sort(exclusive) == ["Priority", "Report ID", "Type"]
      assert category(db, "Amount").kind == :numeric
    end

    test "short names and Also match (shots 74, 76, 113, 119)", %{db: db} do
      assert {category(db, "Calls").short_name, category(db, "Calls").also_match} ==
               {"Phone", "Telephone"}

      assert category(db, "High").short_name == "Hi"

      assert {category(db, "Lodging").short_name, category(db, "Lodging").also_match} ==
               {"Hotel", "Motel;Inn"}

      assert category(db, "No Type").also_match == ~s("Expenses with No Type")
    end

    test "only the categories an item's text should find match their names", %{db: db} do
      assert category(db, "Calls").match_name
      assert category(db, "Lodging").match_name
      assert category(db, "Sample Person").match_name

      for name <-
            ["High", "Expenses", "No Priority Assigned", "No Type", "Unassigned"] ++
              ["Contact List", "Tasks", "Priority", "People"],
          do: refute(category(db, name).match_name, name)
    end

    test "the catch-alls' conditions and Amount's action (shots 117, 119, 121, 125)",
         %{db: db} do
      conditions = fn name ->
        Enum.map(category(db, name).conditions, fn {id, kind} -> {name(db, id), kind} end)
      end

      assert conditions.("No Priority Assigned") ==
               [{"Priority", :not_assigned}, {"Tasks", :assigned}]

      assert conditions.("Unassigned") == [{"People", :not_assigned}, {"Tasks", :assigned}]
      assert conditions.("No Type") == [{"Expenses", :assigned}, {"Type", :not_assigned}]

      # an :assign action is kept as an also-assign link
      assert category(db, "Amount").also_assign == [cat(db, "Expenses")]
    end

    test "Sample Person has a note with a phone number and a company", %{db: db} do
      assert category(db, "Sample Person").note =~ ~r/^Phone: .+\nCompany: .+/
    end

    test "no items", %{db: db} do
      assert db.items == %{}
    end
  end

  test "starters/planner.agendum is what the code builds (run mix agendum.starters)", %{db: db} do
    # compared as data, not bytes: how a map is encoded may differ between
    # OTP versions
    assert {:ok, committed} = Agendum.Store.load("starters/planner.agendum")

    assert committed == db, """
    starters/planner.agendum is out of date with Agendum.Starters.Planner.
    Run `mix agendum.starters` and commit the file.
    """
  end

  describe "the rules at work" do
    test "a task with nobody and no priority is in Unassigned and No Priority Assigned",
         %{db: db} do
      {db, _} = Core.add_item(db, "Write the agenda", ~D[2026-10-13], section: cat(db, "Tasks"))
      id = item_id(db, "Write the agenda")
      assert Database.member?(db, id, cat(db, "Unassigned"))
      assert Database.member?(db, id, cat(db, "No Priority Assigned"))

      {:ok, db, _} = Core.assign_by_name(db, id, cat(db, "Priority"), "High", ~D[2026-10-13])
      refute Database.member?(db, id, cat(db, "No Priority Assigned"))
    end

    test "text finds Calls by its short name and Lodging by Also match", %{db: db} do
      {db, _} = Core.add_item(db, "Phone the bank", ~D[2026-10-13])
      {db, _} = Core.add_item(db, "Book a motel in Lund", ~D[2026-10-13])
      assert Database.member?(db, item_id(db, "Phone the bank"), cat(db, "Calls"))
      assert Database.member?(db, item_id(db, "Book a motel in Lund"), cat(db, "Lodging"))
    end

    test "an amount puts the item in Expenses, and with no type in No Type", %{db: db} do
      {db, id} = Core.add_item(db, "Taxi to the airport", ~D[2026-10-13])
      {:ok, db} = Core.set_number(db, id, cat(db, "Amount"), 120, ~D[2026-10-13])
      assert Database.member?(db, id, cat(db, "Expenses"))
      assert Database.member?(db, id, cat(db, "No Type"))
    end
  end
end
