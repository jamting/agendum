# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.MarksTest do
  use ExUnit.Case, async: true

  import Agendum.Fixtures
  alias Agendum.Core

  setup do
    db = Core.new_file()
    {db, a} = Core.add_item(db, "a", today())
    {db, b} = Core.add_item(db, "b", today())
    {db, c} = Core.add_item(db, "c", today())
    %{db: db, a: a, b: b, c: c}
  end

  test "marked_items lists marked items in item order", %{db: db, a: a, c: c} do
    db = db |> Core.toggle_mark(c) |> Core.toggle_mark(a)
    assert Core.marked_items(db) == [a, c]
  end

  test "set_marked marks or unmarks a group; unmark_all clears every mark", %{db: db, a: a, b: b} do
    db = Core.set_marked(db, [a, b], true)
    assert Core.marked_items(db) == [a, b]
    assert Core.marked_items(Core.set_marked(db, [a], false)) == [b]
    assert Core.marked_items(Core.unmark_all(db)) == []
  end

  test "mark_done sets a done date only where there is none", %{db: db, a: a, b: b} do
    db = Core.toggle_done(db, a, ~D[2026-10-01])
    db = db |> Core.mark_done(a, today()) |> Core.mark_done(b, today())
    assert db.items[a].done == ~D[2026-10-01]
    assert db.items[b].done == today()
  end
end
