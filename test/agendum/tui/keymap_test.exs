defmodule Agendum.TUI.KeymapTest do
  @moduledoc """
  Keys run named commands through keymaps (R65, ADR 0033): the keymap and
  the command list must agree, as the menu's first letters must.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Starters.Planner
  alias Agendum.TUI.{CategoryScreens, Commands, Keymap}
  alias Agendum.TUI.Update.ViewKeys

  @today ~D[2026-10-12]

  # the places whose keys are in keymaps (ADR 0033)
  @places [:view, :catmgr, :viewmgr, :global]

  test "every key in a keymap runs a command in its place's command list" do
    unknown =
      for place <- @places,
          {key, id} <- Keymap.bindings(place),
          Commands.get(place, id) == nil,
          do: {place, key, id}

    assert unknown == []
  end

  test "the global keymap and the global commands agree, and every one runs" do
    state = start(Planner.build(), today: @today)

    for {_key, id} <- Keymap.bindings(:global), do: assert(Commands.get(:global, id), "#{id}")

    for c <- Commands.all(:global) do
      assert Keymap.keys_for(:global, c.id) != []
      assert Agendum.TUI.Update.run_global(state, c.id) != nil
    end
  end

  test "every command has a key" do
    unbound =
      for place <- @places,
          c <- Commands.all(place),
          Keymap.keys_for(place, c.id) == [],
          do: {place, c.id}

    assert unbound == []
  end

  test "names and summaries fit the command list on an 80-column screen" do
    for place <- @places, c <- Commands.all(place) do
      assert String.length(c.name) <= 17, c.name
      assert String.length(c.summary) <= 38, c.summary
    end
  end

  test "command ids are unique in a place and every command has a name and a summary" do
    for place <- @places do
      ids = Enum.map(Commands.all(place), & &1.id)
      assert ids == Enum.uniq(ids)
      assert Enum.all?(Commands.all(place), &(&1.name != "" and &1.summary != ""))
    end
  end

  test "⌥↑ stands for CTRL-PGUP in a view only: in the category manager it moves" do
    assert Keymap.alias_in(:view, {:alt, :up}) == :ctrl_pgup
    assert Keymap.alias_in(:catmgr, {:alt, :up}) == nil
    assert {:alt, :up} in Keymap.keys_for(:catmgr, :move_up)
    refute {:alt, :up} in Keymap.keys_for(:catmgr, :previous_sibling)
  end

  test "every view manager command runs, on the first view and on another" do
    state = start(Planner.build() |> Planner.with_samples(@today), today: @today)
    first = press(state, [{:f, 8}, :home])
    other = press(first, :down)

    for c <- Commands.all(:viewmgr), from <- [first, other] do
      assert %Agendum.TUI.State{} = Agendum.TUI.Boxes.ViewManager.run(from, c.id),
             "#{c.id} failed"
    end
  end

  test "every category manager command runs, on MAIN and on a category below it" do
    state = start(Planner.build() |> Planner.with_samples(@today), today: @today)
    on_main = press(state, {:f, 9})
    below = press(on_main, [:down, :down])

    for c <- Commands.all(:catmgr), from <- [on_main, below] do
      assert %Agendum.TUI.State{} = CategoryScreens.Manager.run(from, c.id), "#{c.id} failed"
    end
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
