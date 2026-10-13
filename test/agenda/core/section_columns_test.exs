defmodule Agenda.Core.SectionColumnsTest do
  @moduledoc """
  Columns per section (R55; User's Guide 3-16, 3-27, 5-22 to 5-25): a
  column belongs to one section or to all, and a column added to all
  sections is linked: it is one column, shown in several sections, so
  changing it in one changes it in all. Each column added is a column of
  its own, even with the head of another (as Agenda does).
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
      assert column(db, v, {0, 0}).link == nil
    end

    test "to all sections: each gets it, linked", %{db: db, view_id: v} do
      db = Core.add_column(db, v, cat(db, "People"), {1, 1}, 14, :all)
      assert heads(db, v) == [["When", "People"], ["When", "People"], ["When", "People"]]
      assert Enum.all?([{0, 1}, {1, 1}, {2, 1}], &(column(db, v, &1).width == 14))
      [link] = Enum.uniq(Enum.map([{0, 1}, {1, 1}, {2, 1}], &column(db, v, &1).link))
      assert link != nil
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

    test "a second column of the same head is a column of its own", %{db: db, view_id: v} do
      db = Core.add_column(db, v, cat(db, "When"), {0, 1}, 12, :all)
      assert heads(db, v) == [["When", "When"], ["When", "When"], ["When", "When"]]
      db = Core.resize_column(db, v, {0, 1}, 2)
      assert Enum.map(0..2, &column(db, v, {&1, 0}).width) == [16, 16, 16]
      assert Enum.map(0..2, &column(db, v, {&1, 1}).width) == [14, 14, 14]
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
    # the same default, asked before adding (the Column Add box shows it)
    assert {Core.default_column_width(db, due), Core.default_column_width(db, nil)} == {16, 12}
    # for a head about to become a date category
    assert Core.default_column_width(db, cat(db, "People"), :date) == 16
  end

  describe "adding a column as a type (Column Add ▸ Category type)" do
    test "a standard head made a date category, then added, 16 wide", %{db: db, view_id: v} do
      assert {:ok, db} =
               Core.add_column_as(db, v, cat(db, "Ideas"), :date, {0, 0}, clock: today())

      assert db.categories[cat(db, "Ideas")].kind == :date
      assert column(db, v, {0, 0}).width == 16
    end

    test "made numeric, the width given", %{db: db, view_id: v} do
      assert {:ok, db} =
               Core.add_column_as(db, v, cat(db, "Amount"), :numeric, {0, 0},
                 width: 9,
                 insert_in: :section,
                 clock: today()
               )

      assert db.categories[cat(db, "Amount")].kind == :numeric
      assert heads(db, v) == [["Amount", "When"], ["When"], ["When"]]
    end

    test "its own type: just added; another type for a date category: refused",
         %{db: db, view_id: v} do
      assert {:ok, db} = Core.add_column_as(db, v, cat(db, "People"), :standard, {0, 0})
      assert column(db, v, {0, 0}).width == 12

      assert Core.add_column_as(db, v, db.special.when, :standard, {0, 0}) ==
               {:error, :not_standard}
    end
  end

  describe "changing a linked column" do
    test "its width changes in every section", %{db: db, view_id: v} do
      db = Core.resize_column(db, v, {2, 0}, 2)
      assert Enum.map(0..2, &column(db, v, {&1, 0}).width) == [18, 18, 18]
      db = Core.set_column_width(db, v, {1, 0}, 20)
      assert Enum.map(0..2, &column(db, v, {&1, 0}).width) == [20, 20, 20]
    end

    test "a width set is at least 3 and at most 80", %{db: db, view_id: v} do
      assert column(Core.set_column_width(db, v, {0, 0}, 1), v, {0, 0}).width == 3
      assert column(Core.set_column_width(db, v, {0, 0}, 999), v, {0, 0}).width == 80
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

  describe "Link with other sections (Column Properties)" do
    test "No: the column changes alone from then on", %{db: db, view_id: v} do
      db = Core.set_column_linked(db, v, {1, 0}, false)
      assert column(db, v, {1, 0}).link == nil
      db = Core.resize_column(db, v, {1, 0}, 4)
      assert Enum.map(0..2, &column(db, v, {&1, 0}).width) == [16, 20, 16]
      db = Core.resize_column(db, v, {0, 0}, 2)
      assert Enum.map(0..2, &column(db, v, {&1, 0}).width) == [18, 20, 18]
    end

    test "Yes: it joins a linked column of its head, taking its settings",
         %{db: db, view_id: v} do
      db = Core.set_column_linked(db, v, {1, 0}, false)
      db = Core.resize_column(db, v, {1, 0}, 4)
      db = Core.set_column_linked(db, v, {1, 0}, true)
      assert column(db, v, {1, 0}).link == column(db, v, {0, 0}).link
      assert column(db, v, {1, 0}).width == 16
      db = Core.resize_column(db, v, {1, 0}, 2)
      assert Enum.map(0..2, &column(db, v, {&1, 0}).width) == [18, 18, 18]
    end

    test "Yes on a linked column changes nothing", %{db: db, view_id: v} do
      db = Core.add_column(db, v, cat(db, "When"), {1, 1}, 16, :section)
      assert Core.set_column_linked(db, v, {0, 0}, true) == db
    end

    test "Yes with no linked columns of its head: it links those of the same width and format",
         %{db: db, view_id: v} do
      db = Core.add_column(db, v, cat(db, "People"), {0, 0}, 12, :section)
      db = Core.add_column(db, v, cat(db, "People"), {1, 0}, 12, :section)
      db = Core.add_column(db, v, cat(db, "People"), {2, 0}, 14, :section)
      db = Core.set_column_linked(db, v, {0, 0}, true)
      assert [a, a, nil] = Enum.map(0..2, &column(db, v, {&1, 0}).link)
      assert a != nil
      db = Core.resize_column(db, v, {0, 0}, 1)
      assert Enum.map(0..2, &column(db, v, {&1, 0}).width) == [13, 13, 14]
    end
  end

  describe "Column head (Column Properties)" do
    test "another category: in every section the column is linked into", %{db: db, view_id: v} do
      db = Core.set_column_head(db, v, {1, 0}, cat(db, "People"))
      assert heads(db, v) == [["People"], ["People"], ["People"]]
    end

    test "an unlinked column changes alone", %{db: db, view_id: v} do
      db = Core.set_column_linked(db, v, {1, 0}, false)
      db = Core.set_column_head(db, v, {1, 0}, cat(db, "People"))
      assert heads(db, v) == [["When"], ["People"], ["When"]]
    end

    test "a column with the head of another stays a column of its own", %{db: db, view_id: v} do
      # People, 9 wide, linked in every section; When (16) becomes People
      db = Core.add_column(db, v, cat(db, "People"), {0, 1}, 9, :all)
      db = Core.set_column_head(db, v, {1, 0}, cat(db, "People"))
      assert Enum.map(0..2, &column(db, v, {&1, 0}).width) == [16, 16, 16]
      db = Core.resize_column(db, v, {0, 1}, 1)
      widths = for s <- 0..2, i <- 0..1, do: column(db, v, {s, i}).width
      assert widths == [16, 10, 16, 10, 16, 10]
    end
  end

  describe "moving a column (User's Guide 5-20)" do
    test "moves it in its section only, even when it is linked", %{db: db, view_id: v} do
      db = Core.add_column(db, v, cat(db, "People"), {0, 1}, 12, :all)
      # places on screen: the item column, When, People
      db = Core.move_column(db, v, 1, 2, 1)
      assert heads(db, v) == [["When", "People"], ["People", "When"], ["When", "People"]]
      # still one column: a change to it is made everywhere
      db = Core.set_column_width(db, v, {1, 0}, 20)
      assert Enum.map([{0, 1}, {1, 0}, {2, 1}], &column(db, v, &1).width) == [20, 20, 20]
    end

    test "a place past the end is the end", %{db: db, view_id: v} do
      db = Core.add_column(db, v, cat(db, "People"), {0, 0}, 12, :section)
      assert heads(Core.move_column(db, v, 0, 1, 9), v) |> hd() == ["When", "People"]
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

    test "from all sections: only that column, not another of the same head",
         %{db: db, view_id: v} do
      # what Agenda does: removing takes one column, from every section it is in
      db = Core.add_column(db, v, cat(db, "When"), {0, 0}, 12, :section)
      db = Core.add_column(db, v, cat(db, "When"), {0, 2}, 12, :all)
      assert heads(db, v) == [["When", "When", "When"], ["When", "When"], ["When", "When"]]
      db = Core.remove_column(db, v, {0, 2}, :all)
      assert heads(db, v) == [["When", "When"], ["When"], ["When"]]
      assert column(db, v, {0, 0}).link == nil
      assert column(db, v, {0, 1}).link == column(db, v, {1, 0}).link
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

    assert [[link]] =
             view.sections |> Enum.map(&Enum.map(&1.columns, fn c -> c.link end)) |> Enum.uniq()

    assert link != nil
  end

  test "columns linked the old way (by head) become one column per place",
       %{db: db, view_id: v} do
    # two When columns in Calls, one in Follow up, all `linked: true` as a
    # format 26 file has them: the first in each section are one column
    view = db.views[v]
    calls = Enum.at(view.sections, 0)
    calls = %{calls | columns: calls.columns ++ calls.columns}
    view = %{view | sections: List.replace_at(view.sections, 0, calls)}
    linked = MapSet.new([{0, 0}, {0, 1}, {1, 0}, {2, 0}])

    view = View.link_by_head(view, linked)
    links = Enum.map(view.sections, fn s -> Enum.map(s.columns, & &1.link) end)
    assert [[a, b], [a], [a]] = links
    assert a != b and a != nil and b != nil
  end

  test "a datebook view keeps one set of columns for all its slots", %{db: db} do
    {:ok, db, v} = Core.add_datebook_view(db, "Week", %Agenda.Core.Datebook{})
    db = Core.add_column(db, v, cat(db, "People"), {3, 0}, 12, :section)
    assert Enum.map(db.views[v].columns, & &1.category_id) == [cat(db, "People")]
    assert View.columns(db.views[v], 5) == db.views[v].columns
    assert View.columns_into_sections(db.views[v]) == db.views[v]
  end
end
