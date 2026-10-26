defmodule Agendum.TUI.TrashTest do
  @moduledoc """
  The trash on screen (R24a; checked in Agenda 2.0, 2026-10-26): ALT-F4
  asks Agenda's "Discard this item?", Item ▸ Undisc brings items back,
  Utilities ▸ Trash empties it, File Properties ▸ Empty trash says when it
  empties by itself, and File statistics counts it.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core.Database
  alias Agendum.TUI.Update

  @today ~D[2026-10-08]

  setup do
    %{state: start(Agendum.Sample.build(@today)) |> press(:down)}
  end

  defp highlighted(state), do: Agendum.TUI.Layout.current_row(state).item

  # ALT-F4 on the highlighted item, and ENTER on Agenda's question
  defp discard(state), do: press(state, [{:alt_f, 4}, :enter])

  defp undisc(state), do: press(state, [{:f, 10}, "i", "u"])

  test "ALT-F4 asks Agenda's question, and the item goes to the trash", %{state: state} do
    item = highlighted(state)
    asked = press(state, {:alt_f, 4})
    assert screen(asked) =~ "Discard this item?"
    assert panel(asked) =~ "Press ENTER to discard this item. Press ESC to cancel."

    state = press(asked, :enter)
    refute Map.has_key?(state.db.items, item.id)
    assert [%{id: id}] = state.db.trash.items
    assert id == item.id
  end

  test "Undisc with one item brings it back at once, below the highlighted item", %{
    state: state
  } do
    item = highlighted(state)
    state = discard(state)
    above = highlighted(state)
    state = undisc(state)
    assert state.modes == []
    assert highlighted(state).id == item.id
    assert state.db.trash.items == []
    # just below the item that was highlighted
    assert Enum.drop_while(state.db.item_order, &(&1 != above.id)) |> Enum.at(1) == item.id
  end

  test "Undisc with several asks Agenda's Undiscard box: all first, or the last", %{
    state: state
  } do
    first = highlighted(state)
    state = discard(state)
    second = highlighted(state)
    state = discard(state)

    asked = undisc(state)
    assert screen(asked) =~ ~r/Undiscard: +All items in trash/
    assert screen(asked) =~ "Press ENTER to accept, ESC to cancel"
    assert panel(asked) =~ "Retrieve all discarded items in the Trash or only the last"

    last = press(asked, [" ", :enter])
    assert Enum.map(last.db.trash.items, & &1.id) == [first.id]
    assert highlighted(last).id == second.id

    all = press(asked, :enter)
    assert all.db.trash.items == []
    assert Map.has_key?(all.db.items, first.id)
  end

  test "Undisc with nothing in the trash says so, in Agenda's words", %{state: state} do
    state = undisc(state)

    # wrapped as Agenda's, in a box 62 wide
    assert screen(state) =~ "There are no discarded items in the trash, so there are no"
    assert screen(state) =~ ~r/│ items to recover\. +│/

    refute screen(state) =~ "Error"
    assert press(state, "x").modes == []
  end

  test "Utilities Trash asks, then empties it; with none, says so", %{state: state} do
    none = press(state, [{:f, 10}, "u", "t"])

    assert screen(none) =~ "There are no discarded items in the trash, so there is no"
    assert screen(none) =~ ~r/│ trash to empty\. +│/

    state = discard(state)
    asked = press(state, [{:f, 10}, "u", "t"])
    assert screen(asked) =~ "Empty the trash?"
    assert panel(asked) =~ "Press ENTER to empty the trash."
    assert press(asked, :enter).db.trash.items == []
  end

  test "CTRL-Z takes a discard back, out of the trash", %{state: state} do
    item = highlighted(state)
    state = state |> discard() |> press({:ctrl, "z"})
    assert Map.has_key?(state.db.items, item.id)
    assert state.db.trash.items == []
  end

  describe "File Properties ▸ Empty trash" do
    defp file_props(state), do: press(state, [{:f, 10}, "f", "p"])

    test "shows End of day, and SPACE goes through Agenda's choices", %{state: state} do
      state = state |> file_props() |> to_setting("Empty trash")
      assert screen(state) =~ ~r/Empty trash: +End of day/

      assert panel(state) =~
               "Choose when to remove discarded items from the trash, so that"

      state = press(state, " ")
      assert screen(state) =~ ~r/Empty trash: +When item is discarded/
      assert state.db.trash.empty == :discarded
      assert screen(press(state, " ")) =~ ~r/Empty trash: +On demand/
      assert screen(press(state, [" ", " "])) =~ ~r/Empty trash: +When file is closed/
    end

    test "File statistics counts the items in the trash", %{state: state} do
      state = state |> discard() |> file_props() |> to_setting("File statistics")
      assert screen(press(state, " ")) =~ ~r/Items in trash: +1/
    end
  end

  describe "emptying by itself" do
    test "End of day: the next day the trash is empty, without a Save question", %{
      state: state
    } do
      state = discard(state)
      state = %{state | saved: %{state.saved | db: state.db}, dirty: false}
      {state, _} = Update.tick(state, ~N[2026-10-08 23:59:00])
      assert state.db.trash.items != []

      {state, _} = Update.tick(state, ~N[2026-10-09 00:00:01])
      assert state.db.trash.items == []
      refute state.dirty
    end

    test "When file is closed: opening it again finds it empty", %{state: state} do
      {:ok, db} = Agendum.Core.set_empty_trash(state.db, :file_closed)
      state = discard(%{state | db: db})
      assert Update.arrive(state).db.trash.items == []
    end
  end

  test "the trash is not a file's item: views and statistics leave it out", %{state: state} do
    count = length(Database.items(state.db))
    state = discard(state)
    assert length(Database.items(state.db)) == count - 1
  end
end
