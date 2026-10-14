defmodule Agendum.Core.PromoteTest do
  @moduledoc """
  Outline-style promote (SPEC R7d; Agenda 2.0 User's Guide, "Promoting and
  Demoting Categories"): the category moves one level up and its following
  siblings become its children, so the outline order never changes.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Agendum.Fixtures
  alias Agendum.Core
  alias Agendum.Core.Database

  defp children(db, name),
    do: Enum.map(db.categories[cat(db, name)].children, &db.categories[&1].name)

  defp outline(db),
    do: db |> Database.hierarchy() |> Enum.map(fn {id, d} -> {db.categories[id].name, d} end)

  defp names(db, item),
    do:
      db |> Database.explicit_categories(item) |> Enum.map(&db.categories[&1].name) |> Enum.sort()

  test "the manual's example: promoting Sam adopts John and Anna; Ted comes along (Figure 16-13)" do
    db =
      with_categories(Core.new_file(), [
        {"People", [match_name: false], [{"Sam", [], ["Ted"]}, "John", "Anna"]}
      ])

    before = outline(db) |> Enum.map(&elem(&1, 0))

    {:ok, db} = Core.promote(db, cat(db, "Sam"))

    assert children(db, "People") == []
    assert children(db, "Sam") == ["Ted", "John", "Anna"]
    assert db.categories[cat(db, "Sam")].parent_id == db.main_id
    # the outline order is unchanged; only levels moved
    assert Enum.map(outline(db), &elem(&1, 0)) == before
  end

  test "promoting the last child adopts nothing" do
    db = with_categories(Core.new_file(), [{"People", [], ["Sam", "Anna"]}])
    {:ok, db} = Core.promote(db, cat(db, "Anna"))
    assert children(db, "People") == ["Sam"]
    assert children(db, "Anna") == []
  end

  test "promote then demote restores a last child, and the outline order holds throughout" do
    db = with_categories(Core.new_file(), [{"People", [], ["Sam", "Anna"]}])
    order = Enum.map(outline(db), &elem(&1, 0))
    {:ok, db} = Core.promote(db, cat(db, "Anna"))
    assert Enum.map(outline(db), &elem(&1, 0)) == order
    {:ok, db} = Core.demote(db, cat(db, "Anna"))
    assert children(db, "People") == ["Sam", "Anna"]
  end

  describe "the manual's conflict example: promoting Anna makes Tim its child (Figure 16-15)" do
    setup do
      db = with_categories(Core.new_file(), [{"Staff", [match_name: false], ["Anna", "Tim"]}])
      {db, item} = Core.add_item(db, "Is project on schedule?", today(), section: cat(db, "Anna"))
      db = Core.assign(db, item, cat(db, "Tim"))
      %{db: db, item: item, anna: cat(db, "Anna")}
    end

    test "the conflict is reported", %{db: db, item: item, anna: anna} do
      assert Core.promote_conflicts(db, anna) == {:ok, [item]}
    end

    test "default: break the assignment to the promoted category (Anna)", %{
      db: db,
      item: item,
      anna: anna
    } do
      {:ok, db} = Core.promote(db, anna)
      assert children(db, "Anna") == ["Tim"]
      assert names(db, item) == ["Tim"]
    end

    test ":remove_other breaks the assignment to the new child (Tim)", %{
      db: db,
      item: item,
      anna: anna
    } do
      {:ok, db} = Core.promote(db, anna, :remove_other)
      assert names(db, item) == ["Anna"]
    end

    test "{:new_category, name} creates it under the conflicting parent (Anna)", %{
      db: db,
      item: item,
      anna: anna
    } do
      {:ok, db} = Core.promote(db, anna, {:new_category, "Both"})
      assert names(db, item) == ["Both"]
      assert db.categories[cat(db, "Both")].parent_id == anna
    end
  end

  test "adopted siblings of an exclusive category become exclusive too" do
    db =
      with_categories(Core.new_file(), [
        {"Staff", [match_name: false], [{"Anna", [exclusive: true], []}, "Tim", "Sue"]}
      ])

    {db, item} = Core.add_item(db, "x", today(), section: cat(db, "Tim"))
    db = Core.assign(db, item, cat(db, "Sue"))

    assert {:ok, [^item]} = Core.promote_conflicts(db, cat(db, "Anna"))
    {:ok, db} = Core.promote(db, cat(db, "Anna"))
    # the category closest to the top of the family wins by default
    assert names(db, item) == ["Tim"]
  end

  property "promote and demote never change the outline order" do
    check all(
            ops <- list_of(tuple({member_of([:promote, :demote]), integer(0..6)}), max_length: 30)
          ) do
      db = with_categories(Core.new_file(), [{"A", [], ["B", {"C", [], ["D"]}, "E"]}, "F", "G"])
      ids = Enum.map(~w(A B C D E F G), &cat(db, &1))
      order = fn db -> Enum.map(Database.hierarchy(db), &elem(&1, 0)) end
      before = order.(db)

      db =
        Enum.reduce(ops, db, fn {op, i}, db ->
          case apply(Core, op, [db, Enum.at(ids, i)]) do
            {:ok, db} -> db
            {:error, _} -> db
          end
        end)

      assert order.(db) == before
    end
  end
end
