defmodule Agendum.Core.DependenciesTest do
  @moduledoc "Items that depend on other items (R43; User's Guide 13-12 to 13-16)."
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.{Database, ViewModel}

  @today ~D[2026-10-08]

  # The manual's example: two prerequisites and one dependent item.
  setup do
    db = Core.new_file()
    section = hd(db.views[hd(db.view_order)].sections).category_id

    {db, [find, look, write]} =
      Enum.reduce(
        ["Find Eastbrook address", "Look into sales strategies", "Write Eastbrook"],
        {db, []},
        fn text, {db, ids} ->
          {db, id} = Core.add_item(db, text, @today, section: section)
          {db, ids ++ [id]}
        end
      )

    {:ok, db} = Core.make_dependent(db, write, [find, look])
    %{db: db, find: find, look: look, write: write, view: hd(db.view_order)}
  end

  defp shown(db, view),
    do:
      db |> ViewModel.build(db.views[view]) |> hd() |> Map.get(:rows) |> Enum.map(& &1.item.text)

  test "an item depends on its prerequisites", %{db: db, find: find, look: look, write: write} do
    assert Core.prerequisites(db, write) == [find, look]
    assert Core.dependents(db, find) == [write]
    assert Core.waiting?(db, write)
    refute Core.waiting?(db, find)
  end

  test "it stops waiting once every prerequisite is done or discarded",
       %{db: db, find: find, look: look, write: write} do
    db = Core.toggle_done(db, find, @today)
    assert Core.waiting?(db, write)
    db = Core.discard_item(db, look)
    refute Core.waiting?(db, write)
    assert Core.prerequisites(db, write) == [find]
  end

  test "an item cannot depend on itself or on an item that depends on it",
       %{db: db, find: find, write: write} do
    assert Core.make_dependent(db, write, [write]) == {:error, :cycle}
    assert Core.make_dependent(db, find, [write]) == {:error, :cycle}
  end

  test "more prerequisites can be added later; they are listed in item order",
       %{db: db, find: find, look: look, write: write} do
    {db, call} = Core.add_item(db, "Call Eastbrook", @today)
    {:ok, db} = Core.make_dependent(db, write, [call])
    assert Core.prerequisites(db, write) == [find, look, call]
  end

  test "dependencies can be cleared", %{db: db, find: find, write: write} do
    db = Core.clear_dependencies(db, write)
    assert Core.prerequisites(db, write) == []
    assert Core.dependents(db, find) == []
  end

  test "one dependency can be removed", %{db: db, find: find, look: look, write: write} do
    db = Core.remove_dependency(db, write, find)
    assert Core.prerequisites(db, write) == [look]
    assert Core.dependents(db, find) == []
    assert Core.remove_dependency(db, write, find) == db
  end

  test "a view can hide waiting items", %{db: db, view: view, find: find, look: look} do
    assert length(shown(db, view)) == 3
    db = Core.toggle_view_option(db, view, :hide_dependent)
    assert shown(db, view) == ["Find Eastbrook address", "Look into sales strategies"]

    # Lotus Q&A "Hiding Done and Dependent Items": with done items hidden
    # too, the dependent item must come back once its prerequisites are done
    db = Core.toggle_view_option(db, view, :hide_done)
    db = db |> Core.toggle_done(find, @today) |> Core.toggle_done(look, @today)
    assert shown(db, view) == ["Write Eastbrook"]
  end

  test "discarding the dependent item forgets its dependencies", %{
    db: db,
    find: find,
    write: write
  } do
    db = Database.delete_item(db, write)
    assert Core.dependents(db, find) == []
  end

  describe "showing dependencies (Utilities Show Depends / Show Prereqs)" do
    setup %{db: db, find: find} do
      {db, sign} = Core.add_item(db, "Sign the letter", @today)
      {:ok, db} = Core.make_dependent(db, sign, [Enum.at(Core.dependents(db, find), 0)])
      %{db: db, sign: sign}
    end

    test "one level or all levels of dependents", %{db: db, find: find, write: write, sign: sign} do
      assert Core.related_items(db, find, :dependents, :one) == [write]
      assert Core.related_items(db, find, :dependents, :all) == [write, sign]
    end

    test "one level or all levels of prerequisites",
         %{db: db, find: find, look: look, write: write, sign: sign} do
      assert Core.related_items(db, sign, :prerequisites, :one) == [write]
      assert Core.related_items(db, sign, :prerequisites, :all) == [find, look, write]
    end

    test "every item that has dependents, or prerequisites",
         %{db: db, find: find, look: look, write: write, sign: sign} do
      assert Core.related_items(db, nil, :dependents, :every) == [find, look, write]
      assert Core.related_items(db, nil, :prerequisites, :every) == [write, sign]
    end

    test "the Show View lists them", %{db: db, find: find, write: write, sign: sign} do
      {db, view} = Core.show_items(db, Core.related_items(db, find, :dependents, :all))
      assert db.views[view].name == "Show View"

      texts =
        db |> ViewModel.build(db.views[view]) |> hd() |> Map.get(:rows) |> Enum.map(& &1.item.id)

      assert texts == [write, sign]
    end
  end
end
