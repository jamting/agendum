defmodule Agenda.Core.ExclusiveTest do
  @moduledoc """
  Making a category's children mutually exclusive when items are already
  assigned to more than one of them (SPEC R7a; Agenda 2.0 User's Guide,
  "Resolving conflicts for mutually exclusive categories").
  """
  use ExUnit.Case, async: true

  import Agenda.Fixtures
  alias Agenda.Core
  alias Agenda.Core.Database

  setup do
    db =
      with_categories(Core.new_file(), [
        {"Priority", [match_name: false], [{"High", [], ["Urgent"]}, "Medium", "Low"]}
      ])

    {db, both} = Core.add_item(db, "both", today(), section: cat(db, "Low"))
    db = Core.assign(db, both, cat(db, "Urgent"))
    {db, single} = Core.add_item(db, "single", today(), section: cat(db, "Medium"))

    %{db: db, both: both, single: single, priority: cat(db, "Priority")}
  end

  defp branches(db, item),
    do:
      db |> Database.explicit_categories(item) |> Enum.map(&db.categories[&1].name) |> Enum.sort()

  test "conflicts are items in more than one child branch (subtrees included)", %{
    db: db,
    both: both,
    priority: p
  } do
    assert Core.exclusive_conflicts(db, p) == [both]
  end

  test ":parent (the default) moves conflicting items up to the parent", %{
    db: db,
    both: both,
    single: single,
    priority: p
  } do
    assert {:ok, db} = Core.make_exclusive(db, p)
    assert db.categories[p].exclusive
    assert branches(db, both) == ["Priority"]
    assert branches(db, single) == ["Medium"]
    assert Core.exclusive_conflicts(db, p) == []
  end

  test ":first_child keeps the branch closest to the top of the family", %{
    db: db,
    both: both,
    priority: p
  } do
    assert {:ok, db} = Core.make_exclusive(db, p, :first_child)
    assert branches(db, both) == ["Urgent"]
  end

  test "{:new_child, name} creates a child and assigns conflicting items to it", %{
    db: db,
    both: both,
    priority: p
  } do
    assert {:ok, db} = Core.make_exclusive(db, p, {:new_child, "Unsure"})
    [unsure] = Database.find_categories(db, "Unsure")
    assert db.categories[unsure].parent_id == p
    assert branches(db, both) == ["Unsure"]
  end

  test "{:new_child, name} rejects empty and duplicate names", %{db: db, priority: p} do
    assert Core.make_exclusive(db, p, {:new_child, " "}) == {:error, :empty}
    assert Core.make_exclusive(db, p, {:new_child, "low"}) == {:error, :duplicate}
  end

  test "without conflicts nothing is created or moved", %{db: db, priority: p} do
    {:ok, db} = Core.make_exclusive(db, cat(db, "High"), {:new_child, "Never"})
    assert db.categories[cat(db, "High")].exclusive
    assert Database.find_categories(db, "Never") == []
    assert Core.exclusive_conflicts(db, p) != []
  end

  test "protected categories cannot be made exclusive", %{db: db} do
    assert Core.make_exclusive(db, db.main_id) == {:error, :protected}
  end

  test "make_unexclusive keeps all assignments", %{db: db, both: both, priority: p} do
    {:ok, db} = Core.make_exclusive(db, p, :first_child)
    db = Core.make_unexclusive(db, p)
    refute db.categories[p].exclusive
    assert branches(db, both) == ["Urgent"]
  end
end
