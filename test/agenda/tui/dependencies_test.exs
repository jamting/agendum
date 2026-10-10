defmodule Agenda.TUI.DependenciesTest do
  @moduledoc "ALT-O, the & symbol and hiding dependent items (R43; User's Guide 13-12 to 13-15)."
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.Core
  alias Agenda.TUI.{Layout, State}

  # Calls: Terracotta, Anna Lasky, Marketing, Check with Abigail, Daniel Fiske
  setup do
    %{state: start(Agenda.Sample.build(~D[2026-10-08]))}
  end

  defp id_of(state, start),
    do: Enum.find(Map.values(state.db.items), &String.starts_with?(&1.text, start)).id

  # mark the first two items, then ALT-O on the fifth
  defp make_dependent(state),
    do: press(state, [:down, {:f, 7}, :down, {:f, 7}, :down, :down, :down, {:alt, "o"}])

  test "ALT-O asks, then makes the item depend on the marked items", %{state: state} do
    state = make_dependent(state)
    assert screen(state) =~ "Make this item depend on the 2 marked items? (Y/N)"

    state = press(state, "y")
    daniel = id_of(state, "Contact Daniel")

    assert Core.prerequisites(state.db, daniel) == [
             id_of(state, "Set up meeting"),
             id_of(state, "Don't forget")
           ]

    assert screen(state) =~ "& Contact Daniel Fiske"
    assert screen(state) =~ "Depends on 2 items"
    assert screen(press(state, {:f, 6})) =~ ~r/Dependencies\s*: depends on 2/
  end

  test "ALT-O on a dependent item, with nothing marked, offers to clear", %{state: state} do
    state = make_dependent(state) |> press(["y", {:alt_f, 7}, {:alt, "o"}])
    assert screen(state) =~ "Clear this item's dependencies? (Y/N)"
    state = press(state, "y")
    assert Core.prerequisites(state.db, id_of(state, "Contact Daniel")) == []
    refute screen(state) =~ "& Contact"
  end

  test "ALT-O with nothing marked on an independent item explains", %{state: state} do
    state = press(state, [:down, {:alt, "o"}])
    assert screen(state) =~ "Mark the items it depends on with F7, then ALT-O"
  end

  test "an item cannot depend on an item that depends on it", %{state: state} do
    state = make_dependent(state) |> press(["y", {:alt_f, 7}])
    # mark Daniel (the dependent), then ALT-O on the first item (its prerequisite)
    state = press(state, [{:f, 7}, :up, :up, :up, :up, {:alt, "o"}, "y"])
    assert screen(state) =~ "would depend on itself"
  end

  test "View ▸ Hide ▸ Pending hides waiting items until their prerequisites are done",
       %{state: state} do
    state = make_dependent(state) |> press(["y", {:alt_f, 7}])
    state = press(state, [{:f, 10}, "v", "h", "p"])
    assert State.view(state).hide_dependent
    assert screen(state) =~ "[Hide Dependent]"
    refute screen(state) =~ "Contact Daniel"

    # finish both prerequisites (the first two items)
    state = press(state, [:ctrl_home, :down, {:f, 4}, :down, {:f, 4}])
    assert screen(state) =~ "Contact Daniel"
    assert Layout.rows(state) |> Enum.any?(&(&1[:item] && &1.item.text =~ "Daniel"))
  end
end
