defmodule Agenda.Core.SortFilterTest do
  @moduledoc """
  Filtering views and sections by category (SPEC R28; User's Guide ch. 11)
  and sorting items (SPEC R36; User's Guide ch. 15).
  """
  use ExUnit.Case, async: true

  import Agenda.Fixtures
  alias Agenda.Core
  alias Agenda.Core.{Database, ViewModel}
  alias Agenda.Core.View.SortKey

  setup do
    db =
      with_categories(Core.new_file(), [
        {"Tasks", [match_name: false], []},
        {"Priority", [exclusive: true, match_name: false], ["High", "Medium", "Low"]},
        {"People", [match_name: false], ["Zoe", "Anna"]}
      ])

    [view] = Database.views(db)
    db = Core.add_section(db, view.id, cat(db, "Tasks"), 0) |> Core.remove_section(view.id, 1)
    tasks = cat(db, "Tasks")

    add = fn db, text, cats ->
      {db, id} = Core.add_item(db, text, today(), section: tasks)
      Enum.reduce(cats, db, &Core.assign(&2, id, cat(&2, &1)))
    end

    db =
      db
      |> add.("call bob", ["Low", "Zoe"])
      |> add.("Ask Bea", ["High"])
      |> add.("buy milk", [])
      |> add.("draft memo", ["Medium", "Anna"])

    %{db: db, view: view.id}
  end

  defp texts(db, view_id),
    do:
      db
      |> ViewModel.build(Database.view(db, view_id))
      |> hd()
      |> Map.get(:rows)
      |> Enum.map(& &1.item.text)

  describe "filters" do
    test "a view filter shows only items assigned to the category", %{db: db, view: v} do
      {:ok, db} = Core.cycle_filter(db, v, :view, cat(db, "High"))
      assert texts(db, v) == ["Ask Bea"]
    end

    test "a not-assigned filter hides the category's items", %{db: db, view: v} do
      {:ok, db} = Core.cycle_filter(db, v, :view, cat(db, "People"))
      {:ok, db} = Core.cycle_filter(db, v, :view, cat(db, "People"))
      assert texts(db, v) == ["Ask Bea", "buy milk"]
    end

    test "filters on mutually exclusive categories mean either (High or Medium)", %{
      db: db,
      view: v
    } do
      {:ok, db} = Core.cycle_filter(db, v, :view, cat(db, "High"))
      {:ok, db} = Core.cycle_filter(db, v, :view, cat(db, "Medium"))
      assert texts(db, v) == ["Ask Bea", "draft memo"]
    end

    test "section filters combine with the view's", %{db: db, view: v} do
      {:ok, db} = Core.cycle_filter(db, v, {:section, 0}, cat(db, "Anna"))
      assert texts(db, v) == ["draft memo"]
    end

    test "cycling a filter goes assigned, not assigned, none", %{db: db, view: v} do
      high = cat(db, "High")
      {:ok, db} = Core.cycle_filter(db, v, :view, high)
      assert Database.view(db, v).filter == [{high, :assigned}]
      {:ok, db} = Core.cycle_filter(db, v, :view, high)
      assert Database.view(db, v).filter == [{high, :not_assigned}]
      {:ok, db} = Core.cycle_filter(db, v, :view, high)
      assert Database.view(db, v).filter == []
    end

    test "a new item is given the categories a filter requires, so it stays in sight", %{
      db: db,
      view: v
    } do
      {:ok, db} = Core.cycle_filter(db, v, :view, cat(db, "High"))
      {:ok, db} = Core.cycle_filter(db, v, {:section, 0}, cat(db, "Zoe"))

      assert Core.entry_categories(db, v, 0) |> Enum.map(&db.categories[&1].name) |> Enum.sort() ==
               ["High", "Zoe"]
    end
  end

  describe "sorting" do
    test "by item text, ascending and descending, ignoring case", %{db: db, view: v} do
      db = Core.set_sort(db, v, :view, [%SortKey{on: :text}])
      assert texts(db, v) == ["Ask Bea", "buy milk", "call bob", "draft memo"]

      db = Core.set_sort(db, v, :view, [%SortKey{on: :text, order: :desc}])
      assert texts(db, v) == ["draft memo", "call bob", "buy milk", "Ask Bea"]
    end

    test "by a category in hierarchy order, items without one at the bottom", %{db: db, view: v} do
      db = Core.set_sort(db, v, :view, [%SortKey{on: {:category, cat(db, "Priority")}}])
      assert texts(db, v) == ["Ask Bea", "draft memo", "call bob", "buy milk"]
    end

    test "by a line of the category note (User's Guide 15-18)", %{db: db, view: v} do
      db =
        db
        |> Core.set_category_note(cat(db, "Zoe"), "Zoe Hall\nOslo")
        |> Core.set_category_note(cat(db, "Anna"), "Anna Berg\nbergen")

      key = %SortKey{on: {:note, cat(db, "People")}, line: 2}
      db = Core.set_sort(db, v, :view, [key])
      # Anna's town (bergen) before Zoe's (Oslo), ignoring case; no person last
      assert texts(db, v) == ["draft memo", "call bob", "Ask Bea", "buy milk"]

      db = Core.set_sort(db, v, :view, [%{key | order: :desc}])
      assert texts(db, v) == ["call bob", "draft memo", "Ask Bea", "buy milk"]
    end

    test "discarding the category drops the key", %{db: db, view: v} do
      db = Core.set_sort(db, v, :view, [%SortKey{on: {:note, cat(db, "People")}}])
      {:ok, db} = Core.discard_category(db, cat(db, "People"))
      assert Database.view(db, v).sort == []
    end

    test "a missing note line counts as no value", %{db: db, view: v} do
      db =
        db
        |> Core.set_category_note(cat(db, "Zoe"), "one line")
        |> Core.set_category_note(cat(db, "Anna"), "Anna Berg\nBergen")

      key = %SortKey{on: {:note, cat(db, "People")}, line: 2, na: :top}
      db = Core.set_sort(db, v, :view, [key])
      # no value (Zoe's note has one line; two items have no person) first, in entry order
      assert texts(db, v) == ["call bob", "Ask Bea", "buy milk", "draft memo"]
    end

    test "n/a's at the top, and alphabetical sequence", %{db: db, view: v} do
      key = %SortKey{on: {:category, cat(db, "People")}, na: :top, sequence: :alpha}
      db = Core.set_sort(db, v, :view, [key])
      # no person: two items (entry order); then Anna, then Zoe
      assert texts(db, v) == ["Ask Bea", "buy milk", "draft memo", "call bob"]
    end

    test "a secondary key breaks ties", %{db: db, view: v} do
      keys = [%SortKey{on: {:category, cat(db, "People")}}, %SortKey{on: :text, order: :desc}]
      db = Core.set_sort(db, v, :view, keys)
      # Zoe, Anna in hierarchy order; the two without a person by text, descending
      assert texts(db, v) == ["call bob", "draft memo", "buy milk", "Ask Bea"]
    end

    test "by a date category", %{db: db, view: v} do
      [_, _, milk, memo] = db.item_order

      db =
        db
        |> Core.set_date(milk, db.special.when, ~D[2026-12-01])
        |> Core.set_date(memo, db.special.when, ~D[2026-11-01])

      db = Core.set_sort(db, v, :view, [%SortKey{on: {:category, db.special.when}}])
      assert Enum.take(texts(db, v), 2) == ["draft memo", "buy milk"]
    end

    test "a section's own sort overrides the view's; nil goes back to the view's", %{
      db: db,
      view: v
    } do
      db = Core.set_sort(db, v, :view, [%SortKey{on: :text}])
      db = Core.set_sort(db, v, {:section, 0}, [%SortKey{on: :text, order: :desc}])
      assert hd(texts(db, v)) == "draft memo"
      db = Core.set_sort(db, v, {:section, 0}, nil)
      assert hd(texts(db, v)) == "Ask Bea"
    end
  end

  test "sort_children and sort_views sort alphabetically (ALT-F5)", %{db: db} do
    db = Core.sort_children(db, cat(db, "People"))

    assert Enum.map(db.categories[cat(db, "People")].children, &db.categories[&1].name) == [
             "Anna",
             "Zoe"
           ]

    {db, _} = Core.add_view(db, "Alpha", [cat(db, "Tasks")])
    db = Core.sort_views(db)
    assert db |> Database.views() |> Enum.map(& &1.name) == ["Alpha", "Initial View"]
  end
end
