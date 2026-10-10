defmodule Agenda.Core.NegativeLinksTest do
  @moduledoc """
  General negative links (R9; not in Agenda 2.0, from the patent's FIG. 6):
  two categories, anywhere in the hierarchy, that may not share an item.
  """
  use ExUnit.Case, async: true

  alias Agenda.Core
  alias Agenda.Core.Database

  @today ~D[2026-10-08]

  setup do
    db = Core.new_file()
    {:ok, db, work} = Core.add_category(db, db.main_id, "Work")
    {:ok, db, coding} = Core.add_category(db, work, "Coding")
    {:ok, db, vacation} = Core.add_category(db, db.main_id, "Vacation")
    {:ok, db, sick} = Core.add_category(db, db.main_id, "Sick")
    {:ok, db} = Core.toggle_exclude(db, work, vacation)
    %{db: db, work: work, coding: coding, vacation: vacation, sick: sick}
  end

  defp member?(db, id, cat), do: Database.member?(db, id, cat)

  test "a negative link is kept on both categories", %{db: db, work: w, vacation: v} do
    assert db.categories[w].excludes == [v]
    assert db.categories[v].excludes == [w]
  end

  test "assigning to one category takes the item out of the other and its children",
       %{db: db, coding: c, vacation: v} do
    {db, id} = Core.add_item(db, "Fix the parser", @today)
    db = Core.assign(db, id, c)
    db = Core.assign(db, id, v)
    assert member?(db, id, v)
    refute member?(db, id, c)

    # a child of an excluded category counts as that category
    db = Core.assign(db, id, c)
    refute member?(db, id, v)
  end

  test "categories not linked are not affected", %{db: db, work: w, sick: s} do
    {db, id} = Core.add_item(db, "Fix the parser", @today)
    db = db |> Core.assign(id, w) |> Core.assign(id, s)
    assert member?(db, id, w) and member?(db, id, s)
  end

  test "text matching never puts an item in both", %{db: db, work: w, vacation: v} do
    {db, id} = Core.add_item(db, "Work during Vacation", @today)
    assert member?(db, id, w)
    refute member?(db, id, v)

    # an assignment the item has wins over a new text match
    {db, id} = Core.add_item(db, "Packing", @today)
    db = Core.assign(db, id, v)
    db = Core.edit_item(db, id, "Packing for Work", @today)
    assert member?(db, id, v)
    refute member?(db, id, w)
  end

  test "toggling again removes the link from both", %{db: db, work: w, vacation: v} do
    {:ok, db} = Core.toggle_exclude(db, v, w)
    assert db.categories[w].excludes == []
    assert db.categories[v].excludes == []
  end

  test "a category cannot exclude itself, its ancestors or its descendants",
       %{db: db, work: w, coding: c} do
    assert Core.toggle_exclude(db, w, w) == {:error, :self}
    assert Core.toggle_exclude(db, w, c) == {:error, :lineage}
    assert Core.toggle_exclude(db, c, w) == {:error, :lineage}
    assert Core.toggle_exclude(db, w, db.special.when) == {:error, :not_allowed}
  end

  test "items already in both must be moved first", %{db: db, work: w, sick: s} do
    {db, a} = Core.add_item(db, "Doctor's note for the office", @today)
    db = db |> Core.assign(a, w) |> Core.assign(a, s)
    assert Core.toggle_exclude(db, s, w) == {:error, {:shared, [a]}}
  end

  test "discarding a category drops its negative links", %{db: db, work: w, vacation: v} do
    {:ok, db} = Core.discard_category(db, v)
    assert db.categories[w].excludes == []
  end

  test "a category cannot be moved under one it excludes", %{db: db, work: w, vacation: v} do
    assert Core.move_category(db, v, w, nil) == {:error, :excluded_lineage}
    assert Core.move_conflicts(db, v, w, nil) == {:error, :excluded_lineage}
  end
end
