defmodule Agendum.TUI.YankTest do
  @moduledoc """
  ALT-Y, yank back the last removed item (R42; User's Guide 4-10): the
  item last taken out of a section with DEL goes into the current
  section, below the highlighted item. Only one is tracked, and removing
  marked items does not count.
  """
  use ExUnit.Case, async: true

  import Agendum.Fixtures, only: [cat: 2, item_id: 2]
  import Agendum.TUIHelpers

  alias Agendum.Core.Database
  alias Agendum.TUI.{History, Layout, State}

  @weed "Weed the carrot bed tomorrow morning"
  @notice "Put up a Notice about the Organising Meeting on Friday"

  # Rabbit's Week; the highlight on Weed, the first item in Garden
  setup do
    db = Agendum.Sample.rabbit(~D[2026-10-12])
    %{state: db |> start(today: ~D[2026-10-12], height: 30) |> press(:down)}
  end

  defp in?(state, text, name),
    do: Database.member?(state.db, item_id(state.db, text), cat(state.db, name))

  defp to_item(state, text) do
    index = Enum.find_index(Layout.rows(state), &(&1.kind == :item and &1.item.text == text))
    Layout.move_to(state, index)
  end

  test "DEL then ALT-Y puts the item below the highlighted one, one undo step", %{state: state} do
    state = press(state, :delete)
    refute in?(state, @weed, "Garden")

    state = state |> to_item(@notice) |> press({:alt, "y"})
    assert in?(state, @weed, "Notices")
    assert panel(state) =~ "Yanked back into Notices"

    # below Put up a Notice, the highlight on it
    notices =
      for %{kind: :item, category: %{name: "Notices"}} = r <- Layout.rows(state), do: r.item.text

    assert Enum.take(notices, 2) == [@notice, @weed]
    assert Layout.current_row(state).item.text == @weed

    refute History.undo(state) |> in?(@weed, "Notices")
  end

  test "it can go back where it was", %{state: state} do
    state = press(state, [:delete, :up, {:alt, "y"}])
    assert in?(state, @weed, "Garden")
  end

  test "one at a time: after a yank there is nothing left to yank", %{state: state} do
    state = press(state, [:delete, {:alt, "y"}, {:alt, "y"}])
    assert panel(state) =~ "No removed item to yank back"
  end

  test "nothing removed, or removed with marked items: nothing to yank", %{state: state} do
    assert state |> press({:alt, "y"}) |> panel() =~ "No removed item to yank back"
    state = press(state, [{:f, 7}, :down, {:f, 7}, :delete, "m", {:alt, "y"}])
    assert panel(state) =~ "No removed item to yank back"
  end

  test "an item already in the section stays as it is", %{state: state} do
    state = state |> press(:delete) |> press(:up)
    # put it back by hand first, then yank
    state = press(state, [{:alt, "y"}])
    state = %{state | last: %{state.last | removed: item_id(state.db, @weed)}}
    assert state |> press({:alt, "y"}) |> panel() =~ "already in Garden"
  end

  test "a datebook view's sections are its dates" do
    db = Agendum.Starters.Planner.build() |> Agendum.Starters.Planner.with_samples(~D[2026-10-12])
    tasks = Enum.find(Database.views(db), &(&1.name == "Tasks"))
    week = Enum.find(Database.views(db), &(&1.name == "This Week"))
    state = db |> start(today: ~D[2026-10-12]) |> State.switch_view(tasks.id)

    state =
      state
      |> press([:down, :delete])
      |> State.switch_view(week.id)
      |> press([:down, {:alt, "y"}])

    assert panel(state) =~ message(:datebook_change)
  end
end
