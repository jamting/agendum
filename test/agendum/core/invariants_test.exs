defmodule Agendum.Core.InvariantsTest do
  @moduledoc """
  The data model's invariants (docs/DATA_MODEL.md, "Invariants") as one
  pure check: sound files have none broken, and each kind of breakage is
  reported. The fuzz walks (`Agendum.TUI.Fuzz`) run the same check after
  every key.
  """
  use ExUnit.Case, async: true

  import Agendum.Fixtures, only: [cat: 2]

  alias Agendum.Core.{Database, Invariants, Links}

  @today ~D[2026-10-08]

  defp sample, do: Agendum.Sample.build(@today)
  defp an_item(db), do: hd(db.item_order)

  # `violations/1` returns readable sentences; a test only needs to know
  # that one about the broken invariant is among them
  defp assert_broken(db, pattern) do
    violations = Invariants.violations(db)
    assert Enum.any?(violations, &(&1 =~ pattern)), inspect(violations, pretty: true)
  end

  test "the built-in files and a new file break none" do
    assert Invariants.violations(Database.new()) == []
    assert Invariants.violations(sample()) == []
    assert Invariants.violations(Agendum.Sample.rabbit(@today)) == []
    assert Invariants.violations(Agendum.Starters.Planner.build()) == []
  end

  test "1. a category whose parent does not list it" do
    db = sample()
    id = cat(db, "Calls")
    parent = db.categories[id].parent_id
    db = update_in(db.categories[parent].children, &List.delete(&1, id))
    assert_broken(db, ~r/tree/)
  end

  test "1. a cycle in the tree" do
    db = sample()
    a = cat(db, "Calls")
    db = put_in(db.categories[db.main_id].parent_id, a)
    assert_broken(db, ~r/tree/)
  end

  test "2. a link without its reverse" do
    db = sample()
    item = an_item(db)
    db = put_in(db.links.by_left[item], MapSet.new([cat(db, "Calls")]))
    db = update_in(db.links.by_right[cat(db, "Calls")], &MapSet.delete(&1 || MapSet.new(), item))
    assert_broken(db, ~r/symmetric/)
  end

  test "2. an empty set stored in the links" do
    db = sample()
    db = put_in(db.links.by_right[cat(db, "Calls")], MapSet.new())
    db = %{db | links: %{db.links | by_left: Map.put(db.links.by_left, 999_999, MapSet.new())}}
    assert_broken(db, ~r/empty/)
  end

  test "3. a link to an item that is gone" do
    db = sample()
    db = %{db | links: Links.link(db.links, 999_999, cat(db, "Calls"))}
    assert_broken(db, ~r/live/)
  end

  test "4. a link to MAIN or a date category" do
    db = sample()
    db = Database.link(db, an_item(db), db.special.when)
    assert_broken(db, ~r/MAIN or a date category/)
  end

  test "5. an item in two children of an exclusive parent" do
    db = sample()
    priority = cat(db, "Priority")
    db = put_in(db.categories[priority].exclusive, true)
    [a, b | _] = db.categories[priority].children
    item = an_item(db)
    db = db |> Database.link(item, a) |> Database.link(item, b)
    assert_broken(db, ~r/exclusive/)
  end

  test "6. a section headed by a category that is gone" do
    db = sample()
    view = hd(db.view_order)
    db = update_in(db.views[view].sections, &[%{hd(&1) | category_id: 999_999} | tl(&1)])
    assert_broken(db, ~r/gone/)
  end

  test "6. a category link to a category that is gone" do
    db = sample()
    db = put_in(db.categories[cat(db, "Calls")].also_assign, [999_999])
    assert_broken(db, ~r/gone/)
  end

  test "7. the order lists and the maps disagree" do
    db = sample()
    db = %{db | item_order: tl(db.item_order)}
    assert_broken(db, ~r/item_order/)
    assert_broken(%{sample() | view_order: []}, ~r/view_order/)
  end

  test "8. a protected category moved or renamed" do
    db = sample()
    db = put_in(db.categories[db.special.when].name, "Whenever")
    assert_broken(db, ~r/protected/)
  end

  test "9. an item directly in a category and its ancestor" do
    db = sample()
    item = an_item(db)

    db =
      db |> Database.link(item, cat(db, "Anna Lasky")) |> Database.link(item, cat(db, "Contact"))

    assert_broken(db, ~r/ancestor/)
  end

  test "10. a conditional mark without its link" do
    db = sample()
    item = an_item(db)
    db = Database.unlink(db, item, cat(db, "Meetings"))
    db = %{db | conditional: MapSet.put(db.conditional, {item, cat(db, "Meetings")})}
    assert_broken(db, ~r/conditional/)
  end

  test "ids: below next_id, one id space, and each object under its own id" do
    db = sample()
    assert_broken(%{db | next_id: 1}, ~r/next_id/)

    item = an_item(db)
    db = put_in(db.items[item].id, item + 1)
    assert_broken(db, ~r/own id/)
  end
end
