defmodule Agenda.Core.MoveCategoryTest do
  @moduledoc """
  Moving a category (promote, demote, move under a new parent) must not put
  an item in two branches of a mutually exclusive family (SPEC R7b; Agenda
  2.0 User's Guide, "Resolving Conflicts When Promoting/Demoting Categories").
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Agenda.Fixtures
  alias Agenda.Core
  alias Agenda.Core.Database

  defp names(db, item),
    do:
      db |> Database.explicit_categories(item) |> Enum.map(&db.categories[&1].name) |> Enum.sort()

  describe "promoting (the manual's example)" do
    # Staff has exclusive children; Design contains Sue and Anna.
    setup do
      db =
        with_categories(Core.new_file(), [
          {"Staff", [exclusive: true, match_name: false],
           [{"Design", [match_name: false], ["Sue", "Anna"]}, "Sales"]}
        ])

      {db, item} = Core.add_item(db, "Is project on schedule?", today(), section: cat(db, "Sue"))
      db = Core.assign(db, item, cat(db, "Anna"))
      %{db: db, item: item, anna: cat(db, "Anna")}
    end

    test "conflicts are reported before moving", %{db: db, item: item, anna: anna} do
      assert Core.promote_conflicts(db, anna) == {:ok, [item]}
    end

    test "default: remove the item from the promoted category", %{db: db, item: item, anna: anna} do
      assert {:ok, db} = Core.promote(db, anna)
      assert db.categories[anna].parent_id == cat(db, "Staff")
      assert names(db, item) == ["Sue"]
    end

    test ":remove_other removes it from the conflicting category instead", %{
      db: db,
      item: item,
      anna: anna
    } do
      assert {:ok, db} = Core.promote(db, anna, :remove_other)
      assert names(db, item) == ["Anna"]
    end

    test "{:new_category, name} moves it to a new child of the exclusive family", %{
      db: db,
      item: item,
      anna: anna
    } do
      assert {:ok, db} = Core.promote(db, anna, {:new_category, "Both"})
      assert names(db, item) == ["Both"]
      assert db.categories[cat(db, "Both")].parent_id == cat(db, "Staff")
    end

    test "a bad new name refuses the whole move", %{db: db, anna: anna} do
      assert Core.promote(db, anna, {:new_category, "sales"}) == {:error, :duplicate}
      assert Core.promote(db, anna, {:new_category, ""}) == {:error, :empty}
    end
  end

  describe "demoting and moving" do
    setup do
      db =
        with_categories(Core.new_file(), [
          {"Priority", [exclusive: true, match_name: false], ["High", "Low"]},
          "Urgent"
        ])

      {db, item} = Core.add_item(db, "fix the roof", today(), section: cat(db, "Urgent"))
      db = Core.assign(db, item, cat(db, "High"))
      %{db: db, item: item, urgent: cat(db, "Urgent"), priority: cat(db, "Priority")}
    end

    test "demoting Urgent under Priority resolves the clash with High", %{
      db: db,
      item: item,
      urgent: urgent,
      priority: priority
    } do
      assert Core.demote_conflicts(db, urgent) == {:ok, [item]}
      assert {:ok, db} = Core.demote(db, urgent)
      assert db.categories[urgent].parent_id == priority
      assert names(db, item) == ["High"]
    end

    test "move_category applies the same rules", %{
      db: db,
      item: item,
      urgent: urgent,
      priority: priority
    } do
      assert Core.move_conflicts(db, urgent, priority, nil) == {:ok, [item]}
      assert {:ok, db} = Core.move_category(db, urgent, priority, nil, :remove_other)
      assert names(db, item) == ["Urgent"]
    end

    test "moves without conflicts are unchanged", %{
      db: db,
      item: item,
      urgent: urgent,
      priority: priority
    } do
      assert Core.move_conflicts(db, urgent, db.main_id, :first) == {:ok, []}
      assert {:ok, moved} = Core.move_category(db, urgent, db.main_id, :first)
      assert hd(moved.categories[db.main_id].children) == urgent
      assert names(moved, item) == ["High", "Urgent"]

      # Low is in the same exclusive family as High, so that move does clash
      assert Core.move_conflicts(db, urgent, cat(db, "Low"), nil) == {:ok, [item]}
      assert priority
    end

    test "invalid moves report the usual errors", %{db: db, priority: priority} do
      assert Core.move_conflicts(db, priority, cat(db, "High"), nil) == {:error, :cycle}
      assert Core.move_category(db, priority, cat(db, "High"), nil) == {:error, :cycle}
      assert Core.promote_conflicts(db, priority) == {:error, :top_level}
    end
  end

  property "no sequence of moves breaks mutual exclusion (invariant 5)" do
    names = ~w(A B C D E F G)

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
          {"A", [exclusive: true], ["B", "C"]},
          {"D", [exclusive: true], ["E"]},
          "F",
          "G"
        ])

      ids = Enum.map(names, &cat(db, &1))

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

      for {id, %{exclusive: true}} <- db.categories, item <- items do
        assert length(Agenda.Core.Assign.branches(db, item, id)) <= 1
      end
    end
  end

  # a {:new_category, "Z"} resolution fails once Z exists in that family; the move is then refused
  defp ok_or(_db, {:ok, db}), do: db
  defp ok_or(db, {:error, _}), do: db
end
