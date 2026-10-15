defmodule Agendum.TUI.KeymapTest do
  @moduledoc """
  Keys run named commands through keymaps (R65, ADR 0033): the keymap and
  the command list must agree, as the menu's first letters must.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Starters.Planner
  alias Agendum.TUI.{Commands, Keymap}
  alias Agendum.TUI.Update.ViewKeys

  @today ~D[2026-10-12]

  test "every key in the view's keymap runs a command in the command list" do
    unknown =
      for {key, id} <- Keymap.bindings(:view), Commands.get(:view, id) == nil, do: {key, id}

    assert unknown == []
  end

  test "every view command has a key" do
    unbound = for c <- Commands.all(:view), Keymap.keys_for(:view, c.id) == [], do: c.id
    assert unbound == []
  end

  test "command ids are unique and every command has a name and a summary" do
    ids = Enum.map(Commands.all(:view), & &1.id)
    assert ids == Enum.uniq(ids)
    assert Enum.all?(Commands.all(:view), &(&1.name != "" and &1.summary != ""))
  end

  test "every view command runs, on an item and on a section head" do
    state = start(Planner.build() |> Planner.with_samples(@today), today: @today)
    on_item = press(state, :down)

    for c <- Commands.all(:view), from <- [state, on_item] do
      assert %Agendum.TUI.State{} = ViewKeys.run(from, c.id), "#{c.id} failed"
    end
  end

  test "a printable character is not bound: it starts typing an item" do
    state = start(Planner.build(), today: @today) |> press(:down)
    assert Keymap.lookup(:view, {:char, "x"}) == nil
    assert press(state, "x").edit != nil
  end
end
