# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.CategoryStatisticsTest do
  @moduledoc """
  Category Properties ▸ Statistics (Agenda's Category Statistics box):
  how much of the file uses a category.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.Database

  @today ~D[2026-10-08]

  setup do
    db = Core.new_file(view_name: "Activities", section_name: "Calls")
    {:ok, db, people} = Core.add_category(db, db.main_id, "People")
    {:ok, db, _} = Core.add_category(db, people, "Anna")
    {:ok, db, _} = Core.add_category(db, people, "Daniel")
    {:ok, db, urgent} = Core.add_category(db, db.main_id, "Urgent")
    %{db: db, people: people, urgent: urgent, calls: hd(Database.find_categories(db, "Calls"))}
  end

  test "a new category is used nowhere", %{db: db, urgent: urgent} do
    assert Database.category_statistics(db, urgent) == %{
             items: 0,
             children: 0,
             section_heads: 0,
             view_filters: 0,
             conditions: 0,
             actions: 0
           }
  end

  test "items, children and section heads", %{db: db, people: people, calls: calls} do
    {db, _} = Core.add_item(db, "Call Anna", @today, section: calls)
    {db, _} = Core.add_item(db, "Call Daniel", @today, section: calls)
    [view] = Database.views(db)
    db = Core.add_section(db, view.id, people, 1)

    assert %{items: 2, section_heads: 1} = Database.category_statistics(db, calls)
    assert %{children: 2, section_heads: 1} = Database.category_statistics(db, people)
  end

  test "views filtered on it, and conditions and actions that name it",
       %{db: db, people: people, urgent: urgent, calls: calls} do
    [view] = Database.views(db)
    {:ok, db} = Core.cycle_filter(db, view.id, :view, urgent)
    {:ok, db} = Core.add_condition(db, calls, urgent, :assigned)
    {:ok, db} = Core.add_condition(db, people, urgent, :not_assigned)
    db = Core.toggle_also_assign(db, calls, urgent)

    assert %{view_filters: 1, conditions: 2, actions: 1} =
             Database.category_statistics(db, urgent)
  end
end
