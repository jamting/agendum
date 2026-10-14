defmodule Agendum.Core.AssignTest do
  use ExUnit.Case, async: true

  import Agendum.Fixtures
  alias Agendum.Core
  alias Agendum.Core.{Assign, Database}

  setup do
    db =
      with_categories(Core.new_file(), [
        {"Priority", [exclusive: true, match_name: false], ["High", "Medium", "Low"]},
        {"People", [match_name: false], ["John Smith", "Anna"]},
        "Meetings"
      ])

    %{db: db}
  end

  describe "mutual exclusion" do
    test "assigning one child of an exclusive parent removes the siblings", %{db: db} do
      {db, item} = Core.add_item(db, "x", today())
      db = db |> Assign.assign(item, cat(db, "High")) |> Assign.assign(item, cat(db, "Low"))

      assert Database.explicit_categories(db, item) == MapSet.new([cat(db, "Low")])
    end

    test "non-exclusive parents allow several children", %{db: db} do
      {db, item} = Core.add_item(db, "x", today())

      db =
        db |> Assign.assign(item, cat(db, "John Smith")) |> Assign.assign(item, cat(db, "Anna"))

      assert MapSet.size(Database.explicit_categories(db, item)) == 2
    end

    test "conflict?/3", %{db: db} do
      assert Assign.conflict?(db, cat(db, "High"), cat(db, "Low"))
      refute Assign.conflict?(db, cat(db, "High"), cat(db, "High"))
      refute Assign.conflict?(db, cat(db, "High"), cat(db, "Priority"))
      refute Assign.conflict?(db, cat(db, "Anna"), cat(db, "John Smith"))
    end
  end

  describe "automatic assignment by text" do
    test "the patent's example: John Smith and Meetings", %{db: db} do
      {db, item} =
        Core.add_item(db, "Meet with John Smith on Tuesday", today(),
          section: cat(db, "Meetings")
        )

      assert Database.explicit_categories(db, item) ==
               MapSet.new([cat(db, "Meetings"), cat(db, "John Smith")])
    end

    test "matches whole words only, ignoring case and spacing" do
      assert Assign.name_in_text?("John Smith", "call JOHN   smith now")
      refute Assign.name_in_text?("Ann", "Call Anna")
      refute Assign.name_in_text?("Low", "follow up")
      assert Assign.name_in_text?("C++", "learn C++ today")
      assert Assign.name_in_text?("Åsa", "ring Åsa")
    end

    test "categories with match_name: false are not matched", %{db: db} do
      {db, item} = Core.add_item(db, "Discuss Priority list with People", today())
      assert Database.explicit_categories(db, item) == MapSet.new()
    end

    test "an explicit assignment wins over a conflicting text match", %{db: db} do
      {db, item} = Core.add_item(db, "Low hanging fruit", today(), section: cat(db, "High"))
      assert Database.explicit_categories(db, item) == MapSet.new([cat(db, "High")])
    end

    test "ambiguity is resolved using the previous item in the view (claim 7)", %{db: db} do
      {db, prev} = Core.add_item(db, "earlier", today(), section: cat(db, "Meetings"))
      db = Assign.assign(db, prev, cat(db, "Medium"))

      {db, item} = Core.add_item(db, "High or Medium, who knows", today(), adjacent: [prev])

      assert Database.explicit_categories(db, item) == MapSet.new([cat(db, "Medium")])
    end

    test "without adjacent items, the category created first wins", %{db: db} do
      {db, item} = Core.add_item(db, "Medium or High", today())
      assert Database.explicit_categories(db, item) == MapSet.new([cat(db, "High")])
    end
  end

  describe "category links (also_assign)" do
    test "follow links transitively and survive cycles", %{db: db} do
      [a, b] = [cat(db, "Meetings"), cat(db, "Anna")]

      db =
        db
        |> Database.update_category(a, &%{&1 | also_assign: [b]})
        |> Database.update_category(b, &%{&1 | also_assign: [a]})

      {db, item} = Core.add_item(db, "x", today(), section: a)
      assert Database.explicit_categories(db, item) == MapSet.new([a, b])
    end
  end

  test "unassign removes the category and its subtree", %{db: db} do
    {db, item} = Core.add_item(db, "x", today(), section: cat(db, "High"))
    db = Assign.unassign(db, item, cat(db, "Priority"))
    refute Database.member?(db, item, cat(db, "Priority"))
  end
end
