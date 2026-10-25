defmodule Agendum.TUI.DependenciesTest do
  @moduledoc "ALT-O, the & symbol and hiding dependent items (R43; User's Guide 13-12 to 13-15)."
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.TUI.{Layout, State}

  # Calls: Terracotta, Anna Lasky, Marketing, Check with Abigail, Daniel Fiske
  setup do
    %{state: start(Agendum.Sample.build(~D[2026-10-08]))}
  end

  defp id_of(state, start),
    do: Enum.find(Map.values(state.db.items), &String.starts_with?(&1.text, start)).id

  # mark the first two items, then ALT-O on the fifth
  defp make_dependent(state),
    do: press(state, [:down, {:f, 7}, :down, {:f, 7}, :down, :down, :down, {:alt, "o"}])

  test "ALT-O asks, then makes the item depend on the marked items", %{state: state} do
    state = make_dependent(state)
    assert screen(state) =~ "Make this item depend on the 2 marked items?"

    state = press(state, "y")
    daniel = id_of(state, "Contact Daniel")

    assert Core.prerequisites(state.db, daniel) == [
             id_of(state, "Set up meeting"),
             id_of(state, "Don't forget")
           ]

    assert screen(state) =~ "& Contact Daniel Fiske"
    assert screen(state) =~ "Depends on 2 items"
    assert screen(press(state, {:f, 6})) =~ ~r/Depends on:\s*Set up meeting/
  end

  test "ALT-O on a dependent item, with nothing marked, offers to clear", %{state: state} do
    state = make_dependent(state) |> press(["y", {:alt_f, 7}, {:alt, "o"}])
    assert screen(state) =~ "Clear this item's dependencies?"
    state = press(state, "y")
    assert Core.prerequisites(state.db, id_of(state, "Contact Daniel")) == []
    refute screen(state) =~ "& Contact"
  end

  test "ALT-O with nothing marked on an independent item explains", %{state: state} do
    state = press(state, [:down, {:alt, "o"}])
    assert panel(state) =~ message(:make_dependent)
  end

  test "an item cannot depend on an item that depends on it", %{state: state} do
    state = make_dependent(state) |> press(["y", {:alt_f, 7}])
    # mark Daniel (the dependent), then ALT-O on the first item (its prerequisite)
    state = press(state, [{:f, 7}, :up, :up, :up, :up, {:alt, "o"}, "y"])
    assert panel(state) =~ message(:depends_on_itself)
  end

  test "View Properties ▸ Hide dependent items hides waiting items until their prerequisites are done",
       %{state: state} do
    state = make_dependent(state) |> press(["y", {:alt_f, 7}])
    state = switch_view_setting(state, "Hide dependent items")
    assert State.view(state).hide_dependent
    assert screen(state) =~ "[Hide dependent]"
    refute screen(state) =~ "Contact Daniel"

    # finish both prerequisites (the first two items)
    state = press(state, [:ctrl_home, :down, {:f, 4}, :down, {:f, 4}])
    assert screen(state) =~ "Contact Daniel"
    assert Layout.rows(state) |> Enum.any?(&(&1[:item] && &1.item.text =~ "Daniel"))
  end

  describe "Search ▸ Depends and Prereqs (Utilities Show Depends / Show Prereqs)" do
    setup %{state: state} do
      # Daniel depends on the first two items; the cursor stays on Daniel
      %{state: state |> make_dependent() |> press(["y", {:alt_f, 7}])}
    end

    defp shown_texts(state),
      do: for(%{kind: :item, item: item} <- Layout.rows(state), do: item.text)

    test "Prereqs ▸ One level lists the item's prerequisites in the Show View", %{state: state} do
      state = press(state, [{:f, 10}, "u", "s", "p", "o"])
      assert State.view(state).name == "*Show View*"
      assert [first, second] = shown_texts(state)
      assert first =~ "Set up meeting"
      assert second =~ "Don't forget"
      assert screen(state) =~ "2 prerequisite items · ALT-F8 returns to the last view"
    end

    test "Depends ▸ One level from a prerequisite", %{state: state} do
      state = press(state, [:ctrl_home, :down, {:f, 10}, "u", "s", "d", "o"])
      assert [only] = shown_texts(state)
      assert only =~ "Contact Daniel"
    end

    test "Every item lists all items that have prerequisites", %{state: state} do
      state = press(state, [:ctrl_home, {:f, 10}, "u", "s", "p", "e"])
      assert [only] = shown_texts(state)
      assert only =~ "Contact Daniel"
    end

    test "nothing to show is reported", %{state: state} do
      state = press(state, [{:f, 10}, "u", "s", "d", "a"])
      assert screen(state) =~ "No items depend on this one"
      assert State.view(state).name == "Activities"
    end
  end

  describe "Item Properties lists dependencies by name" do
    setup %{state: state} do
      # Daniel depends on the first two items; the cursor stays on Daniel
      %{state: state |> make_dependent() |> press(["y", {:alt_f, 7}])}
    end

    defp row_of(state, text) do
      mode = State.mode(state)
      rows = Agendum.TUI.Boxes.ItemProperties.rows(state, mode)

      Enum.find_index(rows, fn
        {kind, id} when kind in [:prerequisite, :dependent] -> state.db.items[id].text =~ text
        _ -> false
      end)
    end

    defp to_row(state, text),
      do: State.put_mode(state, %{State.mode(state) | cursor: row_of(state, text)})

    test "the items it depends on, under Depends on", %{state: state} do
      text = screen(press(state, {:f, 6}))
      assert text =~ ~r/Depends on:\s*Set up meeting/
      assert text =~ ~r/│ {19}Don't forget/
      refute text =~ "Needed by"
    end

    test "the items depending on it, under Needed by; done ones are ticked", %{state: state} do
      state = press(state, [:ctrl_home, :down, {:f, 4}, {:f, 6}])
      text = screen(state)
      assert text =~ ~r/Needed by:\s*Contact Daniel Fiske/
      refute text =~ "Depends on"

      state = press(state, :esc)
      state = Agendum.TUI.Boxes.ItemProperties.open(state, id_of(state, "Contact Daniel"))
      assert screen(state) =~ ~r/Depends on:\s*‼ Set up meeting/
    end

    test "SPACE opens that item's properties; ESC comes back", %{state: state} do
      state = state |> press({:f, 6}) |> to_row("Don't forget") |> press(" ")
      assert State.mode(state).item_id == id_of(state, "Don't forget")
      assert screen(state) =~ ~r/Needed by:\s*Contact Daniel/

      state = press(state, :esc)
      assert State.mode(state).item_id == id_of(state, "Contact Daniel")
    end

    test "DEL removes that one dependency, as one undo step", %{state: state} do
      state = state |> press({:f, 6}) |> to_row("Set up meeting") |> press(:delete)
      daniel = id_of(state, "Contact Daniel")
      assert Core.prerequisites(state.db, daniel) == [id_of(state, "Don't forget")]
      assert screen(state) =~ ~r/Depends on:\s*Don't forget/

      state = Agendum.TUI.History.undo(state)
      assert length(Core.prerequisites(state.db, daniel)) == 2
    end

    test "DEL on a Needed by row frees the other item", %{state: state} do
      state = press(state, [:ctrl_home, :down, {:f, 6}])
      state = state |> to_row("Contact Daniel") |> press(:delete)
      assert Core.dependents(state.db, id_of(state, "Set up meeting")) == []
      refute screen(state) =~ "Needed by"
    end
  end
end
