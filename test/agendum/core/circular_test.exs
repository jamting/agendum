# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.CircularTest do
  @moduledoc """
  Circular references (User's Guide 20-21 to 20-22): conditions that keep
  assigning an item to a category and taking it out again. Utilities ▸
  Show ▸ Circular shows the items caught in one, in the Show View under
  !Circular Reference! (checked in Agenda 2.0, 2026-10-26).
  """
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.ViewModel

  @today ~D[2026-10-26]

  # the manual's example: Ed, under People, assigns items not in People;
  # once in Ed an item is in People, so it leaves Ed, and so on. An item in
  # People already never meets the condition, and is not caught.
  defp contradiction do
    db = Core.new_file()
    {:ok, db, people} = Core.add_category(db, db.main_id, "People")
    {:ok, db, ed} = Core.add_category(db, people, "Ed")
    {:ok, db, anna} = Core.add_category(db, people, "Anna")
    {:ok, db} = Core.add_condition(db, ed, people, :not_assigned)
    {db, lunch} = Core.add_item(db, "Lunch", @today)
    db = Core.assign(db, lunch, anna, @today)
    {db, bank} = Core.add_item(db, "Call the bank", @today)
    {db, lunch, bank}
  end

  test "an item whose conditions never settle is caught in a circular reference" do
    {db, _lunch, bank} = contradiction()
    assert Core.circular_items(db, @today) == [bank]
  end

  test "Show Circular lists them in the Show View under !Circular Reference!" do
    {db, _, _} = contradiction()
    {db, view_id} = Core.show_circular(db, @today)
    [section] = ViewModel.build(db, db.views[view_id], @today)
    assert section.category.name == "!Circular Reference!"
    assert Enum.map(section.rows, & &1.item.id) == Core.circular_items(db, @today)
  end

  test "a file without contradictions has none" do
    db = Agendum.Sample.build(@today)
    assert Core.circular_items(db, @today) == []
  end
end
