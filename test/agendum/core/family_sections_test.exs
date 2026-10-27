defmodule Agendum.Core.FamilySectionsTest do
  @moduledoc """
  A category inserted in a family whose other members are all sections of
  a view becomes a section of that view too (User's Guide 16-11, R42;
  checked in Agenda 2.0, 2026-10-27): right after the section of its
  previous sibling, a first child at the top, with the columns every
  section has.
  """
  use ExUnit.Case, async: true

  import Agendum.Fixtures
  alias Agendum.Core

  # People: Meg, Tom, Janet; By Person: a section for each, plus Other,
  # unrelated, which does not stop the rule
  setup do
    db = Core.new_file()
    {:ok, db, people} = Core.add_category(db, db.main_id, "People")
    {:ok, db, other} = Core.add_category(db, db.main_id, "Other")

    {db, [meg, tom, janet]} =
      Enum.reduce(~w(Meg Tom Janet), {db, []}, fn name, {db, ids} ->
        {:ok, db, id} = Core.add_category(db, people, name)
        {db, ids ++ [id]}
      end)

    {db, view} = Core.add_view(db, "By Person", [meg, tom, janet, other])
    %{db: db, people: people, meg: meg, tom: tom, janet: janet, other: other, view: view}
  end

  defp heads(db, view), do: Enum.map(db.views[view].sections, & &1.category_id)

  defp insert(db, parent, name, opts \\ []) do
    {:ok, db, %{new: id}} = Core.run(db, {:insert_category, parent, name, opts}, today())
    {db, id}
  end

  test "a new sibling gets a section after its previous sibling's", ctx do
    {db, sharon} = insert(ctx.db, ctx.people, "Sharon", after: ctx.tom)
    assert heads(db, ctx.view) == [ctx.meg, ctx.tom, sharon, ctx.janet, ctx.other]
  end

  test "a new first child goes to the top of the view", ctx do
    {db, aa} = insert(ctx.db, ctx.people, "Aa", after: :first)
    assert heads(db, ctx.view) == [aa, ctx.meg, ctx.tom, ctx.janet, ctx.other]
  end

  test "a family not wholly in the view gets no section", ctx do
    db = Core.remove_section(ctx.db, ctx.view, 2)
    {db, _} = insert(db, ctx.people, "Sharon")
    assert heads(db, ctx.view) == [ctx.meg, ctx.tom, ctx.other]
  end

  test "a first child of a family without children gets no section", ctx do
    {db, _} = insert(ctx.db, ctx.other, "Thing")
    assert heads(db, ctx.view) == [ctx.meg, ctx.tom, ctx.janet, ctx.other]
  end

  test "every view that qualifies gets one; a datebook view does not", ctx do
    {db, second} = Core.add_view(ctx.db, "P2", [ctx.janet, ctx.meg, ctx.tom])

    {:ok, db, datebook} =
      Core.add_datebook_view(db, "Week", %Agendum.Core.Datebook{period: :week})

    {db, sharon} = insert(db, ctx.people, "Sharon")
    assert heads(db, second) == [ctx.janet, sharon, ctx.meg, ctx.tom]
    refute sharon in heads(db, datebook)
  end

  test "the new section has the columns every section has, not its neighbour's own", ctx do
    db = Core.add_column(ctx.db, ctx.view, ctx.people, {1, 0}, nil, :all)
    db = Core.add_column(db, ctx.view, db.special.when, {1, 1}, nil, :section)
    {db, sharon} = insert(db, ctx.people, "Sharon", after: ctx.tom)
    section = Enum.find(db.views[ctx.view].sections, &(&1.category_id == sharon))
    assert Enum.map(section.columns, & &1.category_id) == [ctx.people]
  end

  test "a new name typed in a column makes its section too", ctx do
    {db, item} = Core.add_item(ctx.db, "call", today())

    {:ok, db, _} =
      Core.run(db, {:assign_new_by_name, item, ctx.people, "Quinn"}, today())

    quinn = Enum.find(db.categories[ctx.people].children, &(db.categories[&1].name == "Quinn"))
    assert quinn in heads(db, ctx.view)
  end

  test "the Category Add way (add_category) and moving one in do not, as Agenda's", ctx do
    {:ok, db, %{new: thing}} =
      Core.run(ctx.db, {:add_category, ctx.people, "Thing", []}, today())

    refute thing in heads(db, ctx.view)
  end
end
