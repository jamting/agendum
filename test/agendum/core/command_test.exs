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

  describe "adding and editing items" do
    setup %{db: db} do
      db = with_categories(db, ["Work", "Urgent", "Anna"])
      %{db: db, work: cat(db, "Work"), urgent: cat(db, "Urgent")}
    end

    test "adds an item under a category, placed after another, and names it", %{
      db: db,
      a: a,
      work: work
    } do
      {:ok, db, changes} =
        Core.run(db, {:add_item, "Call Anna", section: work, after: a}, today())

      id = changes.new
      assert changes.items.added == [id]
      assert db.items[id].text == "Call Anna"
      assert Agendum.Core.Database.explicit?(db, id, work)
      # matched by its text, as typing it does (R10)
      assert Agendum.Core.Database.member?(db, id, cat(db, "Anna"))
      assert Enum.drop_while(db.item_order, &(&1 != a)) |> Enum.at(1) == id
    end

    test "an item added in a view's section gets what the section's filter needs (R28)", %{
      db: db,
      work: work,
      urgent: urgent
    } do
      {db, view} = Core.add_view(db, "Work", [work])
      {:ok, db} = Core.cycle_filter(db, view, {:section, 0}, urgent)

      {:ok, db, changes} =
        Core.run(db, {:add_item, "Plan", section: work, view_section: {view, 0}}, today())

      assert Agendum.Core.Database.explicit?(db, changes.new, urgent)
    end

    test "a datebook slot's date comes with the item (R47)", %{db: db} do
      when_cat = db.special.when
      date = {when_cat, ~D[2026-10-09], ~T[10:00:00]}
      {:ok, db, changes} = Core.run(db, {:add_item, "Dentist", date: date}, today())

      assert db.items[changes.new].when == ~D[2026-10-09]
    end

    test "edits an item's text, filing it anew by what it now says", %{db: db, a: a} do
      {:ok, db, changes} = Core.run(db, {:edit_item, a, "Ask Anna"}, today())

      assert db.items[a].text == "Ask Anna"
      assert Agendum.Core.Database.member?(db, a, cat(db, "Anna"))
      assert changes.items.changed == [a]
    end

    test "empty text is refused; ids that do not exist are refused", %{db: db, a: a, work: work} do
      assert Core.run(db, {:add_item, "  ", []}, today()) == {:error, :empty_text}
      assert Core.run(db, {:edit_item, a, ""}, today()) == {:error, :empty_text}
      assert Core.run(db, {:edit_item, 999, "x"}, today()) == {:error, :no_such_item}
      assert Core.run(db, {:add_item, "x", section: 999}, today()) == {:error, :no_such_category}
      assert Core.run(db, {:add_item, "x", after: 999}, today()) == {:error, :no_such_item}
      assert Core.run(db, {:add_item, "x", section: a}, today()) == {:error, :no_such_category}

      assert Core.run(db, {:add_item, "x", section: work, view_section: {999, 0}}, today()) ==
               {:error, :no_such_view}
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

  test "clearing a column takes an item out of the head's children it is in", %{db: db, a: a} do
    db = with_categories(db, [{"Who", [], ["Anna", "Bo"]}])
    who = cat(db, "Who")

    {:ok, db, _} =
      Core.run(
        db,
        {:batch, [{:assign, a, cat(db, "Anna")}, {:assign, a, cat(db, "Bo")}]},
        today()
      )

    {:ok, db, changes} = Core.run(db, {:clear_column, a, who}, today())
    refute Agendum.Core.Database.member?(db, a, cat(db, "Anna"))
    refute Agendum.Core.Database.member?(db, a, cat(db, "Bo"))
    assert changes.items.changed == [a]
  end

  describe "typing in a column" do
    setup %{db: db} do
      db = with_categories(db, [{"Who", [], ["Anna", "Bo"]}])
      %{db: db, who: cat(db, "Who"), anna: cat(db, "Anna"), bo: cat(db, "Bo")}
    end

    test "a name typed over an entry replaces it", %{db: db, a: a, who: who, anna: anna, bo: bo} do
      {:ok, db, _} = Core.run(db, {:type_in_column, a, who, {:name, "Anna"}, false}, today())
      {:ok, db, _} = Core.run(db, {:type_in_column, a, who, {:name, "Bo"}, true}, today())

      refute Agendum.Core.Database.member?(db, a, anna)
      assert Agendum.Core.Database.member?(db, a, bo)
    end

    test "added, not replacing; a new child; a category picked", %{db: db, a: a, who: who, bo: bo} do
      {:ok, db, _} = Core.run(db, {:type_in_column, a, who, {:category, bo}, false}, today())
      {:ok, db, changes} = Core.run(db, {:type_in_column, a, who, {:new, "Cleo"}, false}, today())

      assert db.categories[changes.new].name == "Cleo"
      assert Agendum.Core.Database.member?(db, a, bo)
    end

    test "nothing typed over an entry keeps it", %{db: db, a: a, who: who, anna: anna} do
      {:ok, db, _} = Core.run(db, {:type_in_column, a, who, {:category, anna}, false}, today())

      assert Core.run(db, {:type_in_column, a, who, {:name, " "}, true}, today()) ==
               {:error, :empty}
    end
  end

  test "a condition set replaces the one on that category", %{db: db} do
    db = with_categories(db, ["Work", "Home"])
    {work, home} = {cat(db, "Work"), cat(db, "Home")}
    {:ok, db, _} = Core.run(db, {:add_condition, work, home, :assigned}, today())
    {:ok, db, _} = Core.run(db, {:set_condition, work, home, :not_assigned}, today())

    assert db.categories[work].conditions == [{home, :not_assigned}]
  end

  describe "several commands as one" do
    test "a batch runs its commands in turn, as one change", %{db: db, a: a, b: b} do
      {:ok, db, changes} =
        Core.run(db, {:batch, [{:toggle_mark, a}, {:add_item, "c", after: b}]}, today())

      assert db.items[a].marked
      assert [new] = changes.items.added
      assert changes.new == new
      assert changes.steps == [%{}, %{new: new}]
    end

    test "if one is refused, none is made", %{db: db, a: a} do
      assert Core.run(db, {:batch, [{:toggle_mark, a}, {:toggle_mark, 999}]}, today()) ==
               {:error, :no_such_item}
    end
  end

  test "a command with the wrong number of arguments is refused", %{db: db, a: a} do
    assert Core.run(db, {:toggle_mark, a, a}, today()) == {:error, :bad_arguments}
    assert Core.run(db, {:mark_done, a}, today()) == {:error, :bad_arguments}
  end

  test "every command that calls the facade has a function of its arity there" do
    for {id, kinds, how} <- Command.runs(), how in [:core, :clock] do
      arity = 1 + length(kinds) + if(how == :clock, do: 1, else: 0)
      assert function_exported?(Core, id, arity), "Agendum.Core.#{id}/#{arity} is missing"
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
