defmodule Agendum.Core.ColumnFormatsTest do
  @moduledoc """
  The Format of a standard column (User's Guide 5-26 to 5-37, Help
  "Standard Column Properties/Add Box"): Name only, Parent:Category,
  Ancestor, Star, Yes/No and Category note.
  """
  use ExUnit.Case, async: true

  import Agendum.Fixtures

  alias Agendum.Core
  alias Agendum.Core.{Database, ViewModel}
  alias Agendum.Core.View.Column

  # Staff ─ Sales ─ Tom (note: "Telephone: 555-1234" / "Room 12")
  #       └ Cooks
  # One item, "Contact Tom about the meeting", assigned to Tom; another to
  # nothing in Staff. The view's one section has a Staff column.
  setup do
    db = Core.new_file(view_name: "Tasks", section_name: "Tasks")
    db = with_categories(db, [{"Staff", [], [{"Sales", [], ["Tom"]}, "Cooks"]}])
    db = Core.set_category_note(db, cat(db, "Tom"), "Telephone: 555-1234\nRoom 12")
    [view] = Database.views(db)
    tasks = cat(db, "Tasks")
    {db, tom_item} = Core.add_item(db, "Contact Tom about the meeting", today(), section: tasks)
    db = Core.assign(db, tom_item, cat(db, "Tom"))
    {db, other} = Core.add_item(db, "Order paper", today(), section: tasks)
    db = Core.add_column(db, view.id, cat(db, "Staff"), {0, 0}, 20)
    %{db: db, view_id: view.id, tom_item: tom_item, other: other}
  end

  # what the Staff column shows for each item, with the column set to `format`
  defp shown(db, v, changes) do
    db = Core.set_column_display(db, v, {0, 0}, changes)
    [section] = ViewModel.build(db, db.views[v], today())
    Map.new(section.rows, &{&1.item.text, hd(&1.cells)})
  end

  test "a new column shows Name only", %{db: db, view_id: v} do
    assert %Column{format: :name, note_line: 1, title: nil} =
             hd(Core.View.columns(db.views[v], 0))

    assert shown(db, v, [])["Contact Tom about the meeting"] == "Tom"
  end

  test "Parent:Category: the category after its parent's name", %{db: db, view_id: v} do
    assert shown(db, v, format: :parent)["Contact Tom about the meeting"] == "Sales:Tom"
  end

  test "Ancestor: the column head's child the category is under", %{db: db, view_id: v} do
    assert shown(db, v, format: :ancestor)["Contact Tom about the meeting"] == "Sales"
  end

  test "Star: * for an item in the head, directly or not", %{db: db, view_id: v} do
    assert shown(db, v, format: :star) == %{
             "Contact Tom about the meeting" => "*",
             "Order paper" => ""
           }
  end

  test "Yes/No: Y or N", %{db: db, view_id: v} do
    assert shown(db, v, format: :yes_no) == %{
             "Contact Tom about the meeting" => "Y",
             "Order paper" => "N"
           }
  end

  test "Category note: a line of the category's note, without its label", %{db: db, view_id: v} do
    assert shown(db, v, format: :note)["Contact Tom about the meeting"] == "555-1234"
    assert shown(db, v, format: :note, note_line: 2)["Contact Tom about the meeting"] == "Room 12"
    assert shown(db, v, format: :note, note_line: 3)["Contact Tom about the meeting"] == ""
    assert shown(db, v, format: :note)["Order paper"] == ""
  end

  test "a Category note column is headed by its title", %{db: db, view_id: v} do
    db = Core.set_column_display(db, v, {0, 0}, format: :note, title: "Phone #")
    column = hd(Core.View.columns(db.views[v], 0))
    assert ViewModel.column_head(db, column) == "Phone #"
    # other formats, and a note column without a title: the head's name
    assert ViewModel.column_head(db, %{column | title: nil}) == "Staff"
    assert ViewModel.column_head(db, %{column | format: :name}) == "Staff"
  end

  test "line numbers are 1 to 999; a title is at most 69 characters", %{db: db, view_id: v} do
    db = Core.set_column_display(db, v, {0, 0}, note_line: 0, title: String.duplicate("x", 80))
    column = hd(Core.View.columns(db.views[v], 0))
    assert {column.note_line, String.length(column.title)} == {1, 69}
    db = Core.set_column_display(db, v, {0, 0}, note_line: 1000, title: "  ")
    column = hd(Core.View.columns(db.views[v], 0))
    assert {column.note_line, column.title} == {999, nil}
  end

  test "linked columns change format together", %{db: db, view_id: v} do
    {:ok, db, ideas} = Core.add_category(db, db.main_id, "Ideas")
    db = Core.add_section(db, v, ideas, 1, 0)
    db = Core.set_column_display(db, v, {1, 0}, format: :yes_no)

    assert Enum.map(0..1, &(db.views[v] |> Core.View.columns(&1) |> hd()).format) ==
             [:yes_no, :yes_no]
  end

  describe "added with a Format (Column Add)" do
    test "Star and Yes/No start 2 wide (User's Guide 5-31, 5-33)", %{db: db, view_id: v} do
      {:ok, db} = Core.add_column_as(db, v, cat(db, "Staff"), :standard, {0, 0}, format: :star)
      assert %Column{format: :star, width: 2} = hd(Core.View.columns(db.views[v], 0))
      assert Core.default_column_width(db, cat(db, "Staff"), :standard, :yes_no) == 2
    end

    test "Category note with its line and title", %{db: db, view_id: v} do
      opts = [format: :note, note_line: 2, title: "Room", width: 10]
      {:ok, db} = Core.add_column_as(db, v, cat(db, "Staff"), :standard, {0, 0}, opts)

      assert %Column{format: :note, note_line: 2, title: "Room", width: 10} =
               hd(Core.View.columns(db.views[v], 0))
    end

    test "a date or numeric column has no Format", %{db: db, view_id: v} do
      {:ok, db} = Core.add_column_as(db, v, db.special.when, :date, {0, 0}, format: :star)
      assert %Column{format: :name, width: 16} = hd(Core.View.columns(db.views[v], 0))
    end
  end

  describe "typing in the formats (User's Guide 5-31 to 5-37)" do
    test "Star and Yes/No: in the head directly, or out of it and all under it",
         %{db: db, tom_item: tom, other: other} do
      staff = cat(db, "Staff")
      db = Core.set_in_column(db, other, staff, true, today())
      assert Database.explicit?(db, other, staff)
      db = Core.set_in_column(db, tom, staff, false, today())
      refute Database.member?(db, tom, staff)
      # already in it (through Tom): nothing more is assigned
      db2 = Core.assign(db, tom, cat(db, "Tom"))
      refute Database.explicit?(Core.set_in_column(db2, tom, staff, true, today()), tom, staff)
    end

    test "Category note: the line of the item's category's note, its label kept",
         %{db: db, tom_item: tom, other: other} do
      staff = cat(db, "Staff")
      assert {:ok, db} = Core.set_column_note(db, tom, staff, 1, "555-9999")
      assert db.categories[cat(db, "Tom")].note == "Telephone: 555-9999\nRoom 12"
      assert {:ok, db} = Core.set_column_note(db, tom, staff, 4, "Floor 3")
      assert db.categories[cat(db, "Tom")].note == "Telephone: 555-9999\nRoom 12\n\nFloor 3"
      assert {:ok, db} = Core.set_column_note(db, tom, staff, 2, "")
      assert db.categories[cat(db, "Tom")].note == "Telephone: 555-9999\n\n\nFloor 3"
      assert Core.set_column_note(db, other, staff, 1, "x") == {:error, :no_category}
    end
  end

  describe "the category a column entry stands for (its note's ♪ and F5, User's Guide 12-2)" do
    defp column(db, v), do: db.views[v] |> Agendum.Core.View.columns(0) |> hd()

    test "the first category the entry shows, in every Format", %{
      db: db,
      view_id: v,
      tom_item: tom,
      other: other
    } do
      tom_id = cat(db, "Tom")
      assert ViewModel.entry_category(db, tom, column(db, v)) == tom_id
      assert ViewModel.entry_category(db, other, column(db, v)) == nil

      db = Core.set_column_display(db, v, {0, 0}, format: :note)
      assert ViewModel.entry_category(db, tom, column(db, v)) == tom_id
    end

    test "a Star or Yes/No entry of an item in the head itself: the head", %{
      db: db,
      view_id: v,
      other: other
    } do
      db = Core.assign(db, other, cat(db, "Staff"))
      db = Core.set_column_display(db, v, {0, 0}, format: :star)
      assert ViewModel.entry_category(db, other, column(db, v)) == cat(db, "Staff")
    end

    test "a date or a number is no category", %{db: db, view_id: v, tom_item: tom} do
      when_column = %{column(db, v) | category_id: db.special.when}
      assert ViewModel.entry_category(db, tom, when_column) == nil
    end
  end

  # ours (R73a)
  test "Zettel id: every item's id, whatever the head", %{db: db, view_id: v} = ctx do
    {:ok, db, _} = Core.attach_zettels(db, [ctx.other])
    shown = shown(db, v, format: :zettel)
    assert shown["Order paper"] == "bonalaku"
    assert shown["Contact Tom about the meeting"] == ""

    column = hd(Core.View.columns(db.views[v], 0))
    assert ViewModel.column_head(db, %{column | format: :zettel}) == "Zettel id"
    assert Core.default_column_width(db, nil, :standard, :zettel) == 9
  end
end
