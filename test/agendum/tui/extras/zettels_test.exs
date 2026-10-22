defmodule Agendum.TUI.Extras.ZettelsTest do
  @moduledoc "Zettel ids in the view: Item ▸ Zettel ▸ Attach (R73)."
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.TUI.Layout

  setup do
    %{state: start(quiet_meetings(Agendum.Sample.build(~D[2026-10-08])))}
  end

  # the menu: F10, Item, Zettel, Attach (first letters, as in Agenda)
  defp attach(state), do: press(state, [{:f, 10}, "i", "z", "a"])
  defp current(state), do: Layout.current_row(state).item

  test "Attach gives the highlighted item the next id and says which", %{state: state} do
    state = state |> press(:down) |> attach()
    assert Core.zettel(current(state)) == "bonalaku"
    assert screen(state) =~ "bonalaku given"
  end

  test "an item that has an id keeps it, and is told so", %{state: state} do
    state = state |> press(:down) |> attach() |> attach()
    assert Core.zettel(current(state)) == "bonalaku"
    assert screen(state) =~ "The item already has its Zettel id, bonalaku"
  end

  test "with marked items it asks, and gives each marked item one", %{state: state} do
    state = press(state, [:down, {:f, 7}, :down, :down, {:f, 7}]) |> attach()
    assert screen(state) =~ "Give a Zettel id to:"

    state = press(state, "m")
    assert screen(state) =~ "2 Zettel ids given: bonalaku, pigavono"
    assert state.db.next_zettel == 3
  end

  test "on a section head, with nothing marked, it says what to do", %{state: state} do
    state = attach(state)
    assert screen(state) =~ "Highlight an item, or mark some with F7"
  end

  test "one undo takes the id back", %{state: state} do
    state = state |> press(:down) |> attach() |> press({:ctrl, "z"})
    assert current(state).zettel == nil
    assert state.db.next_zettel == 1
  end

  test "CTRL-T does what Item ▸ Zettel ▸ Attach does", %{state: state} do
    state = press(state, [:down, {:ctrl, "t"}])
    assert screen(state) =~ "bonalaku given"
  end
end
