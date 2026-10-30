# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.CoreTest do
  use ExUnit.Case, async: true

  import Agendum.Fixtures
  alias Agendum.Core
  alias Agendum.Core.{Database, ViewModel}

  describe "assign_by_name/5 (typing into a column, claims 3 and 6)" do
    setup do
      db =
        with_categories(Core.new_file(), [
          {"Priority", [exclusive: true], ["High", "Medium", "Low"]}
        ])

      {db, item} = Core.add_item(db, "an item", today())
      %{db: db, item: item, priority: cat(db, "Priority")}
    end

    test "exact names are used", %{db: db, item: item, priority: p} do
      assert {:ok, db, id} = Core.assign_by_name(db, item, p, "medium", today())
      assert id == cat(db, "Medium")
    end

    test "unique prefixes are completed", %{db: db, item: item, priority: p} do
      assert {:ok, db, id} = Core.assign_by_name(db, item, p, "Hi", today())
      assert id == cat(db, "High")
    end

    test "unknown names create a new child of the column head", %{db: db, item: item, priority: p} do
      assert {:ok, db, id} = Core.assign_by_name(db, item, p, "Urgent", today())
      assert db.categories[id].parent_id == p
      assert Database.member?(db, item, id)
    end

    test "date columns parse dates", %{db: db, item: item} do
      assert {:ok, db, :date} =
               Core.assign_by_name(db, item, db.special.when, "tomorrow", today())

      assert db.items[item].when == ~D[2026-10-09]

      assert {:error, :invalid_date} =
               Core.assign_by_name(db, item, db.special.when, "soonish", today())
    end
  end

  describe "the view model" do
    test "the patent's sample view" do
      db = Agendum.Sample.build(today())
      [view] = Database.views(db)
      [section] = ViewModel.build(db, view)

      assert section.category.name == "Calls"

      assert Enum.map(section.rows, & &1.cells) == [
               # "...before the end of the month."
               ["10/31/26", "Medium", ""],
               ["", "High", "Anna Lasky"],
               # "...this Tuesday." (this week's Tuesday, R14)
               ["10/06/26", "Low", "Abigail Scheer"],
               ["", "Medium", "Abigail Scheer"],
               ["", "Medium", "Daniel Fiske"]
             ]
    end

    test "items in subcategories appear as inherited, and can be hidden" do
      db = with_categories(Core.new_file(), [{"Work", [], ["Calls"]}])
      [view] = Database.views(db)
      db = Core.add_section(db, view.id, cat(db, "Work"), 0)
      {db, _} = Core.add_item(db, "ring Bob", today(), section: cat(db, "Calls"))

      [work | _] = ViewModel.build(db, Database.view(db, view.id))
      assert [%{inherited: true}] = work.rows

      db = Core.toggle_view_option(db, view.id, :hide_inherited)
      [work | _] = ViewModel.build(db, Database.view(db, view.id))
      assert work.rows == []
    end

    test "done items can be hidden" do
      db = Core.new_file()
      [view] = Database.views(db)
      [%{category_id: section}] = view.sections
      {db, item} = Core.add_item(db, "finish", today(), section: section)
      db = db |> Core.toggle_done(item, today()) |> Core.toggle_view_option(view.id, :hide_done)

      assert [%{rows: []}] = ViewModel.build(db, Database.view(db, view.id))
    end

    test "childless column heads show a star" do
      db = with_categories(Core.new_file(), ["Urgent"])
      [view] = Database.views(db)
      db = Core.add_column(db, view.id, cat(db, "Urgent"), {0, 0})
      [%{category_id: section}] = view.sections
      {db, _} = Core.add_item(db, "Urgent: fix roof", today(), section: section)

      assert [%{rows: [%{cells: ["*", ""]}]}] = ViewModel.build(db, Database.view(db, view.id))
    end
  end

  test "removing an item from a section breaks the assignment" do
    db = Core.new_file()
    [%{sections: [%{category_id: section}]}] = Database.views(db)
    {db, item} = Core.add_item(db, "x", today(), section: section)

    db = Core.remove_from_category(db, item, section)
    assert Database.items_in(db, section) == []
    assert Database.item(db, item)
  end

  test "category names must be unique among siblings" do
    db = Core.new_file()
    assert {:error, :duplicate} = Core.add_category(db, db.main_id, "when")
  end

  describe "operations used by the TUI" do
    setup do
      db = with_categories(Core.new_file(), [{"Work", [], ["Calls"]}, "Home"])
      %{db: db, work: cat(db, "Work"), calls: cat(db, "Calls"), home: cat(db, "Home")}
    end

    test "toggle_assignment removes only the explicit link, or assigns", %{
      db: db,
      home: home,
      calls: calls
    } do
      {db, item} = Core.add_item(db, "x", today(), section: calls)
      db = Core.toggle_assignment(db, item, home)
      assert Database.explicit?(db, item, home)

      db = Core.toggle_assignment(db, item, home)
      refute Database.explicit?(db, item, home)
      assert Database.explicit?(db, item, calls)
    end

    test "toggle_assignment on an ancestor follows R7c", %{db: db, work: work, calls: calls} do
      {db, item} = Core.add_item(db, "x", today(), section: calls)
      db = Core.toggle_assignment(db, item, work)
      assert Database.explicit_categories(db, item) == MapSet.new([work])
    end

    test "move_item reassigns between sections and reorders", %{db: db, calls: calls, home: home} do
      {db, a} = Core.add_item(db, "a", today(), section: home)
      {db, b} = Core.add_item(db, "b", today(), section: calls)

      db = Core.move_item(db, b, calls, home, after: nil)
      assert Database.member?(db, b, home)
      refute Database.member?(db, b, calls)
      assert db.item_order == [a, b]

      db = Core.move_item(db, a, home, home, after: b)
      assert db.item_order == [b, a]
    end

    test "move_item never links MAIN", %{db: db, calls: calls} do
      {db, item} = Core.add_item(db, "x", today(), section: calls)
      db = Core.move_item(db, item, calls, db.main_id)
      assert Database.explicit_categories(db, item) == MapSet.new()
    end

    test "set_short_name trims, and blank clears", %{db: db, home: home} do
      db = Core.set_short_name(db, home, "  hm ")
      assert db.categories[home].short_name == "hm"
      assert Core.set_short_name(db, home, "  ").categories[home].short_name == nil
    end

    test "set_category_note", %{db: db, home: home} do
      assert Core.set_category_note(db, home, "keys").categories[home].note == "keys"
    end

    test "toggle_also_assign adds and removes a link", %{db: db, home: home, work: work} do
      db = Core.toggle_also_assign(db, home, work)
      assert db.categories[home].also_assign == [work]
      assert Core.toggle_also_assign(db, home, work).categories[home].also_assign == []
    end

    test "move_view reorders views, clamping the index", %{db: db, home: home} do
      [first] = db.view_order
      {db, second} = Core.add_view(db, "Second", [home])

      assert Core.move_view(db, second, 0).view_order == [second, first]
      assert Core.move_view(db, first, 99).view_order == [second, first]
      assert Core.move_view(db, second, -5).view_order == [second, first]
    end

    test "set_section_category changes a section head", %{db: db, home: home} do
      [view] = Database.views(db)
      db = Core.set_section_category(db, view.id, 0, home)
      assert [%{category_id: ^home}] = Database.view(db, view.id).sections
    end
  end
end
