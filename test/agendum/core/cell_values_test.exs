defmodule Agendum.Core.CellValuesTest do
  @moduledoc """
  Raw values beside the formatted cells (ROADMAP, Towards many users):
  each row of a built view holds what each cell shows as data, the same
  for every format, for a front end that formats or sorts it itself.
  """
  use ExUnit.Case, async: true

  import Agendum.Fixtures

  alias Agendum.Core
  alias Agendum.Core.{Database, ViewModel}

  setup do
    db = Core.new_file(view_name: "Tasks", section_name: "Tasks")
    db = with_categories(db, [{"Staff", [], ["Tom", "Ann"]}, "Urgent"])
    {:ok, db} = Core.make_numeric(db, cat(db, "Urgent"))
    [view] = Database.views(db)
    tasks = cat(db, "Tasks")
    {db, item} = Core.add_item(db, "Call Tom friday", today(), section: tasks)
    db = Core.assign(db, item, cat(db, "Tom"))
    %{db: db, view: view, item: item}
  end

  test "a standard column: the ids of the categories it shows", %{db: db, item: item} do
    assert ViewModel.value(db, db.items[item], cat(db, "Staff")) == [cat(db, "Tom")]
  end

  test "a date column: the date and time", %{db: db, item: item} do
    assert {%Date{}, nil} = ViewModel.value(db, db.items[item], db.special.when)
    assert ViewModel.value(db, db.items[item], db.special.done) == nil
  end

  test "a numeric column: the number", %{db: db, item: item} do
    urgent = cat(db, "Urgent")
    assert ViewModel.value(db, db.items[item], urgent) == nil
    {:ok, db} = Core.set_number(db, item, urgent, 3)
    assert ViewModel.value(db, db.items[item], urgent) == 3.0
  end

  test "a row of a built view holds one value per column", %{db: db, view: view, item: item} do
    db = Core.add_column(db, view.id, cat(db, "Staff"), {0, 0}, 20)
    [section] = ViewModel.build(db, Database.view(db, view.id), today())
    [row] = section.rows

    assert row.item.id == item
    # the Staff column added first, then the view's own When column
    assert [staff, {%Date{}, nil}] = row.values
    assert staff == [cat(db, "Tom")]
    assert length(row.values) == length(row.cells)
  end
end
