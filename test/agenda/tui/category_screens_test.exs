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
end
