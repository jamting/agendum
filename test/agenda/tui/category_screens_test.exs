defmodule Agenda.TUI.CategoryScreensTest do
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.Core.Database

  setup do
    %{state: start(Agenda.Sample.build(~D[2026-10-08]))}
  end

  defp cat(state, name), do: hd(Database.find_categories(state.db, name))

  test "F9 shows the hierarchy", %{state: state} do
    screen = state |> press({:f, 9}) |> screen()
    assert screen =~ "Category Manager"
    assert screen =~ ~r/Priority\s+exclusive/
    assert screen =~ ~r/\n\s{7}High/
  end

  test "typing adds a sibling, F8 demotes it, F7 promotes it", %{state: state} do
    # MAIN, Entry, When, Done, Calls, Priority, High
    state = press(state, [{:f, 9}, :down, :down, :down, :down, :down, :down, "Urgent", :enter])
    urgent = cat(state, "Urgent")
    assert state.db.categories[urgent].parent_id == cat(state, "Priority")

    assert state.db.categories[cat(state, "Priority")].children |> Enum.take(2) == [
             cat(state, "High"),
             urgent
           ]

    state = press(state, [{:f, 8}])
    assert state.db.categories[urgent].parent_id == cat(state, "High")

    state = press(state, [{:f, 7}])
    assert state.db.categories[urgent].parent_id == cat(state, "Priority")
  end

  test "protected categories cannot be discarded", %{state: state} do
    state = press(state, [{:f, 9}, :delete])
    assert screen(state) =~ "MAIN cannot be discarded"
  end

  test "F6 in the view opens the assignment profile; SPACE toggles", %{state: state} do
    state = press(state, [:down, {:f, 6}])
    assert screen(state) =~ "Assignments:"
    # rows: Entry When Done Calls Priority High Medium ... → Meetings is last
    state = press(state, [:ctrl_end, " "])
    item = hd(Database.items(state.db))
    assert Database.member?(state.db, item.id, cat(state, "Meetings"))
  end

  test "category properties toggle exclusivity", %{state: state} do
    state = press(state, [{:f, 9}, :ctrl_end, {:f, 6}, :down, :down, :enter])
    assert state.db.categories[cat(state, "Meetings")].exclusive
  end

  test "F8 view manager adds a view", %{state: state} do
    state = press(state, [{:f, 8}, :insert, "People", :enter, "Contact", :enter])
    assert Agenda.TUI.State.view(state).name == "People"
    assert screen(state) =~ ~r/Contact/
    assert state.modes == []
  end

  test "navigating an empty category box does not crash", %{state: state} do
    # Meetings has no subcategories: its column choices box is empty
    state = press(state, [:down, {:alt, "r"}, "Meet", :enter, {:f, 3}])
    assert screen(state) =~ "no categories yet"
    state = press(state, [:ctrl_pgdn, :down, :home, :end])
    assert %{type: :picker} = Agenda.TUI.State.mode(state)
  end

  test "category properties set a short name", %{state: state} do
    # Meetings is last; the second property is the short name
    state = press(state, [{:f, 9}, :ctrl_end, {:f, 6}, :down, :enter, "mtg", :enter])
    assert state.db.categories[cat(state, "Meetings")].short_name == "mtg"
  end

  test "ALT-↓ in the view manager reorders views", %{state: state} do
    state = press(state, [{:f, 8}, :insert, "People", :enter, "Contact", :enter])
    people = state.view_id
    state = press(state, [{:f, 8}, :up, {:alt, :down}])
    assert List.first(state.db.view_order) == people
  end

  describe "making children mutually exclusive with conflicts" do
    setup %{state: state} do
      # the Anna Lasky item also gets Daniel Fiske -> two Contact children
      state = press(state, [:down, :down, :right, :right, :right, {:ctrl, "n"}, "Daniel", :enter])
      item = Agenda.TUI.Layout.current_row(state).item.id
      # category manager: MAIN Entry When Done Calls Priority High Medium Low Contact
      opened =
        press(state, [{:f, 9}] ++ List.duplicate(:down, 9) ++ [{:f, 6}, :down, :down, :enter])

      %{opened: opened, item: item}
    end

    defp contacts(state, item) do
      contact = cat(state, "Contact")

      state.db
      |> Database.explicit_categories(item)
      |> Enum.filter(&(state.db.categories[&1].parent_id == contact or &1 == contact))
      |> Enum.map(&state.db.categories[&1].name)
      |> Enum.sort()
    end

    test "the conflict box appears with Agenda's three choices", %{opened: state} do
      screen = screen(state)
      assert screen =~ "Make children of Contact mutually exclusive"
      assert screen =~ "1 item(s) are assigned to more than one child."
      assert screen =~ "Parent category"
      assert screen =~ "Existing category"
      assert screen =~ "New category"
    end

    test "ENTER takes the default, Parent category", %{opened: state, item: item} do
      state = press(state, :enter)
      assert state.db.categories[cat(state, "Contact")].exclusive
      assert contacts(state, item) == ["Contact"]
      assert screen(state) =~ "1 conflicting item(s) reassigned"
    end

    test "Existing category keeps the child closest to the top", %{opened: state, item: item} do
      state = press(state, "e")
      assert contacts(state, item) == ["Anna Lasky"]
    end

    test "New category prompts for a name", %{opened: state, item: item} do
      state = press(state, ["n", "Several", :enter])
      assert contacts(state, item) == ["Several"]
      assert state.db.categories[cat(state, "Several")].parent_id == cat(state, "Contact")
    end

    test "ESC cancels without changing anything", %{opened: state, item: item} do
      state = press(state, :esc)
      refute state.db.categories[cat(state, "Contact")].exclusive
      assert contacts(state, item) == ["Anna Lasky", "Daniel Fiske"]
    end

    test "the whole change is one undo step", %{opened: state, item: item} do
      state = press(state, [:enter, :esc, :esc, {:ctrl, "z"}])
      refute state.db.categories[cat(state, "Contact")].exclusive
      assert contacts(state, item) == ["Anna Lasky", "Daniel Fiske"]
    end
  end

  describe "moving a category into an exclusive family" do
    setup do
      db = Agenda.Sample.build(~D[2026-10-08])
      priority = hd(Database.find_categories(db, "Priority"))
      {:ok, db, urgent} = Agenda.Core.add_category(db, db.main_id, "Urgent", after: priority)
      # the item about Anna is High; it is now also Urgent
      item = Enum.find(Database.items(db), &(&1.text =~ "Anna Lasky")).id
      db = Agenda.Core.assign(db, item, urgent)

      # category manager rows: MAIN Entry When Done Calls Priority High Medium Low Urgent
      state = start(db) |> press([{:f, 9}] ++ List.duplicate(:down, 9))
      %{state: state, item: item, urgent: urgent, priority: priority}
    end

    defp priorities(state, item) do
      state.db
      |> Database.explicit_categories(item)
      |> Enum.map(&state.db.categories[&1].name)
      |> Enum.filter(&(&1 in ~w(High Medium Low Urgent Mixed)))
      |> Enum.sort()
    end

    test "F8 (demote) shows Agenda's conflict box", %{state: state} do
      screen = state |> press({:f, 8}) |> screen()
      assert screen =~ "Moving Urgent creates a conflict"
      assert screen =~ "1 item(s) would be in two conflicting categories."
      assert screen =~ "Removing from current category"
      assert screen =~ "Removing from conflicting category"
      assert screen =~ "Moving to new category"
    end

    test "ENTER (default) moves it and removes the item from Urgent", %{
      state: state,
      item: item,
      urgent: urgent,
      priority: priority
    } do
      state = press(state, [{:f, 8}, :enter])
      assert state.db.categories[urgent].parent_id == priority
      assert priorities(state, item) == ["High"]
      assert screen(state) =~ "1 conflicting item(s) reassigned"
    end

    test "Removing from conflicting category keeps Urgent", %{state: state, item: item} do
      state = press(state, [{:f, 8}, :down, :enter])
      assert priorities(state, item) == ["Urgent"]
    end

    test "Moving to new category asks for a name", %{state: state, item: item, priority: priority} do
      state = press(state, [{:f, 8}, "m", "Mixed", :enter])
      assert priorities(state, item) == ["Mixed"]

      assert state.db.categories[hd(Database.find_categories(state.db, "Mixed"))].parent_id ==
               priority
    end

    test "ESC leaves the hierarchy alone", %{state: state, urgent: urgent} do
      state = press(state, [{:f, 8}, :esc])
      assert state.db.categories[urgent].parent_id == state.db.main_id
    end

    test "ALT-F10 (move under a new parent) uses the same box", %{
      state: state,
      item: item,
      urgent: urgent
    } do
      state = press(state, [{:alt_f, 10}, "Prio", :enter])
      assert screen(state) =~ "Moving Urgent creates a conflict"
      state = press(state, :enter)

      assert state.db.categories[urgent].parent_id ==
               hd(Database.find_categories(state.db, "Priority"))

      assert priorities(state, item) == ["High"]
    end

    test "the move and its resolution are one undo step", %{
      state: state,
      item: item,
      urgent: urgent
    } do
      state = press(state, [{:f, 8}, :enter, {:ctrl, "z"}])
      assert state.db.categories[urgent].parent_id == state.db.main_id
      assert priorities(state, item) == ["High", "Urgent"]
    end
  end

  test "demoting a category under one the item is also in asks how to resolve it (R7c)", %{
    state: state
  } do
    # "Check with Abigail Scheer..." is in Abigail; also assign it to Anna
    item = Enum.find(Database.items(state.db), &(&1.text =~ "Check with Abigail")).id
    state = %{state | db: Agenda.Core.assign(state.db, item, cat(state, "Anna Lasky"))}

    # rows: MAIN Entry When Done Calls Priority High Medium Low Contact Anna Abigail
    state = press(state, [{:f, 9}] ++ List.duplicate(:down, 11) ++ [{:f, 8}])
    assert screen(state) =~ "Moving Abigail Scheer creates a conflict"

    state = press(state, :enter)
    assert state.db.categories[cat(state, "Abigail Scheer")].parent_id == cat(state, "Anna Lasky")

    contact_links =
      state.db |> Database.explicit_categories(item) |> Enum.map(&state.db.categories[&1].name)

    assert "Anna Lasky" in contact_links
    refute "Abigail Scheer" in contact_links
  end
end
