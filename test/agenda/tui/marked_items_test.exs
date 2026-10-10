defmodule Agenda.TUI.MarkedItemsTest do
  @moduledoc "Marking items and bulk commands on them (User's Guide 13-1 to 13-4, 4-5, 4-17)."
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.Core
  alias Agenda.Core.Database
  alias Agenda.TUI.{Layout, State}

  setup do
    db = Agenda.Sample.build(~D[2026-10-08])
    [view] = Database.views(db)
    db = Core.add_section(db, view.id, hd(Database.find_categories(db, "Meetings")), 1)
    %{state: start(db)}
  end

  defp cat(state, name), do: hd(Database.find_categories(state.db, name))
  defp items(state), do: Database.items(state.db)
  defp marked(state), do: Core.marked_items(state.db)
  # mark the first and third items of the Calls section
  defp mark_two(state), do: press(state, [:down, {:f, 7}, :down, :down, {:f, 7}])

  test "F7 on a section head marks all its items, and again unmarks them", %{state: state} do
    state = press(state, {:f, 7})
    assert length(marked(state)) == 5
    assert screen(state) =~ "♦"
    assert marked(press(state, {:f, 7})) == []
  end

  test "ALT-F7 unmarks every item", %{state: state} do
    state = state |> mark_two() |> press({:alt_f, 7})
    assert marked(state) == []
  end

  test "ALT-J jumps to the next marked item", %{state: state} do
    state = state |> mark_two() |> press([:home, {:alt, "j"}])
    assert Layout.current_row(state).item.id == hd(marked(state))
    state = press(state, {:alt, "j"})
    assert Layout.current_row(state).item.id == List.last(marked(state))
  end

  test "with marked items, F4 asks: marked items or current item", %{state: state} do
    state = state |> mark_two() |> press({:f, 4})
    assert screen(state) =~ "Marked items (2)"
    assert screen(state) =~ "Current item"

    state = press(state, "m")
    assert Enum.count(items(state), & &1.done) == 2
  end

  test "choosing Current item acts on the highlighted item only", %{state: state} do
    state = state |> mark_two() |> press([:up, {:f, 4}, "c"])
    assert [done] = Enum.filter(items(state), & &1.done)
    refute done.marked
  end

  test "ESC cancels the question", %{state: state} do
    state = state |> mark_two() |> press([{:f, 4}, :esc])
    refute Enum.any?(items(state), & &1.done)
    assert state.modes == []
  end

  test "ALT-F4 discards all marked items after confirming", %{state: state} do
    state = state |> mark_two() |> press([{:alt_f, 4}, "m"])
    assert screen(state) =~ "Discard 2 marked items from the whole file?"
    state = press(state, "y")
    assert length(items(state)) == 3
  end

  test "DEL removes all marked items from the current section", %{state: state} do
    calls = cat(state, "Calls")
    state = state |> mark_two() |> press([:delete, "m"])
    assert length(Database.items_in(state.db, calls)) == 3
    assert length(items(state)) == 5
  end

  test "ALT-F2 gives all marked items the same When date", %{state: state} do
    state = state |> mark_two() |> press([{:alt_f, 2}, "m", "2026-12-24", :enter])
    assert Enum.count(items(state), &(&1.when == ~D[2026-12-24] and &1.when_explicit)) == 2
  end

  test "ALT-F10 moves all marked items to another section", %{state: state} do
    meetings = cat(state, "Meetings")
    state = state |> mark_two() |> press([{:alt_f, 10}, "m", :end, :enter])
    assert length(Database.items_in(state.db, meetings)) == 2
    assert length(Database.items_in(state.db, cat(state, "Calls"))) == 3
  end

  test "ALT-M assigns the current item, or all marked items, to a category", %{state: state} do
    meetings = cat(state, "Meetings")
    state = press(state, [:down, {:alt, "m"}, "Meet", :enter])
    assert length(Database.items_in(state.db, meetings)) == 1

    state = state |> mark_two() |> press([{:alt, "m"}, "m", "Meet", :enter])
    assert length(Database.items_in(state.db, meetings)) == 3
  end

  test "F3 with marked items shows a group profile with counts; SPACE assigns or unassigns all",
       %{state: state} do
    state = state |> mark_two() |> press([{:f, 3}, "m"])
    assert screen(state) =~ "2 marked items"
    # Calls holds both marked items
    assert screen(state) =~ ~r/2\s+Calls/

    # Meetings is last: assign both, then unassign both
    state = press(state, [:ctrl_end, " "])
    assert length(Database.items_in(state.db, cat(state, "Meetings"))) == 2
    state = press(state, " ")
    assert Database.items_in(state.db, cat(state, "Meetings")) == []
    assert %{type: :group_profile} = State.mode(state)
  end

  test "without marked items, commands act on the current item as before", %{state: state} do
    state = press(state, [:down, {:f, 4}])
    assert Enum.count(items(state), & &1.done) == 1
    assert state.modes == []
  end
end
