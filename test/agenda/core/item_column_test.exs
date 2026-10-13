defmodule Agenda.Core.ItemColumnTest do
  @moduledoc """
  The item column of each section (R55; User's Guide 3-18 to 3-19, Help
  "Item Column Properties Box"): its width set automatically (as wide as
  the columns leave, at least a minimum) or by hand, and linked with the
  item columns of the other sections, so a change to one is made to all
  the linked ones.
  """
  use ExUnit.Case, async: true

  import Agenda.Fixtures

  alias Agenda.Core
  alias Agenda.Core.{Database, ViewModel}
  alias Agenda.Core.View.ItemColumn

  # Calls, Follow up and Ideas
  setup do
    db = Core.new_file(view_name: "Activities", section_name: "Calls")
    db = with_categories(db, ["Follow up", "Ideas"])
    [view] = Database.views(db)
    db = Core.add_section(db, view.id, cat(db, "Follow up"), 1)
    db = Core.add_section(db, view.id, cat(db, "Ideas"), 2)
    %{db: db, view_id: view.id}
  end

  defp items(db, view_id), do: Enum.map(db.views[view_id].sections, & &1.item_column)

  test "every section starts automatic and linked, at least 10 wide", %{db: db, view_id: v} do
    assert items(db, v) == List.duplicate(%ItemColumn{}, 3)
    assert %ItemColumn{set: :auto, minimum: 10, linked: true} = %ItemColumn{}
  end

  test "a change to a linked item column is made to all the linked ones", %{db: db, view_id: v} do
    db = Core.set_item_column(db, v, 1, set: :manual, width: 50)
    assert Enum.map(items(db, v), &{&1.set, &1.width}) == List.duplicate({:manual, 50}, 3)
  end

  test "an unlinked one changes alone, and the others leave it alone", %{db: db, view_id: v} do
    db = Core.set_item_column_linked(db, v, 2, false)
    db = Core.set_item_column(db, v, 2, minimum: 20)
    db = Core.set_item_column(db, v, 0, minimum: 15)
    assert Enum.map(items(db, v), & &1.minimum) == [15, 15, 20]
  end

  test "linking again takes the settings of the linked ones", %{db: db, view_id: v} do
    db = Core.set_item_column_linked(db, v, 2, false)
    db = Core.set_item_column(db, v, 2, set: :manual, width: 30)
    db = Core.set_item_column(db, v, 0, minimum: 15)
    db = Core.set_item_column_linked(db, v, 2, true)
    assert Enum.at(items(db, v), 2) == %ItemColumn{minimum: 15}
  end

  test "widths are kept between 5 and 200", %{db: db, view_id: v} do
    db = Core.set_item_column(db, v, 0, width: 1, minimum: 999)
    assert {hd(items(db, v)).width, hd(items(db, v)).minimum} == {5, 200}
  end

  test "a new section gets the item column of the one it was added from, if linked",
       %{db: db, view_id: v} do
    db = Core.set_item_column(db, v, 0, set: :manual, width: 44)
    db = Core.add_section(db, v, cat(db, "Ideas"), 3, 0)
    assert Enum.at(items(db, v), 3) == %ItemColumn{set: :manual, width: 44}

    db = Core.set_item_column_linked(db, v, 1, false)
    db = Core.add_section(db, v, cat(db, "Ideas"), 4, 1)
    # from an unlinked one: the linked ones' settings, as a new column gets
    assert Enum.at(items(db, v), 4) == %ItemColumn{set: :manual, width: 44}
  end

  test "the view model carries each section's item column", %{db: db, view_id: v} do
    db = Core.set_item_column_linked(db, v, 1, false)
    db = Core.set_item_column(db, v, 1, set: :manual, width: 33)
    model = ViewModel.build(db, db.views[v], ~D[2026-10-13])
    assert Enum.map(model, & &1.item_column.set) == [:auto, :manual, :auto]
  end

  test "the item column's text width: by hand, or what the columns leave" do
    columns = [%Core.View.Column{category_id: 1, width: 12}]
    # 80 wide: 3 for the bullet and margin, 13 for the column
    assert ItemColumn.text_width(%ItemColumn{}, columns, 80) == 64
    assert ItemColumn.text_width(%ItemColumn{minimum: 70}, columns, 80) == 70
    assert ItemColumn.text_width(%ItemColumn{set: :manual, width: 30}, columns, 80) == 30
  end
end
