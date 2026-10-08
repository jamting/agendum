defmodule Agenda.Core.AncestorTest do
  @moduledoc """
  An item cannot be directly assigned to both a category and one of its
  ancestors (SPEC R7c; Agenda 2.0 User's Guide, "Because an ancestor
  inherits items assigned to its descendents, Agenda does not let you
  assign an item directly to both an ancestor and its descendent").
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Agenda.Fixtures
  alias Agenda.Core
  alias Agenda.Core.Database

  defp names(db, item),
    do:
      db |> Database.explicit_categories(item) |> Enum.map(&db.categories[&1].name) |> Enum.sort()

  setup do
    db =
      with_categories(Core.new_file(), [{"Sales", [match_name: false], ["Ed", "Joan"]}, "Other"])

    {db, item} = Core.add_item(db, "x", today())
    %{db: db, item: item}
  end

  describe "assigning" do
    test "to an ancestor breaks the assignment to its descendants (the manual's rule)", %{
      db: db,
      item: item
    } do
      db = db |> Core.assign(item, cat(db, "Ed")) |> Core.assign(item, cat(db, "Joan"))
      db = Core.assign(db, item, cat(db, "Sales"))
      assert names(db, item) == ["Sales"]
    end

    test "to a descendant replaces a direct assignment to the ancestor", %{db: db, item: item} do
      db = db |> Core.assign(item, cat(db, "Sales")) |> Core.assign(item, cat(db, "Ed"))
      assert names(db, item) == ["Ed"]
      assert Database.member?(db, item, cat(db, "Sales"))
    end

    test "unrelated categories are untouched", %{db: db, item: item} do
      db = db |> Core.assign(item, cat(db, "Other")) |> Core.assign(item, cat(db, "Ed"))
      assert names(db, item) == ["Ed", "Other"]
    end

    test "a category link to an ancestor does not undo the assignment", %{db: db, item: item} do
      ed = cat(db, "Ed")
      db = Database.update_category(db, ed, &%{&1 | also_assign: [cat(db, "Sales")]})
      assert names(Core.assign(db, item, ed), item) == ["Ed"]
    end
  end

  describe "automatic assignment" do
    test "keeps the more specific category when an ancestor's name also matches", %{db: db} do
      db = Database.update_category(db, cat(db, "Sales"), &%{&1 | match_name: true})
      {db, item} = Core.add_item(db, "Sales call with Ed", today())
      assert names(db, item) == ["Ed"]
    end

    test "does not move an item up to an ancestor it already belongs to", %{db: db} do
      db = Database.update_category(db, cat(db, "Sales"), &%{&1 | match_name: true})
      {db, item} = Core.add_item(db, "quarterly numbers", today(), section: cat(db, "Joan"))
      db = Core.edit_item(db, item, "quarterly Sales numbers")
      assert names(db, item) == ["Joan"]
    end
  end

  describe "moving categories (the manual's demote example)" do
    # Design > Sue, Anna; the item is directly in Sue and Anna. Demoting Anna
    # puts it under Sue, so the item would be in both a parent and its child.
    setup do
      db = with_categories(Core.new_file(), [{"Design", [match_name: false], ["Sue", "Anna"]}])

      {db, item} =
        Core.add_item(db, "Is the project on schedule?", today(), section: cat(db, "Sue"))

      db = Core.assign(db, item, cat(db, "Anna"))
      %{db: db, item: item, anna: cat(db, "Anna"), sue: cat(db, "Sue")}
    end

    test "the conflict is reported", %{db: db, item: item, anna: anna} do
      assert Core.demote_conflicts(db, anna) == {:ok, [item]}
    end

    test "default: remove the item from the demoted category", %{
      db: db,
      item: item,
      anna: anna,
      sue: sue
    } do
      assert {:ok, db} = Core.demote(db, anna)
      assert db.categories[anna].parent_id == sue
      assert names(db, item) == ["Sue"]
    end

    test ":remove_other removes it from the conflicting parent", %{db: db, item: item, anna: anna} do
      assert {:ok, db} = Core.demote(db, anna, :remove_other)
      assert names(db, item) == ["Anna"]
    end

    test "{:new_category, name} creates it under the conflicting parent", %{
      db: db,
      item: item,
      anna: anna,
      sue: sue
    } do
      assert {:ok, db} = Core.demote(db, anna, {:new_category, "Both"})
      assert names(db, item) == ["Both"]
      assert db.categories[cat(db, "Both")].parent_id == sue
    end
  end

  property "no sequence of assignments and moves leaves an item directly in a category and its ancestor" do
    op =
      one_of([
        tuple({constant(:assign), integer(0..2), integer(0..6)}),
        tuple({constant(:move), integer(0..6), integer(0..6)}),
        tuple({constant(:promote), integer(0..6), constant(nil)}),
        tuple({constant(:demote), integer(0..6), constant(nil)})
      ])

    check all(
            ops <- list_of(op, max_length: 40),
            resolution <- member_of([:remove_moved, :remove_other, {:new_category, "Z"}])
          ) do
      db =
        with_categories(Core.new_file(), [
          {"A", [exclusive: true], ["B", {"C", [], ["D"]}]},
          {"E", [], ["F"]},
          "G"
        ])

      ids = Enum.map(~w(A B C D E F G), &cat(db, &1))

      {db, items} =
        Enum.reduce(1..3, {db, []}, fn n, {db, acc} ->
          {db, id} = Core.add_item(db, "item #{n}", today())
          {db, acc ++ [id]}
        end)

      db =
        Enum.reduce(ops, db, fn
          {:assign, i, c}, db ->
            Core.assign(db, Enum.at(items, i), Enum.at(ids, c))

          {:move, c, p}, db ->
            ok_or(db, Core.move_category(db, Enum.at(ids, c), Enum.at(ids, p), nil, resolution))

          {:promote, c, _}, db ->
            ok_or(db, Core.promote(db, Enum.at(ids, c), resolution))

          {:demote, c, _}, db ->
            ok_or(db, Core.demote(db, Enum.at(ids, c), resolution))
        end)

      for item <- items, cat_id <- Database.explicit_categories(db, item) do
        ancestors = Database.ancestors(db, cat_id)

        refute Enum.any?(ancestors, &Database.explicit?(db, item, &1)),
               "item #{item} is directly in #{db.categories[cat_id].name} and one of its ancestors"
      end

      for {id, %{exclusive: true}} <- db.categories, item <- items do
        assert length(Agenda.Core.Assign.branches(db, item, id)) <= 1
      end
    end
  end

  defp ok_or(_db, {:ok, db}), do: db
  defp ok_or(db, {:error, _}), do: db
end
