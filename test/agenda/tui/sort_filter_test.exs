defmodule Agenda.TUI.SortFilterTest do
  @moduledoc "Filters (R28) and sorting (R36) from the menu, ALT-F5 and the Sort box."
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.Core.Database
  alias Agenda.Core.View.SortKey
  alias Agenda.TUI.State

  setup do
    %{state: start(Agenda.Sample.build(~D[2026-10-08]))}
  end

  defp cat(state, name), do: hd(Database.find_categories(state.db, name))

  defp texts(state) do
    state.db
    |> Agenda.Core.ViewModel.build(State.view(state))
    |> hd()
    |> Map.get(:rows)
    |> Enum.map(& &1.item.text)
  end

  test "View > Filter: ENTER cycles a category's filter; the view shows it in brackets", %{
    state: state
  } do
    state = press(state, [{:f, 10}, "v", "f", "High", :enter])
    assert %{type: :picker} = State.mode(state)
    assert State.view(state).filter == [{cat(state, "High"), :assigned}]
    state = press(state, [:esc, :esc])
    assert state.modes == []
    assert screen(state) =~ "View: Activities [High]"
    assert length(texts(state)) == 1
  end

  test "a section filter shows after the section head", %{state: state} do
    state = press(state, [{:f, 10}, "v", "s", "f", "Abigail", :enter, :enter, :esc, :esc])
    assert screen(state) =~ "Calls [-Abigail Scheer]"
    assert length(texts(state)) == 3
  end

  test "typing into a filtered view assigns the new item to the filter", %{state: state} do
    state =
      press(state, [{:f, 10}, "v", "f", "High", :enter, :esc, :esc, "Call the bank", :enter])

    item = Enum.find(Database.items(state.db), &(&1.text == "Call the bank"))
    assert Database.member?(state.db, item.id, cat(state, "High"))
    assert "Call the bank" in texts(state)
  end

  test "View > Order: sort on item text, then reverse the order", %{state: state} do
    state = press(state, [{:f, 10}, "v", "o"])
    assert %{type: :sort} = State.mode(state)
    assert screen(state) =~ "Sort items in all sections"

    state = press(state, :enter)
    assert State.view(state).sort == [%SortKey{on: :text}]

    assert hd(texts(state)) ==
             "Call Marketing to arrange a Rapidfire demo for Abigail Scheer this Tuesday."

    state = press(state, [:down, :enter])

    assert hd(texts(state)) ==
             "Set up meeting at Terracotta Corp to discuss CopyCat before the end of the month."
  end

  test "sorting on a category uses the category box", %{state: state} do
    state = press(state, [{:f, 10}, "v", "o", :enter, :enter, "Prio", :enter])
    assert State.view(state).sort == [%SortKey{on: {:category, cat(state, "Priority")}}]
    assert screen(state) =~ "Category: Priority"
    # High first: the Anna Lasky item
    assert hd(texts(state)) =~ "Anna Lasky"
  end

  test "ALT-F5 in a view opens the section's Sort box, which can use the view's settings", %{
    state: state
  } do
    state = press(state, {:alt_f, 5})
    assert screen(state) =~ "Sort items in Calls"
    assert screen(state) =~ "As the view (None)"

    state = press(state, [:enter, :enter])
    assert hd(State.view(state).sections).sort == [%SortKey{on: :text}]
  end

  test "ALT-F5 in the category manager sorts a family alphabetically", %{state: state} do
    # rows: MAIN Entry When Done Calls Priority
    state = press(state, [{:f, 9}] ++ List.duplicate(:down, 5) ++ [{:alt_f, 5}, "y"])

    names =
      Enum.map(
        state.db.categories[cat(state, "Priority")].children,
        &state.db.categories[&1].name
      )

    assert names == ["High", "Low", "Medium"]
  end

  test "ALT-F5 in the view manager sorts the views", %{state: state} do
    state =
      press(state, [{:f, 8}, :insert, "Agenda", :enter, "Calls", :enter, {:f, 8}, {:alt_f, 5}])

    assert state.db |> Database.views() |> Enum.map(& &1.name) == ["Activities", "Agenda"]
  end
end
