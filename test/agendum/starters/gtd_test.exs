# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Starters.GTDTest do
  @moduledoc """
  The Getting Things Done starter file (R60a): an Inbox family whose
  lists are the contexts, Waiting For and Someday/Maybe, Projects, six
  views and one welcome item; then its rules at work, drawn in the TUI.
  """
  use ExUnit.Case, async: true

  import Agendum.Fixtures, only: [cat: 2]
  import Agendum.TUIHelpers

  alias Agendum.Core
  alias Agendum.Core.Database
  alias Agendum.Starters.GTD
  alias Agendum.TUI.State

  @today ~D[2026-11-02]

  setup_all do
    %{db: GTD.build()}
  end

  defp name(db, id), do: db.categories[id].name
  defp children(db, name), do: Enum.map(db.categories[cat(db, name)].children, &name(db, &1))
  defp view(db, name), do: Enum.find(Database.views(db), &(&1.name == name))
  defp sections(db, name), do: Enum.map(view(db, name).sections, &name(db, &1.category_id))

  defp columns(db, name) do
    for s <- view(db, name).sections,
        do: Enum.map(s.columns, &(&1.title || name(db, &1.category_id)))
  end

  # the item typed in the Inbox view, as a person would
  defp type_in_inbox(db, text, today \\ @today) do
    Core.add_item(db, text, today, section: cat(db, "Inbox"))
  end

  defp lists(db, item) do
    for name <- ["Inbox", "Contexts"] ++ children(db, "Contexts") ++ ["Waiting For"],
        Database.member?(db, item, cat(db, name)),
        do: name
  end

  defp show(db, name, today \\ @today) do
    state = start(db, today: today, width: 120, height: 50)
    state |> State.switch_view(view(db, name).id) |> screen()
  end

  describe "the file" do
    test "the categories: the Inbox family and its lists, then Projects", %{db: db} do
      assert Enum.filter(children(db, "MAIN"), &(&1 in ["Inbox", "Projects"])) == [
               "Inbox",
               "Projects"
             ]

      assert children(db, "Inbox") == ["Contexts", "Waiting For", "Someday/Maybe"]

      assert children(db, "Contexts") ==
               ~w(@Anywhere @Calls @Computer @Errands @Home @Office)

      assert children(db, "Projects") == ["Sample Project"]

      # one list for each item, one context in Contexts
      assert db.categories[cat(db, "Inbox")].exclusive
      assert db.categories[cat(db, "Contexts")].exclusive
    end

    test "the views, in the order of the method", %{db: db} do
      assert Enum.map(Database.views(db), & &1.name) ==
               ["Inbox", "Next Actions", "Projects", "Waiting For", "Someday/Maybe"] ++
                 ["Weekly Review"]

      assert sections(db, "Next Actions") == ~w(@Anywhere @Calls @Computer @Errands @Home @Office)
      assert sections(db, "Weekly Review") == ["Inbox", "Waiting For", "Someday/Maybe", "Done"]
      assert columns(db, "Inbox") == [["Contexts", "Projects", "When"]]
      assert columns(db, "Waiting For") == [["Entry", "Projects"]]
    end

    test "one item, the welcome, with a note on how the file works", %{db: db} do
      assert [item] = Map.values(db.items)
      assert item.text =~ "Welcome"
      assert item.note =~ "Weekly Review"
      assert lists(db, item.id) == ["Inbox"]
      assert show(db, "Inbox") =~ "Welcome"
    end

    test "starters/gtd.agendum is what the code builds (run mix agendum.starters)", %{db: db} do
      assert {:ok, committed} = Agendum.Store.load("starters/gtd.agendum")

      assert committed == db, """
      starters/gtd.agendum is out of date with Agendum.Starters.GTD.
      Run `mix agendum.starters` and commit the file.
      """
    end
  end

  describe "the rules at work" do
    test "an item filed by its words leaves the Inbox by itself", %{db: db} do
      {db, call} = type_in_inbox(db, "Call Anna about the budget")
      {db, milk} = type_in_inbox(db, "Buy milk")
      {db, wait} = type_in_inbox(db, "Waiting for Bob's reply")

      assert lists(db, call) == ["Inbox", "Contexts", "@Calls"]
      assert lists(db, milk) == ["Inbox", "Contexts", "@Errands"]
      assert lists(db, wait) == ["Inbox", "Waiting For"]

      inbox = show(db, "Inbox")
      refute inbox =~ "Call Anna"
      refute inbox =~ "Buy milk"
      refute inbox =~ "Waiting for Bob"
      assert show(db, "Next Actions") =~ "Call Anna about the budget"
      assert show(db, "Waiting For") =~ "Waiting for Bob's reply"
    end

    test "an item given a context by hand leaves the Inbox", %{db: db} do
      {db, gate} = type_in_inbox(db, "Fix the gate")
      assert show(db, "Inbox") =~ "Fix the gate"

      db = Core.assign(db, gate, cat(db, "@Home"), @today)
      assert lists(db, gate) == ["Inbox", "Contexts", "@Home"]
      refute show(db, "Inbox") =~ "Fix the gate"

      # a list replaces the other: from @Home to Someday/Maybe
      db = Core.assign(db, gate, cat(db, "Someday/Maybe"), @today)
      refute Database.member?(db, gate, cat(db, "@Home"))
      refute show(db, "Next Actions") =~ "Fix the gate"
      assert show(db, "Someday/Maybe") =~ "Fix the gate"
    end

    test "a project without a next action shows as an empty section", %{db: db} do
      projects = show(db, "Projects")
      assert projects =~ "Sample Project"

      {db, step} = type_in_inbox(db, "Email the plan to Owl")
      db = Core.assign(db, step, cat(db, "Sample Project"), @today)
      assert show(db, "Projects") =~ "Email the plan to Owl"
      assert lists(db, step) == ["Inbox", "Contexts", "@Computer"]
    end

    test "the Weekly Review: waiting a week, and done in the last week", %{db: db} do
      {db, old} = type_in_inbox(db, "Waiting for the plumber's quote", Date.add(@today, -10))
      {db, _new} = type_in_inbox(db, "Waiting for the new keys", Date.add(@today, -2))
      {db, done} = type_in_inbox(db, "Buy stamps")
      db = Core.toggle_done(db, done, @today)

      review = show(db, "Weekly Review")
      assert review =~ "Waiting for the plumber's quote"
      refute review =~ "Waiting for the new keys"
      assert review =~ "Buy stamps"
      assert Database.member?(db, old, cat(db, "Waiting For"))

      # done, it leaves the action views
      refute show(db, "Next Actions") =~ "Buy stamps"
    end
  end
end
