defmodule Agendum.Core.DatabaseTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Agendum.Fixtures
  alias Agendum.Core
  alias Agendum.Core.Database

  describe "new/1" do
    test "creates MAIN, the date categories, an initial section and view" do
      db = Database.new()

      names =
        db |> Database.hierarchy() |> Enum.map(fn {id, d} -> {db.categories[id].name, d} end)

      assert names == [
               {"MAIN", 0},
               {"Entry", 1},
               {"When", 1},
               {"Done", 1},
               {"Initial Section", 1}
             ]

      assert [%{name: "Initial View", sections: [%{category_id: section}]}] = Database.views(db)
      assert db.categories[section].name == "Initial Section"
    end
  end

  describe "hierarchy (patent FIG. 1)" do
    setup do
      db =
        with_categories(Database.new(), [
          {"C2", [], ["C3", "C4", {"C5", [], ["C9"]}, "C6"]},
          "C7",
          "C8"
        ])

      %{db: db}
    end

    test "ancestors and descendants", %{db: db} do
      assert Database.ancestors(db, cat(db, "C9")) == [cat(db, "C5"), cat(db, "C2"), db.main_id]
      assert Database.descendants(db, cat(db, "C2")) == Enum.map(~w(C3 C4 C5 C9 C6), &cat(db, &1))
    end

    test "promote moves a category up a level, after its old parent", %{db: db} do
      {:ok, db} = Database.promote(db, cat(db, "C9"))
      assert db.categories[cat(db, "C9")].parent_id == cat(db, "C2")
      assert db.categories[cat(db, "C2")].children == Enum.map(~w(C3 C4 C5 C9 C6), &cat(db, &1))
    end

    test "demote makes a category the last child of its previous sibling", %{db: db} do
      {:ok, db} = Database.demote(db, cat(db, "C7"))
      assert List.last(db.categories[cat(db, "C2")].children) == cat(db, "C7")
      assert Database.demote(db, cat(db, "C3")) == {:error, :no_previous_sibling}
    end

    test "MAIN and top-level categories cannot be promoted", %{db: db} do
      assert Database.promote(db, db.main_id) == {:error, :top_level}
      assert Database.promote(db, cat(db, "C2")) == {:error, :top_level}
      assert Database.demote(db, db.main_id) == {:error, :no_previous_sibling}
    end

    test "moving a category below itself is refused", %{db: db} do
      assert Database.move_category(db, cat(db, "C2"), cat(db, "C9"), nil) == {:error, :cycle}
    end

    test "MAIN and the date categories cannot be deleted", %{db: db} do
      assert Database.delete_category(db, db.main_id) == {:error, :protected}
      assert Database.delete_category(db, db.special.done) == {:error, :protected}
    end
  end

  describe "subsumption (patent FIG. 4)" do
    test "an item assigned to a category is a member of all its ancestors" do
      db = with_categories(Database.new(), [{"C2", [], [{"C5", [], ["C9"]}]}, "C7"])
      {db, i4} = Core.add_item(db, "I4", today(), section: cat(db, "C9"))

      assert Database.member?(db, i4, cat(db, "C9"))
      assert Database.member?(db, i4, cat(db, "C5"))
      assert Database.member?(db, i4, cat(db, "C2"))
      assert Database.member?(db, i4, db.main_id)
      refute Database.member?(db, i4, cat(db, "C7"))
      assert Database.explicit_categories(db, i4) == MapSet.new([cat(db, "C9")])
    end

    test "deleting a category removes inherited memberships as a side effect" do
      db = with_categories(Database.new(), [{"C2", [], ["C5"]}])
      {db, i6} = Core.add_item(db, "I6", today(), section: cat(db, "C5"))
      c2 = cat(db, "C2")

      {:ok, db} = Database.delete_category(db, cat(db, "C5"))

      refute Database.member?(db, i6, c2)
      assert Database.items_in(db, c2) == []
    end

    test "deleting a category removes it from view sections and columns" do
      db = with_categories(Database.new(), ["Doomed"])
      [view] = Database.views(db)

      db =
        db
        |> Core.add_section(view.id, cat(db, "Doomed"), 1)
        |> Core.add_column(view.id, cat(db, "Doomed"), {0, 0})

      {:ok, db} = Database.delete_category(db, cat(db, "Doomed"))
      [view] = Database.views(db)
      assert length(view.sections) == 1
      assert length(Agendum.Core.View.columns(view, 0)) == 1
    end
  end

  test "items keep insertion order, honouring :after" do
    db = Database.new()
    {db, a} = Database.insert_item(db, "a", today())
    {db, c} = Database.insert_item(db, "c", today())
    {db, b} = Database.insert_item(db, "b", today(), after: a)
    assert db.item_order == [a, b, c]
  end

  property "the hierarchy stays a tree under random moves" do
    check all(moves <- list_of({integer(0..7), integer(0..7)}, max_length: 30)) do
      db = with_categories(Database.new(), ~w(A B C D E F G H))
      ids = Enum.map(~w(A B C D E F G H), &cat(db, &1))

      db =
        Enum.reduce(moves, db, fn {from, to}, db ->
          case Database.move_category(db, Enum.at(ids, from), Enum.at(ids, to), nil) do
            {:ok, db} -> db
            {:error, _} -> db
          end
        end)

      # every category is reachable exactly once from MAIN, and parents agree with children
      reachable = Database.subtree(db, db.main_id)
      assert Enum.sort(reachable) == Enum.sort(Map.keys(db.categories))

      for {id, c} <- db.categories, child <- c.children do
        assert db.categories[child].parent_id == id
      end
    end
  end
end
