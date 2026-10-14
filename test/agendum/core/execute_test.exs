defmodule Agendum.Core.ExecuteTest do
  @moduledoc """
  Utilities Execute (R15e; User's Guide 20-19 to 20-21, 21-17): apply
  conditions, text conditions and actions to items already in the file.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.Database

  @today ~D[2026-10-08]

  # Two items exist before Meetings gets its text condition and Taxes its
  # special action.
  setup do
    db = Core.new_file()
    {:ok, db, meetings} = Core.add_category(db, db.main_id, "Meetings")
    {:ok, db, taxes} = Core.add_category(db, db.main_id, "Taxes")
    {:ok, db, people} = Core.add_category(db, db.main_id, "People")
    {:ok, db, ann} = Core.add_category(db, people, "Ann")
    {db, meet} = Core.add_item(db, "Talk to Bob", @today)
    {db, tax} = Core.add_item(db, "Pay taxes", @today)
    {db, call} = Core.add_item(db, "Call", @today)

    {:ok, db} = Core.set_also_match(db, meetings, "(talk to)")
    {:ok, db} = Core.set_special_action(db, taxes, :done)
    {:ok, db} = Core.set_also_match(db, ann, "call")

    %{
      db: db,
      meetings: meetings,
      taxes: taxes,
      people: people,
      ann: ann,
      meet: meet,
      tax: tax,
      call: call
    }
  end

  test "new conditions reach existing items", %{db: db, meetings: meetings, meet: meet} do
    refute Database.member?(db, meet, meetings)
    db = Core.execute(db, db.item_order, clock: @today)
    assert Database.member?(db, meet, meetings)
  end

  test "new actions run on old assignments only when asked", %{db: db, tax: tax} do
    assert Core.execute(db, db.item_order, clock: @today).items[tax].done == nil

    db = Core.execute(db, db.item_order, clock: @today, old_assignments: true)
    assert db.items[tax].done == @today
  end

  test "only the conditions of one family", %{db: db, people: people, ann: ann} = c do
    db = Core.execute(db, db.item_order, clock: @today, root: people)
    assert Database.member?(db, c.call, ann)
    refute Database.member?(db, c.meet, c.meetings)
  end

  test "only some items", %{db: db, meetings: meetings, meet: meet, ann: ann, call: call} do
    db = Core.execute(db, [call], clock: @today)
    assert Database.member?(db, call, ann)
    refute Database.member?(db, meet, meetings)
  end
end
