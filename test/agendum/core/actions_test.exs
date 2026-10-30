# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.ActionsTest do
  @moduledoc """
  Actions (R15b; User's Guide chapter 21): when an item is assigned to a
  category, its actions remove other assignments, set or clear dates and
  numbers, or mark the item done or discard it, once.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.Database

  # Thursday
  @today ~D[2026-10-08]

  setup do
    db = Core.new_file()

    {db, c} =
      Enum.reduce(
        ~w(Paid Receivables Taxes Reschedule Delegated Junk Design Amount),
        {db, %{}},
        fn
          name, {db, c} ->
            {:ok, db, id} = Core.add_category(db, db.main_id, name, match_name: false)
            {db, Map.put(c, name, id)}
        end
      )

    {:ok, db, sue} = Core.add_category(db, c["Design"], "Sue", match_name: false)
    {:ok, db} = Core.make_numeric(db, c["Amount"])
    {db, item} = Core.add_item(db, "Invoice 42", @today)
    %{db: db, c: Map.put(c, "Sue", sue), item: item}
  end

  test "an assignment action breaks another assignment", %{db: db, c: c, item: item} do
    {:ok, db} = Core.set_action(db, c["Paid"], c["Receivables"], :remove)
    db = Core.assign(db, item, c["Receivables"], @today)
    assert Database.member?(db, item, c["Receivables"])

    db = Core.assign(db, item, c["Paid"], @today)
    refute Database.member?(db, item, c["Receivables"])
  end

  test "a date action sets a date, read when the action runs", %{db: db, c: c, item: item} do
    {:ok, db} = Core.set_action(db, c["Taxes"], db.special.when, {:set, "tomorrow"}, @today)
    db = Core.assign(db, item, c["Taxes"], @today)
    assert db.items[item].when == ~D[2026-10-09]
  end

  test "a date action can clear the date", %{db: db, c: c, item: item} do
    {:ok, db} = Core.set_action(db, c["Reschedule"], db.special.when, :clear)
    db = Core.set_date(db, item, db.special.when, ~D[2026-11-01], @today)
    db = Core.assign(db, item, c["Reschedule"], @today)
    assert db.items[item].when == nil
  end

  test "a numeric action sets or clears a number", %{db: db, c: c, item: item} do
    {:ok, db} = Core.set_action(db, c["Taxes"], c["Amount"], {:set, "150"}, @today)
    db = Core.assign(db, item, c["Taxes"], @today)
    assert Database.number(db, item, c["Amount"]) == 150.0

    {:ok, db} = Core.set_action(db, c["Paid"], c["Amount"], :clear)
    db = Core.assign(db, item, c["Paid"], @today)
    assert Database.number(db, item, c["Amount"]) == nil
  end

  test "special actions mark the item done or discard it", %{db: db, c: c, item: item} do
    {:ok, db} = Core.set_special_action(db, c["Delegated"], :done)
    {:ok, db} = Core.set_special_action(db, c["Junk"], :discard)

    done = Core.assign(db, item, c["Delegated"], @today)
    assert done.items[item].done == @today

    gone = Core.assign(db, item, c["Junk"], @today)
    refute Map.has_key?(gone.items, item)
  end

  test "actions run only when the item becomes a member", %{db: db, c: c, item: item} do
    {:ok, db} = Core.set_action(db, c["Taxes"], db.special.when, {:set, "tomorrow"}, @today)
    db = Core.assign(db, item, c["Taxes"], @today)
    db = Core.set_date(db, item, db.special.when, ~D[2026-12-24], @today)

    # assigning again, or another change, does not run it again
    db = Core.assign(db, item, c["Taxes"], @today)
    db = Core.edit_item(db, item, "Invoice 42 (paid)", @today)
    assert db.items[item].when == ~D[2026-12-24]
  end

  test "a parent's actions apply to items assigned to its children", %{db: db, c: c, item: item} do
    {:ok, db} = Core.set_special_action(db, c["Design"], :done)
    db = Core.assign(db, item, c["Sue"], @today)
    assert db.items[item].done == @today
  end

  test "actions make explicit assignments that stay", %{db: db, c: c, item: item} do
    db = Core.toggle_also_assign(db, c["Taxes"], c["Paid"])
    db = Core.assign(db, item, c["Taxes"], @today)
    db = Core.remove_from_category(db, item, c["Taxes"], @today)
    assert Database.member?(db, item, c["Paid"])
  end

  test "items pulled in by a condition trigger actions too", %{db: db, c: c, item: item} do
    {:ok, db} = Core.add_condition(db, c["Delegated"], c["Taxes"], :assigned)
    {:ok, db} = Core.set_special_action(db, c["Delegated"], :done)
    db = Core.assign(db, item, c["Taxes"], @today)
    assert db.items[item].done == @today
  end

  test "bad values are refused; actions can be cleared", %{db: db, c: c} do
    assert Core.set_action(db, c["Taxes"], db.special.when, {:set, "someday"}, @today) ==
             {:error, :invalid_date}

    assert Core.set_action(db, c["Taxes"], c["Amount"], {:set, "lots"}, @today) ==
             {:error, :not_a_number}

    assert Core.set_action(db, c["Taxes"], c["Taxes"], :remove) == {:error, :self}

    {:ok, db} = Core.set_action(db, c["Paid"], c["Receivables"], :remove)
    db = Core.remove_action(db, c["Paid"], c["Receivables"])
    assert db.categories[c["Paid"]].actions == []
  end
end
