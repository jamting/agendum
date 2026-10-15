defmodule Agendum.Core.FileStatisticsTest do
  @moduledoc """
  File ▸ Properties ▸ File statistics (Agenda's File Statistics box): how
  big the file is.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.Database

  @today ~D[2026-10-08]

  test "a new file: no items, its own categories" do
    db = Core.new_file()

    assert %{items: 0, items_with_notes: 0, items_per_category: 0, categories_per_item: 0} =
             Database.file_statistics(db)

    assert Database.file_statistics(db).categories == map_size(db.categories)
  end

  test "items, notes and the averages of the assignments, rounded down" do
    db = Core.new_file(view_name: "Activities", section_name: "Calls")
    {:ok, db, urgent} = Core.add_category(db, db.main_id, "Urgent")
    {db, one} = Core.add_item(db, "Call Anna", @today)
    {db, _two} = Core.add_item(db, "Write the plan", @today)
    db = db |> Core.set_note(one, "Her number is in the book", @today)
    db = Database.link(db, one, urgent)

    stats = Database.file_statistics(db)
    assignments = Agendum.Core.Links.size(db.links)
    assert %{items: 2, items_with_notes: 1} = stats
    assert stats.categories == map_size(db.categories)
    assert stats.categories_per_item == div(assignments, 2)
    assert stats.items_per_category == div(assignments, stats.categories)
  end
end
