defmodule Agendum.Core.ItemAssignmentsTest do
  use ExUnit.Case, async: true

  import Agendum.Fixtures
  alias Agendum.Core

  test "lists an item's assignments in hierarchy order: dates, explicit and conditional" do
    db = with_categories(Core.new_file(), [{"Work", [match_name: false], ["Calls"]}, "Watch"])
    {:ok, db} = Core.add_condition(db, cat(db, "Watch"), cat(db, "Calls"), :assigned)
    {db, item} = Core.add_item(db, "Ring Bob tomorrow", today(), section: cat(db, "Calls"))

    assert Core.item_assignments(db, item) == [
             %{category: db.special.entry, kind: :date, date: today()},
             %{category: db.special.when, kind: :date, date: ~D[2026-10-09]},
             %{category: cat(db, "Calls"), kind: :explicit, date: nil},
             %{category: cat(db, "Watch"), kind: :conditional, date: nil}
           ]
  end
end
