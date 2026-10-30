# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.CopyConditionsTest do
  @moduledoc """
  Copy and clear a category's conditions and actions (R15f; Agenda's
  ALT-F9 CPY C/A and ALT-F8 CLR C/A in the category manager; Help "Copy
  Conditions/Actions"; checked in Agenda 2.0, 2026-10-26).
  """
  use ExUnit.Case, async: true

  alias Agendum.Core

  @today ~D[2026-10-26]

  defp file do
    db = Core.new_file()
    {:ok, db, people} = Core.add_category(db, db.main_id, "People")
    {:ok, db, north} = Core.add_category(db, db.main_id, "North")
    {:ok, db, south} = Core.add_category(db, db.main_id, "South")
    {:ok, db, new} = Core.add_category(db, db.main_id, "New")
    {:ok, db, fred} = Core.add_category(db, people, "Fred")
    {:ok, db, barney} = Core.add_category(db, people, "Barney")
    {:ok, db} = Core.add_condition(db, fred, north, :assigned)
    {:ok, db} = Core.add_condition(db, barney, south, :assigned)
    {:ok, db} = Core.set_action(db, barney, new, :assign, @today)
    %{db: db, fred: fred, barney: barney, north: north, south: south, new: new}
  end

  setup do: file()

  defp run!(db, command) do
    {:ok, db, _} = Core.run(db, command, @today)
    db
  end

  test "copying conditions replaces the target's conditions and keeps its actions", c do
    db = run!(c.db, {:copy_conditions_actions, c.fred, c.barney, :conditions})
    barney = db.categories[c.barney]
    assert barney.conditions == [{c.north, :assigned}]
    assert barney.also_assign == [c.new]
    # the source is left as it was
    assert db.categories[c.fred].conditions == [{c.north, :assigned}]
  end

  test "copying actions replaces the target's actions and keeps its conditions", c do
    db = run!(c.db, {:copy_conditions_actions, c.barney, c.fred, :actions})
    fred = db.categories[c.fred]
    assert fred.also_assign == [c.new]
    assert fred.conditions == [{c.north, :assigned}]
  end

  test "copying both replaces both", c do
    db = run!(c.db, {:copy_conditions_actions, c.barney, c.fred, :both})
    fred = db.categories[c.fred]
    assert fred.conditions == [{c.south, :assigned}]
    assert fred.also_assign == [c.new]
  end

  test "a condition or action on the target itself is not copied to it", c do
    db = run!(c.db, {:copy_conditions_actions, c.barney, c.south, :both})
    south = db.categories[c.south]
    assert south.conditions == []
    assert south.also_assign == [c.new]
  end

  test "a category cannot copy to itself", c do
    assert Core.run(c.db, {:copy_conditions_actions, c.fred, c.fred, :both}, @today) ==
             {:error, :self}
  end

  test "clearing takes the conditions, the actions, or both", c do
    only_conditions = run!(c.db, {:clear_conditions_actions, c.barney, :conditions})
    assert only_conditions.categories[c.barney].conditions == []
    assert only_conditions.categories[c.barney].also_assign == [c.new]

    only_actions = run!(c.db, {:clear_conditions_actions, c.barney, :actions})
    assert only_actions.categories[c.barney].also_assign == []
    assert only_actions.categories[c.barney].conditions == [{c.south, :assigned}]

    both = run!(c.db, {:clear_conditions_actions, c.barney, :both})
    assert both.categories[c.barney].conditions == []
    assert both.categories[c.barney].also_assign == []
  end

  test "what a category has to copy or clear", c do
    assert Core.conditions_and_actions(c.db, c.barney) == :both
    assert Core.conditions_and_actions(c.db, c.fred) == :conditions
    assert Core.conditions_and_actions(c.db, c.new) == nil
  end
end
