# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.ReasonsTest do
  @moduledoc "Why an item is in a category (R67): the reasons that hold now."
  use ExUnit.Case, async: true

  import Agendum.Fixtures
  alias Agendum.Core

  setup do
    db = with_categories(Core.new_file(), [{"People", [], ["Kanga", "Roo"]}, "Calls", "Urgent"])
    %{db: db}
  end

  test "MAIN, a date, and not in it at all", %{db: db} do
    {db, id} = Core.add_item(db, "Water the garden friday", today())

    assert Core.assignment_reasons(db, id, db.main_id) == [:main]
    assert [{:date, %Date{}}] = Core.assignment_reasons(db, id, db.special.when)
    assert Core.assignment_reasons(db, id, db.special.done) == []
    assert Core.assignment_reasons(db, id, cat(db, "Calls")) == []
  end

  test "a text match, and through a child", %{db: db} do
    {db, id} = Core.add_item(db, "Ask Kanga about lunch", today())

    assert Core.assignment_reasons(db, id, cat(db, "Kanga")) == [:text_match]
    assert Core.assignment_reasons(db, id, cat(db, "People")) == [{:through, cat(db, "Kanga")}]
  end

  test "by hand, and an action", %{db: db} do
    {calls, urgent} = {cat(db, "Calls"), cat(db, "Urgent")}
    db = Core.toggle_also_assign(db, calls, urgent)
    {db, id} = Core.add_item(db, "Phone the dentist", today())
    db = Core.assign(db, id, calls, today())

    assert Core.assignment_reasons(db, id, calls) == [:assigned]
    assert Core.assignment_reasons(db, id, urgent) == [{:action, calls}]
  end

  test "a condition", %{db: db} do
    {calls, urgent} = {cat(db, "Calls"), cat(db, "Urgent")}
    {:ok, db} = Core.add_condition(db, urgent, calls, :assigned)
    {db, id} = Core.add_item(db, "Phone the dentist", today())
    db = Core.assign(db, id, calls, today())

    assert Core.assignment_reasons(db, id, urgent) == [{:condition, [{calls, :assigned}]}]
  end
end
