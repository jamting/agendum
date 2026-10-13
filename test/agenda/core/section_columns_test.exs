defmodule Agenda.Core.SectionColumnsTest do
  @moduledoc """
  Columns per section (R55; User's Guide 3-16, 3-27, 5-22 to 5-25): a
  column belongs to one section or to all, and a column added to all
  sections is linked, so changing one changes them all.
  """
  use ExUnit.Case, async: true

  import Agenda.Fixtures

  alias Agenda.Core
  alias Agenda.Core.{Database, NumberFormat, View, ViewModel}
  alias Agenda.Core.View.Column

  # A view like the Planner's Activities: sections Calls, Follow up and
  # Ideas, each with the When column every new file starts with.
  setup do
    db = Core.new_file(view_name: "Activities", section_name: "Calls")
    db = with_categories(db, ["Follow up", "Ideas", "People", "Priority", "Amount"])
    [view] = Database.views(db)
    db = Core.add_section(db, view.id, cat(db, "Follow up"), 1)
    db = Core.add_section(db, view.id, cat(db, "Ideas"), 2)
    %{db: db, view_id: view.id}
  end

  defp heads(db, view_id) do
    view = db.views[view_id]

    for sidx <- 0..(length(view.sections) - 1) do
      view |> View.columns(sidx) |> Enum.map(&db.categories[&1.category_id].name)
    end
  end

  defp column(db, view_id, {sidx, index}),
    do: db.views[view_id] |> View.columns(sidx) |> Enum.at(index)

  test "a new file's columns are in its section", %{db: db, view_id: v} do
    assert heads(db, v) == [["When"], ["When"], ["When"]]
    assert db.views[v].columns == []
  end

  describe "adding a column" do
    test "to the current section only: the other sections do not get it", %{db: db, view_id: v} do
      db = Core.add_column(db, v, cat(db, "People"), {0, 0}, 12, :section)
      assert heads(db, v) == [["People", "When"], ["When"], ["When"]]
      refute column(db, v, {0, 0}).linked
    end

    test "to all sections: each gets it, linked", %{db: db, view_id: v} do
      db = Core.add_column(db, v, cat(db, "People"), {1, 1}, 14, :all)
      assert heads(db, v) == [["When", "People"], ["When", "People"], ["When", "People"]]
      assert Enum.all?([{0, 1}, {1, 1}, {2, 1}], &(column(db, v, &1).width == 14))
      assert Enum.all?([{0, 1}, {1, 1}, {2, 1}], &column(db, v, &1).linked)
    end

    test "to all sections: beside the same column where a section has it", %{db: db, view_id: v} do
      # Calls: People, When; the others: When
      db = Core.add_column(db, v, cat(db, "People"), {0, 0}, 12, :section)
      # left of When in Follow up: left of When in Calls too, not at its start
      db = Core.add_column(db, v, cat(db, "Priority"), {1, 0}, 8, :all)

      assert heads(db, v) == [
               ["People", "Priority", "When"],
               ["Priority", "When"],
               ["Priority", "When"]
             ]

      # between People and Priority in Calls: left of Priority where there
      # is no People
      db = Core.add_column(db, v, cat(db, "Amount"), {0, 1}, 8, :all)

      assert heads(db, v) == [
               ["People", "Amount", "Priority", "When"],
               ["Amount", "Priority", "When"],
               ["Amount", "Priority", "When"]
             ]

      # right of When: after When wherever it is (Priority is gone from Follow up)
      db = Core.remove_column(db, v, {1, 1}, :section)
      db = Core.add_column(db, v, cat(db, "Ideas"), {0, 4}, 8, :all)
      assert Enum.map(heads(db, v), &List.last/1) == ["Ideas", "Ideas", "Ideas"]
      assert Enum.at(heads(db, v), 1) == ["Amount", "When", "Ideas"]
    end

    test "joining linked columns of the same head takes their settings", %{db: db, view_id: v} do
      db = Core.resize_column(db, v, {0, 0}, 4)
      db = Core.add_column(db, v, cat(db, "When"), {0, 1}, 12, :all)
      assert column(db, v, {1, 1}).width == column(db, v, {0, 0}).width
    end
  end

  describe "the file's Insert new columns in (File Properties)" do
    test "is All sections in a new file", %{db: db} do
      assert db.insert_columns == :all
    end

    test "Current section: a new column goes into that section only", %{db: db, view_id: v} do
      db = Core.set_insert_columns(db, :section)
      db = Core.add_column(db, v, cat(db, "People"), {1, 0})
      assert heads(db, v) == [["When"], ["People", "When"], ["When"]]
    end

    test "adding a column can say otherwise (the Column Add box's Insert in)",
         %{db: db, view_id: v} do
      db = Core.set_insert_columns(db, :section)
      db = Core.add_column(db, v, cat(db, "People"), {1, 0}, nil, :all)
      assert heads(db, v) == [["People", "When"], ["People", "When"], ["People", "When"]]
    end
  end

  test "a new column is 16 wide for a date category, 12 for others", %{db: db, view_id: v} do
    {:ok, db, due} = Core.add_category(db, db.main_id, "Due")
    {:ok, db} = Core.make_date(db, due, today())
    db = Core.add_column(db, v, cat(db, "People"), {0, 0})
    db = Core.add_column(db, v, due, {0, 0})
    assert Enum.map(View.columns(db.views[v], 0), & &1.width) == [16, 12, 16]
  end

  describe "changing a linked column" do
    test "its width changes in every section", %{db: db, view_id: v} do
      db = Core.resize_column(db, v, {2, 0}, 2)
      assert Enum.map(0..2, &column(db, v, {&1, 0}).width) == [18, 18, 18]
    end

    test "its formats change in every section", %{db: db, view_id: v} do
      db = Core.add_column(db, v, cat(db, "Amount"), {0, 1}, 8, :all)
      format = %NumberFormat{decimals: 0}
      db = Core.set_column_format(db, v, {1, 1}, format)
      assert Enum.map(0..2, &column(db, v, {&1, 1}).number) == [format, format, format]
    end

    test "an unlinked column changes alone", %{db: db, view_id: v} do
      db = Core.add_column(db, v, cat(db, "People"), {0, 0}, 12, :section)
      db = Core.add_column(db, v, cat(db, "People"), {1, 0}, 12, :section)
      db = Core.resize_column(db, v, {1, 0}, 2)
      assert column(db, v, {0, 0}).width == 12
      assert column(db, v, {1, 0}).width == 14
    end
  end

  describe "removing a column" do
    test "from the current section only", %{db: db, view_id: v} do
      db = Core.remove_column(db, v, {1, 0}, :section)
      assert heads(db, v) == [["When"], [], ["When"]]
    end

    test "from all sections: its linked columns go too, unlinked ones stay", %{db: db, view_id: v} do
      db = Core.add_column(db, v, cat(db, "When"), {1, 1}, 12, :section)
      db = Core.remove_column(db, v, {0, 0}, :all)
      assert heads(db, v) == [[], ["When"], []]
    end

    test "whether it is in other sections, for the question", %{db: db, view_id: v} do
      db = Core.add_column(db, v, cat(db, "People"), {0, 0}, 12, :section)
      view = db.views[v]
      assert View.in_other_sections?(view, {0, 1})
      refute View.in_other_sections?(view, {0, 0})
      db = Core.remove_column(db, v, {1, 0}, :section)
      db = Core.remove_column(db, v, {2, 0}, :section)
      refute View.in_other_sections?(db.views[v], {0, 1})
    end
  end

  test "a new section gets the linked columns of the section it was added from",
       %{db: db, view_id: v} do
    db = Core.add_column(db, v, cat(db, "People"), {0, 0}, 12, :section)
    db = Core.add_section(db, v, cat(db, "Priority"), 1, 0)
    assert Enum.at(heads(db, v), 1) == ["When"]
  end

  test "each section shows its own columns", %{db: db, view_id: v} do
    db = Core.add_column(db, v, cat(db, "People"), {0, 0}, 12, :section)
    [calls, follow_up | _] = ViewModel.build(db, db.views[v], today())
    assert Enum.map(calls.columns, & &1.category_id) == [cat(db, "People"), cat(db, "When")]
    assert Enum.map(follow_up.columns, & &1.category_id) == [cat(db, "When")]
    assert {calls.index, follow_up.index} == {0, 1}
  end

  test "discarding a category removes its columns from every section", %{db: db, view_id: v} do
    db = Core.add_column(db, v, cat(db, "People"), {1, 0}, 12, :all)
    {:ok, db} = Core.discard_category(db, cat(db, "People"))
    assert heads(db, v) == [["When"], ["When"], ["When"]]
  end

  test "a view with its columns stored the old way gets them in every section, linked",
       %{db: db, view_id: v} do
    old = %{
      db.views[v]
      | sections: Enum.map(db.views[v].sections, &%{&1 | columns: []}),
        columns: [%Column{category_id: cat(db, "People"), width: 9}]
    }

    view = View.columns_into_sections(old)
    assert view.columns == []
    assert Enum.all?(view.sections, &match?([%Column{width: 9, linked: true}], &1.columns))
  end

  test "a datebook view keeps one set of columns for all its slots", %{db: db} do
    {:ok, db, v} = Core.add_datebook_view(db, "Week", %Agenda.Core.Datebook{})
    db = Core.add_column(db, v, cat(db, "People"), {3, 0}, 12, :section)
    assert Enum.map(db.views[v].columns, & &1.category_id) == [cat(db, "People")]
    assert View.columns(db.views[v], 5) == db.views[v].columns
    assert View.columns_into_sections(db.views[v]) == db.views[v]
  end
end
