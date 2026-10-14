defmodule Agendum.TUI.SectionMoveTest do
  @moduledoc """
  Moving a section within its view (R62; User's Guide 5-8 to 5-9): ALT-F10
  on a section head or View ▸ Section ▸ Move collapses the sections, ↑ ↓
  move the section, ENTER keeps the new place, ESC puts it back.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Core
  alias Agendum.Core.Database
  alias Agendum.TUI.{History, State}

  # Rabbit's Week: Garden, Notices, Friends and Relations; the cursor on
  # the Garden head
  setup do
    db = Agendum.Sample.rabbit(~D[2026-10-12])
    %{state: start(db, today: ~D[2026-10-12], height: 30)}
  end

  defp heads(state),
    do: Enum.map(State.view(state).sections, &state.db.categories[&1.category_id].name)

  defp stored(state),
    do:
      Enum.map(
        Database.view(state.db, state.view_id).sections,
        &state.db.categories[&1.category_id].name
      )

  test "the core moves a section, with its columns and filter, in this view only", %{state: state} do
    view = state.db.views[state.view_id]
    garden = hd(view.sections)
    db = Core.move_section(state.db, view.id, 0, 2)
    assert List.last(db.views[view.id].sections) == garden
    # out of range is kept in range
    assert Core.move_section(state.db, view.id, 0, 9) == db
  end

  test "ALT-F10 on a section head: every section collapsed, § beside them", %{state: state} do
    state = press(state, {:alt_f, 10})
    assert %{type: :section_move, from: 0, to: 0} = State.mode(state)
    text = screen(state)
    refute text =~ "Weed the carrot bed"
    assert text =~ ~r/Garden.*§/
    assert panel(state) =~ "Moving section Garden"
  end

  test "↓ moves it in the preview; ENTER keeps it, one undo step, sections open again",
       %{state: state} do
    state = press(state, [{:alt_f, 10}, :down, :down])
    assert heads(state) == ["Notices", "Friends and Relations", "Garden"]
    # nothing kept yet
    assert stored(state) == ["Garden", "Notices", "Friends and Relations"]

    state = press(state, :enter)
    assert stored(state) == ["Notices", "Friends and Relations", "Garden"]
    assert State.mode(state) == nil
    assert screen(state) =~ "Weed the carrot bed"
    # the highlight on the moved section's head
    assert state.cursor_key == {:section, 2}
    assert stored(History.undo(state)) == ["Garden", "Notices", "Friends and Relations"]
  end

  test "ESC puts it back; the file is as it was", %{state: state} do
    moved = press(state, [{:alt_f, 10}, :down, :esc])
    assert moved.db == state.db
    assert heads(moved) == ["Garden", "Notices", "Friends and Relations"]
    assert moved.cursor_key == {:section, 0}
  end

  test "View ▸ Section ▸ Move moves the section the highlight is in", %{state: state} do
    state = press(state, [:down, {:f, 10}, "v", "s", "m"])
    assert %{type: :section_move, from: 0} = State.mode(state)
  end

  test "a view that sorts its sections, or a datebook, has no order to change" do
    db = Agendum.Starters.Planner.build()
    activities = Enum.find(Database.views(db), &(&1.name == "Activities"))
    state = db |> start() |> State.switch_view(activities.id) |> press({:alt_f, 10})
    assert panel(state) =~ "This view sorts its sections"

    today = Enum.find(Database.views(db), &(&1.name == "Today"))
    state = db |> start() |> State.switch_view(today.id) |> press([{:f, 10}, "v", "s", "m"])
    assert panel(state) =~ "A datebook view's sections are its dates"
  end
end
