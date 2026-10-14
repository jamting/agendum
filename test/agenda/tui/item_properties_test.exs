defmodule Agenda.TUI.ItemPropertiesTest do
  @moduledoc "The Item Properties box (F6 on an item; User's Guide 4-13 to 4-15)."
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.Core.Database
  alias Agenda.TUI.State

  setup do
    # the second item: "Don't forget to call Anna Lasky...", High, Anna Lasky
    state = start(Agenda.Sample.build(~D[2026-10-08])) |> press([:down, :down])
    item = Agenda.TUI.Layout.current_row(state).item.id
    %{state: press(state, {:f, 6}), item: item}
  end

  defp cat(state, name), do: hd(Database.find_categories(state.db, name))

  defp names(state, item),
    do:
      state.db
      |> Database.explicit_categories(item)
      |> Enum.map(&state.db.categories[&1].name)
      |> Enum.sort()

  # rows: Item text, Note, Statistics, then assignments, then the add row
  defp row(state, n), do: press(state, List.duplicate(:down, n))

  test "F6 on an item opens the box with its text, note, statistics and assignments", %{
    state: state
  } do
    screen = screen(state)
    assert screen =~ "Item properties"
    assert screen =~ "Don't forget to call"
    assert screen =~ ~r/Note\s+: \(none\)/
    assert screen =~ ~r/Statistics\s+: 4 categories · entered 2026-10-08/
    assert screen =~ ~r/Assigned to\s+: Entry \(2026-10-08\)/
    assert screen =~ "Calls"
    assert screen =~ "High"
    assert screen =~ "Anna Lasky"
  end

  test "F2 on the text edits it", %{state: state, item: item} do
    state = press(state, [{:f, 2}, {:ctrl, "u"}, "Call Anna about the report", :enter])
    assert state.db.items[item].text == "Call Anna about the report"
    assert %{type: :item_props} = State.mode(state)
  end

  test "SPACE on the note opens it; ESC returns to the box", %{state: state, item: item} do
    state = state |> row(1) |> press([" ", "remember the figures", :esc])
    assert state.db.items[item].note == "remember the figures"
    assert %{type: :item_props} = State.mode(state)
  end

  test "DEL on an assignment breaks it", %{state: state, item: item} do
    # assignments: Entry(3) Calls(4) High(5) Anna Lasky(6)
    state = state |> row(5) |> press(:delete)
    refute "High" in names(state, item)
  end

  test "the Entry date cannot be removed", %{state: state} do
    state = state |> row(3) |> press(:delete)
    assert screen(state) =~ "Entry date cannot be removed"
  end

  test "typing a name assigns the category, with automatic completion", %{
    state: state,
    item: item
  } do
    state = state |> row(4) |> press("Mee")
    assert screen(state) =~ "AUTOC"
    state = press(state, :enter)
    assert "Meetings" in names(state, item)
  end

  test "INS creates exactly what was typed as a new category under MAIN", %{
    state: state,
    item: item
  } do
    state = state |> row(4) |> press(["Errands", :insert])
    assert "Errands" in names(state, item)
    assert state.db.categories[cat(state, "Errands")].parent_id == state.db.main_id
  end

  test "choosing a date category asks for the date", %{state: state, item: item} do
    state = state |> row(4) |> press(["Whe", :enter])
    assert screen(state) =~ "When date:"
    state = press(state, ["friday", :enter])
    assert state.db.items[item].when == ~D[2026-10-09]
    assert state.db.items[item].when_explicit
  end

  test "F4 on a date changes it", %{state: state, item: item} do
    state = state |> row(3) |> press([{:f, 4}, {:ctrl, "u"}, "2026-10-01", :enter])
    assert state.db.items[item].entry == ~D[2026-10-01]
  end

  test "F3 opens the assignment profile; ESC closes the box", %{state: state} do
    assert %{type: :profile} = State.mode(press(state, {:f, 3}))
    assert press(state, :esc).modes == []
  end

  test "F6 on a section head opens Section Properties, and F6 there the category's (R61)" do
    state = start(Agenda.Sample.build(~D[2026-10-08])) |> press([{:f, 6}, {:f, 6}])
    assert screen(state) =~ "Category properties: Calls"
  end
end
