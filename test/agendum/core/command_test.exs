defmodule Agendum.Core.CommandTest do
  @moduledoc """
  The command layer (R66, ADR 0036): a user action is a named command,
  run by the core on ids, returning the new database and what changed.
  """
  use ExUnit.Case, async: true

  import Agendum.Fixtures
  alias Agendum.Core
  alias Agendum.Core.Command

  setup do
    db = Core.new_file()
    {db, a} = Core.add_item(db, "a", today())
    {db, b} = Core.add_item(db, "b", today())
    %{db: db, a: a, b: b}
  end

  describe "running a command" do
    test "marks and unmarks an item, saying which", %{db: db, a: a} do
      assert {:ok, db, changes} = Core.run(db, {:toggle_mark, a}, today())
      assert db.items[a].marked
      assert changes.items == %{added: [], changed: [a], removed: []}

      assert {:ok, db, _} = Core.run(db, {:toggle_mark, a}, today())
      refute db.items[a].marked
    end

    test "marks or unmarks a group, and unmarks every item", %{db: db, a: a, b: b} do
      {:ok, db, changes} = Core.run(db, {:set_marked, [a, b], true}, today())
      assert Core.marked_items(db) == [a, b]
      assert changes.items.changed == [a, b]

      {:ok, db, changes} = Core.run(db, :unmark_all, today())
      assert Core.marked_items(db) == []
      assert changes.items.changed == [a, b]
    end

    test "done on one item toggles; done on several only sets", %{db: db, a: a, b: b} do
      {:ok, db, _} = Core.run(db, {:toggle_done, a}, ~D[2026-10-01])
      assert db.items[a].done == ~D[2026-10-01]

      {:ok, db, changes} = Core.run(db, {:mark_done, [a, b]}, today())
      assert db.items[a].done == ~D[2026-10-01]
      assert db.items[b].done == today()
      assert changes.items.changed == [b]

      {:ok, db, _} = Core.run(db, {:toggle_done, a}, today())
      assert db.items[a].done == nil
    end

    test "a recurring item marked done is followed by a new one, reported as added" do
      {db, id} = Core.add_item(Core.new_file(), "Water plants every Monday", today())
      {:ok, db, changes} = Core.run(db, {:toggle_done, id}, today())

      assert [copy] = changes.items.added
      assert db.items[copy].text == "Water plants every Monday"
      assert id in changes.items.changed
    end

    test "discards items from the whole file", %{db: db, a: a, b: b} do
      {:ok, db, changes} = Core.run(db, {:discard_items, [a]}, today())
      assert Map.keys(db.items) == [b]
      assert changes.items.removed == [a]
    end

    test "an id that is not an item is refused, and nothing changes", %{db: db, a: a} do
      assert Core.run(db, {:toggle_mark, 999}, today()) == {:error, :no_such_item}
      assert Core.run(db, {:mark_done, [a, 999]}, today()) == {:error, :no_such_item}
      assert Core.run(db, {:discard_items, [db.main_id]}, today()) == {:error, :no_such_item}
    end

    test "an unknown command is refused", %{db: db} do
      assert Core.run(db, {:fly_away, 1}, today()) == {:error, :unknown_command}
    end
  end

  describe "what changed" do
    test "nothing, when the command changed nothing", %{db: db, a: a} do
      {:ok, db, _} = Core.run(db, {:toggle_done, a}, today())
      {:ok, _db, changes} = Core.run(db, {:mark_done, [a]}, today())
      assert Command.Changes.none?(changes)
    end

    test "an assignment counts as a change to the item, not to the category", %{db: db, a: a} do
      db = with_categories(db, ["Work"])
      work = cat(db, "Work")
      changes = Command.Changes.between(db, Core.assign(db, a, work))

      assert changes.items.changed == [a]
      assert changes.categories.changed == []
    end

    test "a new category, and a setting of the file", %{db: db} do
      after_ = with_categories(db, ["Work"])
      assert changes = Command.Changes.between(db, after_)
      assert changes.categories.added == [cat(after_, "Work")]

      format = %{db.date_format | clock: 12}
      changes = Command.Changes.between(db, Core.set_date_format(db, format))
      assert changes.file == [:date_format]
    end
  end

  describe "the commands describe themselves" do
    test "each has a name and a summary" do
      assert Command.ids() == Enum.uniq(Command.ids())

      for id <- Command.ids() do
        assert %{id: ^id, name: name, summary: summary, args: args} = Command.describe(id)
        assert is_binary(name) and is_binary(summary) and is_list(args)
      end
    end
  end
end
